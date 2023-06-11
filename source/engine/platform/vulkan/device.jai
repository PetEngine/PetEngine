VulkanDevice :: struct {
    #as using public_data : Device;

    MINIMAL_SUPPORTED_API_VERSION :: VK_API_VERSION_1_2;
    LATEST_VULKAN_MINOR_VERSION   :: 3;

    api_version : u32;

    instance        : VkInstance;
    physical_device : VkPhysicalDevice;
    device          : VkDevice;

    queues : [#run Basic.enum_highest_value(QueueType) + 1] Queue;

    surface   : VkSurfaceKHR;
    swapchain : VkSwapchainKHR;

    semaphores : [#run Basic.enum_highest_value(SemaphoreKind) + 1] VkSemaphore;

    frame_data : [Device.MAX_SWAPCHAIN_BUFFERS] FrameData;

    messenger      : VkDebugUtilsMessengerEXT;
    message_hashes : [..] u32;

    // @TODO: #ContextDependency
    jai_context : *Context;

    loader : VulkanLoader;
}

createVulkanDevice :: (window : *Window) -> *VulkanDevice #must {
    device := pushToArena(*context.pet.persistent_arena, VulkanDevice);
    device.jai_context = *context;

    // @TODO: #PerFrameArena
    enabled_instance_extensions : [..] string;
    defer Basic.array_free(enabled_instance_extensions);

    // @TODO: #PerFrameArena
    enabled_device_extensions : [..] string;
    defer Basic.array_free(enabled_device_extensions);

    instance_api_version := createInstance(device, *enabled_instance_extensions);
    loadVulkanInstanceExtensionsFunctions(*device.loader, device.instance, *enabled_instance_extensions);
    initMessengerCallback(device);
    physical_device_api_version := selectPhysicalDevice(device);

    device.api_version = Basic.min(instance_api_version, physical_device_api_version);
    infoMessage("Using Vulkan API version: %.%.%.%",
                VK_API_VERSION_VARIANT(device.api_version),
                VK_API_VERSION_MAJOR(device.api_version),
                VK_API_VERSION_MINOR(device.api_version),
                VK_API_VERSION_PATCH(device.api_version));

    gatherQueuesInfo(device);
    createDevice(device, *enabled_device_extensions);
    loadVulkanDeviceExtensionsFunctions(*device.loader, device.device, *enabled_device_extensions);
    getQueues(device);
    createSurface(device, window);
    createSwapchainAndInitImages(device, window, VK_NULL_HANDLE);
    createSemaphores(device);
    createFences(device);
    createCommandPools(device);
    createCommandBuffers(device);
    createSystemCommandBuffers(device);

    return device;
}

destroyVulkanDevice :: (device : *VulkanDevice) {
    // @Important: Should be the first call
    waitVulkanDeviceIdle(device);

    frame_data_it := device.frame_data.data;

    for 0 .. device.swapchain_buffers_count - 1 {
        if frame_data_it.swapchain_texture.name.data {
            Basic.free(frame_data_it.swapchain_texture.name.data);
        }

        for frame_data_it.command_pools {
            // @TODO: VkAllocationCallbacks
            vkDestroyCommandPool(device.device, it, null);
        }

        for frame_data_it.fences {
            // @TODO: VkAllocationCallbacks
            vkDestroyFence(device.device, it, null);
        }

        frame_data_it += 1;
    }

    for device.semaphores {
        // @TODO: VkAllocationCallbacks
        vkDestroySemaphore(device.device, it, null);
    }

    // @TODO: VkAllocationCallbacks
    device.loader.extensions.device.required.vkDestroySwapchainKHR(device.device, device.swapchain, null);

    // @TODO: VkAllocationCallbacks
    device.loader.extensions.instance.required.vkDestroySurfaceKHR(device.instance, device.surface, null);

    // @TODO: VkAllocationCallbacks
    vkDestroyDevice(device.device, null);

    if device.loader.extensions.instance.optional.vkDestroyDebugUtilsMessengerEXT {
        // @TODO: VkAllocationCallbacks
        device.loader.extensions.instance.optional.vkDestroyDebugUtilsMessengerEXT(device.instance, device.messenger, null);
    }

    // @TODO: VkAllocationCallbacks
    vkDestroyInstance(device.instance, null);
}

beginVulkanFrame :: (device : *VulkanDevice) {
    {
        acquire_info := VkAcquireNextImageInfoKHR.{
            sType      = .VK_STRUCTURE_TYPE_ACQUIRE_NEXT_IMAGE_INFO_KHR,
            pNext      = null,
            swapchain  = device.swapchain,
            timeout    = 0xFFFF_FFFF_FFFF_FFFF,
            semaphore  = device.semaphores[SemaphoreKind.ACQUIRE_IMAGE],
            fence      = VK_NULL_HANDLE,
            deviceMask = 1
        };

        back_buffer_index : u32 = ---;
        debugCheckVK(device.loader.extensions.device.required.vkAcquireNextImage2KHR(device.device, *acquire_info, *back_buffer_index));

        device.back_buffer_index = cast,no_check(u8) back_buffer_index;
    }

    frame_data := *device.frame_data[device.back_buffer_index];

    {
        debugCheckVK(vkWaitForFences(device.device, frame_data.fences.count, frame_data.fences.data, VK_TRUE, 0xFFFF_FFFF_FFFF_FFFF));
    }

    // @Speed: Is this (Device.MAX_COMMAND_BUFFERS >> 2) threshold value optimal enough?
    //         Maybe we should always reset entire command pool no matter how many command buffers we use?
    {
        command_buffers_used_it := frame_data.command_buffers_used.data;

        for frame_data.command_pools {
            if command_buffers_used_it.* > (Device.MAX_COMMAND_BUFFERS >> 2) {
                debugCheckVK(vkResetCommandPool(device.device, it, 0));
            } else {
                command_buffers_it := frame_data.command_buffers.data;

                for 0 .. command_buffers_used_it.* - 1 {
                    debugCheckVK(vkResetCommandBuffer(command_buffers_it.*, 0));

                    command_buffers_it += 1;
                }
            }

            command_buffers_used_it += 1;
        }
    }

    {
        begin_info := VkCommandBufferBeginInfo.{
            sType            = .VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            pNext            = null,
            flags            = 0,
            pInheritanceInfo = null // Ignored for primary command buffers
        };

        command_buffers_used_it := frame_data.command_buffers_used.data;
        command_buffers_it      := frame_data.command_buffers.data;

        for 0 .. VulkanDevice.queues.count - 1 {
            command_buffers_local_it := command_buffers_it;

            for 0 .. command_buffers_used_it.* - 1 {
                debugCheckVK(vkBeginCommandBuffer(command_buffers_local_it.*, *begin_info));

                command_buffers_local_it += 1;
            }

            command_buffers_used_it += 1;
            command_buffers_it      += Device.MAX_COMMAND_BUFFERS;
        }
    }
}

endVulkanFrame :: (device : *VulkanDevice) {
    frame_data := *device.frame_data[device.back_buffer_index];

    {
        command_buffers_used_it := frame_data.command_buffers_used.data;
        command_buffers_it      := frame_data.command_buffers.data;

        for 0 .. VulkanDevice.queues.count - 1 {
            command_buffers_local_it := command_buffers_it;

            for 0 .. command_buffers_used_it.* - 1 {
                debugCheckVK(vkEndCommandBuffer(command_buffers_local_it.*));

                command_buffers_local_it += 1;
            }

            command_buffers_used_it += 1;
            command_buffers_it      += Device.MAX_COMMAND_BUFFERS;
        }
    }

    {
        submit_info := VkSubmitInfo.{
            sType = .VK_STRUCTURE_TYPE_SUBMIT_INFO,
            // Everything else will be set in the loop
        };

        WHICH_STAGE_WILL_WAIT_FOR_THE_SEMAPHORE :: VkPipelineStageFlags.[
            VkPipelineStageFlags.VK_PIPELINE_STAGE_VERTEX_SHADER_BIT | .VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT | .VK_PIPELINE_STAGE_TRANSFER_BIT,
            .VK_PIPELINE_STAGE_NONE,
            .VK_PIPELINE_STAGE_NONE
        ];

        command_buffers_used_it := frame_data.command_buffers_used.data;
        command_buffers_it      := frame_data.command_buffers.data;

        for device.queues {
            if command_buffers_used_it.* > 0 {
                fence_to_signal : VkFence = ---;

                if it_index == cast,no_check(s64) QueueType.GRAPHICS {
                    submit_info.waitSemaphoreCount   = 1;
                    submit_info.pWaitSemaphores      = *device.semaphores[SemaphoreKind.ACQUIRE_IMAGE];
                    submit_info.signalSemaphoreCount = 1;
                    submit_info.pSignalSemaphores    = *device.semaphores[SemaphoreKind.GRAPHICS_DONE];

                    fence_to_signal = VK_NULL_HANDLE;
                } else {
                    submit_info.waitSemaphoreCount   = 0;
                    submit_info.pWaitSemaphores      = VK_NULL_HANDLE;
                    submit_info.signalSemaphoreCount = 0;
                    submit_info.pSignalSemaphores    = VK_NULL_HANDLE;

                    fence_to_signal = frame_data.fences[it_index];

                    debugCheckVK(vkResetFences(device.device, 1, *fence_to_signal));
                }

                submit_info.pWaitDstStageMask  = *WHICH_STAGE_WILL_WAIT_FOR_THE_SEMAPHORE[it_index];
                submit_info.commandBufferCount = cast(u32) command_buffers_used_it.*;
                submit_info.pCommandBuffers    = command_buffers_it;

                debugCheckVK(vkQueueSubmit(it.handle, 1, *submit_info, fence_to_signal));
            }

            command_buffers_used_it += 1;
            command_buffers_it      += Device.MAX_COMMAND_BUFFERS;
        }
    }

    {
        post_frame_command_buffer := frame_data.system_command_buffers[SystemCommandBufferKind.POST_FRAME];

        graphics_command_buffers_used := frame_data.command_buffers_used[QueueType.GRAPHICS];

        if graphics_command_buffers_used <= (Device.MAX_COMMAND_BUFFERS >> 2) {
            debugCheckVK(vkResetCommandBuffer(post_frame_command_buffer, 0));
        }

        begin_info := VkCommandBufferBeginInfo.{
            sType            = .VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            pNext            = null,
            flags            = 0,
            pInheritanceInfo = null // Ignored for primary command buffers
        };

        debugCheckVK(vkBeginCommandBuffer(post_frame_command_buffer, *begin_info));

        assert(frame_data.swapchain_texture.current_owner == .GRAPHICS);
        vulkanTextureLayoutBarrier(post_frame_command_buffer, *frame_data.swapchain_texture, .VK_IMAGE_LAYOUT_PRESENT_SRC_KHR);

        debugCheckVK(vkEndCommandBuffer(post_frame_command_buffer));

        fence_to_signal := frame_data.fences[QueueType.GRAPHICS];

        debugCheckVK(vkResetFences(device.device, 1, *fence_to_signal));

        submit_info := VkSubmitInfo.{
            sType                = .VK_STRUCTURE_TYPE_SUBMIT_INFO,
            pNext                = null,
            waitSemaphoreCount   = 1,
            pWaitSemaphores      = ifx  graphics_command_buffers_used > 0
                                   then *device.semaphores[SemaphoreKind.GRAPHICS_DONE]
                                   else *device.semaphores[SemaphoreKind.ACQUIRE_IMAGE],
            pWaitDstStageMask    = VkPipelineStageFlags.[ .VK_PIPELINE_STAGE_ALL_COMMANDS_BIT ].data,
            commandBufferCount   = 1,
            pCommandBuffers      = *post_frame_command_buffer,
            signalSemaphoreCount = 1,
            pSignalSemaphores    = *device.semaphores[SemaphoreKind.POST_FRAME]
        };

        debugCheckVK(vkQueueSubmit(device.queues[QueueType.GRAPHICS].handle, 1, *submit_info, fence_to_signal));
    }

    {
        back_buffer_indices : [1] u32;
        back_buffer_indices[0] = device.back_buffer_index;

        present_info := VkPresentInfoKHR.{
            sType              = .VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            pNext              = null,
            waitSemaphoreCount = 1,
            pWaitSemaphores    = *device.semaphores[SemaphoreKind.POST_FRAME],
            swapchainCount     = 1,
            pSwapchains        = *device.swapchain,
            pImageIndices      = back_buffer_indices.data,
            pResults           = null
        };

        debugCheckVK(device.loader.extensions.device.required.vkQueuePresentKHR(device.queues[QueueType.GRAPHICS].handle, *present_info));
    }
}

setVulkanObjectName :: (device : *VulkanDevice, $object_type : VkObjectType, object : *void, name : string) {
    #if DEBUG_BUILD {
        if device.loader.extensions.instance.optional.vkSetDebugUtilsObjectNameEXT {
            object_name := pushToArena(*context.pet.per_frame_arena, s8, name.count + 1);
            memcpy(object_name, name.data, name.count);

            name_info := VkDebugUtilsObjectNameInfoEXT.{
                sType        = .VK_STRUCTURE_TYPE_DEBUG_UTILS_OBJECT_NAME_INFO_EXT,
                pNext        = null,
                objectType   = object_type,
                objectHandle = cast(u64) object,
                pObjectName  = object_name
            };

            debugCheckVK(device.loader.extensions.instance.optional.vkSetDebugUtilsObjectNameEXT(device.device, *name_info));
        }
    }
}

setVulkanObjectName :: (device : *VulkanDevice, $object_type : VkObjectType, object : *void, $format : string, args : ..Any) {
    #if DEBUG_BUILD {
        if device.loader.extensions.instance.optional.vkSetDebugUtilsObjectNameEXT {
            builder : Basic.String_Builder;
            builder.allocator = Basic.temporary_allocator;

            Basic.print_to_builder(*builder, format, ..args);
            Basic.append(*builder, "\0");

            object_name := Basic.builder_to_string(*builder);

            name_info := VkDebugUtilsObjectNameInfoEXT.{
                sType        = .VK_STRUCTURE_TYPE_DEBUG_UTILS_OBJECT_NAME_INFO_EXT,
                pNext        = null,
                objectType   = object_type,
                objectHandle = cast(u64) object,
                pObjectName  = cast(*s8) object_name.data
            };

            debugCheckVK(device.loader.extensions.instance.optional.vkSetDebugUtilsObjectNameEXT(device.device, *name_info));
        }
    }
}

recreateVulkanSwapchain :: (device : *VulkanDevice, window : *Window) {
    old_swapchain := device.swapchain;

    createSwapchainAndInitImages(device, window, old_swapchain);

    // @TODO: VkAllocationCallbacks
    device.loader.extensions.device.required.vkDestroySwapchainKHR(device.device, old_swapchain, null);
}

waitVulkanDeviceIdle :: (device : *VulkanDevice) {
    debugCheckVK(vkDeviceWaitIdle(device.device));
}

getVulkanSwapchainTexture :: inline (device : *VulkanDevice, swapchain_buffer_index : u32) -> *VulkanTexture {
    return *device.frame_data[swapchain_buffer_index].swapchain_texture;
}

debugCheckVK :: ($code : Code) #expand #no_debug {
    #if DEBUG_BUILD {{
        result := #insert code;
        assert(result == .VK_SUCCESS, "% returned %", #run codeToString(code), result);
    }} else {
        #insert code;
    }
}

#scope_file

Hash :: #import "Hash";

FrameData :: struct {
    swapchain_texture : VulkanTexture;

    fences               : [VulkanDevice.queues.count]                              VkFence;
    command_pools        : [VulkanDevice.queues.count]                              VkCommandPool;
    command_buffers      : [VulkanDevice.queues.count * Device.MAX_COMMAND_BUFFERS] VkCommandBuffer;
    command_buffers_used : [VulkanDevice.queues.count]                              s32;

    system_command_buffers : [#run Basic.enum_highest_value(SystemCommandBufferKind) + 1] VkCommandBuffer;
}

Queue :: struct {
    handle          : VkQueue;
    family_index    : u32 = 0xFFFF_FFFF;
    index_in_family : u32;
}

SemaphoreKind :: enum u8 {
    ACQUIRE_IMAGE;
    GRAPHICS_DONE;
    POST_FRAME;
}

SystemCommandBufferKind :: enum u8 {
    POST_FRAME;
}

createInstance :: (device : *VulkanDevice, enabled_instance_extensions : *[..] string) -> u32 {
    MINIMAL_MINOR_VERSION :: #run VK_API_VERSION_MINOR(VulkanDevice.MINIMAL_SUPPORTED_API_VERSION);

    api_version : u32;
    for < VulkanDevice.LATEST_VULKAN_MINOR_VERSION .. MINIMAL_MINOR_VERSION {
        api_version = VK_MAKE_API_VERSION(0, 1, cast(u32) it, 0);

        if vkEnumerateInstanceVersion(*api_version) == .VK_SUCCESS {
            break;
        }
    }

    infoMessage("Vulkan instance API version: %.%.%.%",
                VK_API_VERSION_VARIANT(api_version),
                VK_API_VERSION_MAJOR(api_version),
                VK_API_VERSION_MINOR(api_version),
                VK_API_VERSION_PATCH(api_version));

    if api_version < VulkanDevice.MINIMAL_SUPPORTED_API_VERSION {
        assertMessage("Vulkan instance API version is less than minimal requied API version: %.%.%.%",
                      VK_API_VERSION_VARIANT(VulkanDevice.MINIMAL_SUPPORTED_API_VERSION),
                      VK_API_VERSION_MAJOR(VulkanDevice.MINIMAL_SUPPORTED_API_VERSION),
                      VK_API_VERSION_MINOR(VulkanDevice.MINIMAL_SUPPORTED_API_VERSION),
                      VK_API_VERSION_PATCH(VulkanDevice.MINIMAL_SUPPORTED_API_VERSION));
    }

    defer Basic.reset_temporary_storage();

    builder : Basic.String_Builder;
    builder.allocator = Basic.temporary_allocator;

    layers_to_apply : [..] *s8;
    layers_to_apply.allocator = Basic.temporary_allocator;

    {
        layers_count : u32;
        debugCheckVK(vkEnumerateInstanceLayerProperties(*layers_count, null));

        layers := pushToArena(*context.pet.per_frame_arena, VkLayerProperties, layers_count);
        debugCheckVK(vkEnumerateInstanceLayerProperties(*layers_count, layers));

        layers_it := layers;

        Basic.print_to_builder(*builder, "Available instance layers (%):\n", layers_count);
        for 0 .. layers_count - 1 {
            Basic.print_to_builder(*builder, "            %\n", to_string(cast(*u8) layers_it.layerName.data));
            layers_it += 1;
        }
        infoMessage("%", Basic.builder_to_string(*builder), new_line = false);

        REQUIRED_LAYERS, OPTIONAL_LAYERS :: #run gatherVulkanLayers();

        for required_layers_it : REQUIRED_LAYERS {
            layers_it = layers;

            layer_found := false;
            for 0 .. layers_count - 1 {
                if String.equal(to_string(cast(*u8) layers_it.layerName.data), required_layers_it) {
                    layer_found = true;
                    break;
                }
                layers_it += 1;
            }

            if layer_found {
                Basic.array_add(*layers_to_apply, cast(*s8) required_layers_it.data);
            } else {
                assertMessage("Required instance layer \"%\" has not been found in available instance layers", required_layers_it);
            }
        }

        for optional_layers_it : OPTIONAL_LAYERS {
            layers_it = layers;

            layer_found := false;
            for 0 .. layers_count - 1 {
                if String.equal(to_string(cast(*u8) layers_it.layerName.data), optional_layers_it) {
                    layer_found = true;
                    break;
                }
                layers_it += 1;
            }

            if layer_found {
                Basic.array_add(*layers_to_apply, cast(*s8) optional_layers_it.data);
            } else {
                warningMessage("Optional instance layer \"%\" has not been found in available instance layers", optional_layers_it);
            }
        }

        Basic.print_to_builder(*builder, "Applying instance layers (%):\n", layers_to_apply.count);
        for layers_to_apply {
            Basic.print_to_builder(*builder, "            %\n", to_string(cast(*u8) it));
        }
        infoMessage("%", Basic.builder_to_string(*builder), new_line = false);
    }

    extensions_to_apply : [..] *s8;
    extensions_to_apply.allocator = Basic.temporary_allocator;

    {
        extensions_count : u32;
        debugCheckVK(vkEnumerateInstanceExtensionProperties(null, *extensions_count, null));

        extensions := pushToArena(*context.pet.per_frame_arena, VkExtensionProperties, extensions_count);
        debugCheckVK(vkEnumerateInstanceExtensionProperties(null, *extensions_count, extensions));

        extensions_it := extensions;

        Basic.print_to_builder(*builder, "Available instance extensions (%):\n", extensions_count);
        for 0 .. extensions_count - 1 {
            Basic.print_to_builder(*builder, "            %\n", to_string(cast(*u8) extensions_it.extensionName.data));
            extensions_it += 1;
        }
        infoMessage("%", Basic.builder_to_string(*builder), new_line = false);

        REQUIRED_EXTENSIONS, OPTIONAL_EXTENSIONS :: #run gatherVulkanInstanceExtensions();

        for required_extensions_it : REQUIRED_EXTENSIONS {
            extensions_it = extensions;

            extension_found := false;
            for 0 .. extensions_count - 1 {
                if String.equal(to_string(cast(*u8) extensions_it.extensionName.data), required_extensions_it) {
                    extension_found = true;
                    break;
                }
                extensions_it += 1;
            }

            if extension_found {
                Basic.array_add(enabled_instance_extensions, required_extensions_it);
            } else {
                assertMessage("Required extension \"%\" has not been found in available extensions", required_extensions_it);
            }
        }

        for optional_extensions_it : OPTIONAL_EXTENSIONS {
            extensions_it = extensions;

            extension_found := false;
            for 0 .. extensions_count - 1 {
                if String.equal(to_string(cast(*u8) extensions_it.extensionName.data), optional_extensions_it) {
                    extension_found = true;
                    break;
                }
                extensions_it += 1;
            }

            if extension_found {
                Basic.array_add(enabled_instance_extensions, optional_extensions_it);
            } else {
                warningMessage("Optional extension \"%\" has not been found in available extensions", optional_extensions_it);
            }
        }

        Basic.print_to_builder(*builder, "Applying instance extensions (%):\n", enabled_instance_extensions.count);
        for enabled_instance_extensions.* {
            Basic.array_add(*extensions_to_apply, cast(*s8) it.data);
            Basic.print_to_builder(*builder, "            %\n", it);
        }
        infoMessage("%", Basic.builder_to_string(*builder), new_line = false);
    }

    nt_engine_name : [ENGINE_NAME.count + 1] s8;
    memcpy(nt_engine_name.data, ENGINE_NAME.data, ENGINE_NAME.count);

    application_info := VkApplicationInfo.{
        sType              = .VK_STRUCTURE_TYPE_APPLICATION_INFO,
        pNext              = null,
        pApplicationName   = null, // @TODO: window.title or something, don't know
        applicationVersion = 0,
        pEngineName        = nt_engine_name.data,
        engineVersion      = ENGINE_VERSION,
        apiVersion         = api_version
    };

    instance_create_info := VkInstanceCreateInfo.{
        sType                   = .VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        pNext                   = null,
        flags                   = 0,
        pApplicationInfo        = *application_info,
        enabledLayerCount       = cast(u32)  layers_to_apply.count,
        ppEnabledLayerNames     = cast(**s8) layers_to_apply.data,
        enabledExtensionCount   = cast(u32)  extensions_to_apply.count,
        ppEnabledExtensionNames = cast(**s8) extensions_to_apply.data
    };

    // @TODO: VkAllocationCallbacks
    debugCheckVK(vkCreateInstance(*instance_create_info, null, *device.instance));

    return api_version;
}

messengerCallback :: (
    messageSeverity : VkDebugUtilsMessageSeverityFlagsEXT,
    messageTypes    : VkDebugUtilsMessageTypeFlagsEXT,
    pCallbackData   : *VkDebugUtilsMessengerCallbackDataEXT,
    pUserData       : *void
) -> VkBool32 #c_call {
    device : *VulkanDevice = pUserData;

    message := to_string(cast(*u8) pCallbackData.pMessage);
    if message[message.count - 1] == #char "." {
        message.count -= 1;
    }

    MESSAGE_DEDUPLICATION_STRATEGY : enum u8 {
        VUID_HASH    :: 1;
        MESSAGE_HASH;
    } : .MESSAGE_HASH;

    push_context device.jai_context {
        #if MESSAGE_DEDUPLICATION_STRATEGY == .VUID_HASH {
            message_end := message.data + message.count;

            vuid_start := message.data;
            while vuid_start < message_end && vuid_start.* != #char "[" {
                vuid_start += 1;
            }

            vuid_end := vuid_start;
            while vuid_end < message_end && vuid_end.* != #char "]" {
                vuid_end += 1;
            }
            vuid_end += 1;

            vuid_string : string = ---;
            vuid_string.data  = vuid_start;
            vuid_string.count = vuid_end - vuid_start;

            hash := Hash.get_hash(vuid_string);

            should_be_printed := Basic.array_add_if_unique(*device.message_hashes, hash);
        } else #if MESSAGE_DEDUPLICATION_STRATEGY == .MESSAGE_HASH {
            hash := Hash.get_hash(message);

            should_be_printed := Basic.array_add_if_unique(*device.message_hashes, hash);
        } else {
            should_be_printed :: true;
        }

        if should_be_printed {
            SHORTEN_MESSAGE :: true;
            #if SHORTEN_MESSAGE {
                index := String.find_index_from_left(message, "Object");
                if index != -1 {
                    builder : Basic.String_Builder;
                    builder.allocator = Basic.temporary_allocator;

                    severity_and_vuid : string = ---;
                    severity_and_vuid.data  = message.data;
                    severity_and_vuid.count = index;

                    Basic.append(*builder, severity_and_vuid);

                    message.data  += index;
                    message.count -= index;

                    index = String.find_index_from_left(message, "MessageID");
                    if index != -1 {
                        message.data  += index;
                        message.count -= index;

                        index = String.find_index_from_left(message, "| ");
                        if index != -1 {
                            message.data  += index + 2;
                            message.count -= index + 2;
                        }
                    }

                    Basic.append(*builder, message);

                    message = Basic.builder_to_string(*builder);
                }
            }

            MESSAGE_FORMAT :: #string END
%
--------------------------------------------------------------------------------------------------------
END;

            if messageSeverity & .VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT {
                errorMessage(MESSAGE_FORMAT, message, new_line = false);
            } else if messageSeverity & .VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT {
                warningMessage(MESSAGE_FORMAT, message, new_line = false);
            } else if messageSeverity & .VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT {
                debugMessage(MESSAGE_FORMAT, message, new_line = false);
            } else {
                infoMessage(MESSAGE_FORMAT, message, new_line = false);
            }
        }
    }

    return VK_FALSE;
}

initMessengerCallback :: (device : *VulkanDevice) {
    if device.loader.extensions.instance.optional.vkCreateDebugUtilsMessengerEXT {
        create_info := VkDebugUtilsMessengerCreateInfoEXT.{
            sType           = .VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            pNext           = null,
            flags           = 0,
            messageSeverity = VkDebugUtilsMessageSeverityFlagsEXT.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT
//                          | .VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT
                            | .VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT
                            | .VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
            messageType     = VkDebugUtilsMessageTypeFlagsEXT.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT
                            | .VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT
                            | .VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT
                            | .VK_DEBUG_UTILS_MESSAGE_TYPE_DEVICE_ADDRESS_BINDING_BIT_EXT,
            pfnUserCallback = messengerCallback,
            pUserData       = device,
        };

        // @TODO: VkAllocationCallbacks
        debugCheckVK(device.loader.extensions.instance.optional.vkCreateDebugUtilsMessengerEXT(device.instance,
                                                                                               *create_info,
                                                                                               null,
                                                                                               *device.messenger));
    }
}

// @TODO: Multiple GPU support: vkEnumeratePhysicalDeviceGroupsKHR (VK_KHR_device_group_creation)
selectPhysicalDevice :: (device : *VulkanDevice) -> u32 {
    physical_device_count : u32;
    debugCheckVK(vkEnumeratePhysicalDevices(device.instance, *physical_device_count, null));

    physical_devices := pushToArena(*context.pet.per_frame_arena, VkPhysicalDevice, physical_device_count);
    debugCheckVK(vkEnumeratePhysicalDevices(device.instance, *physical_device_count, physical_devices));

    physical_device_properties := VkPhysicalDeviceProperties2.{
        sType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2,
        pNext = null
    };
    properties := *physical_device_properties.properties;

    COMPATIBLE_PHYSICAL_DEVICE_TYPES :: VkPhysicalDeviceType.[
        .VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU,
        .VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU
    ];

    memory_properties := VkPhysicalDeviceMemoryProperties2.{
        sType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MEMORY_PROPERTIES_2,
        pNext = null
    };

    available_device_memory : VkDeviceSize;

    for type : COMPATIBLE_PHYSICAL_DEVICE_TYPES {
        max_memory_size : VkDeviceSize;

        physical_device_it := physical_devices;
        for 0 .. physical_device_count - 1 {
            vkGetPhysicalDeviceProperties2(physical_device_it.*, *physical_device_properties);

            if properties.deviceType == type {
                vkGetPhysicalDeviceMemoryProperties2(physical_device_it.*, *memory_properties);

                memory_heaps : [] VkMemoryHeap;
                memory_heaps.data  = memory_properties.memoryProperties.memoryHeaps.data;
                memory_heaps.count = memory_properties.memoryProperties.memoryHeapCount;

                memory_size : VkDeviceSize;
                if type == {
                    case .VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU;
                        device.type = .DISCRETE;

                        for memory_heaps {
                            if it.flags & .VK_MEMORY_HEAP_DEVICE_LOCAL_BIT {
                                memory_size += it.size;
                            }
                        }

                    case .VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU;
                        device.type = .INTEGRATED;

                        for memory_heaps {
                            memory_size += it.size;
                        }
                }

                if memory_size > max_memory_size {
                    max_memory_size        = memory_size;
                    device.physical_device = physical_device_it.*;
                }
            }

            physical_device_it += 1;
        }

        if device.physical_device {
            available_device_memory = max_memory_size;
            break;
        }
    }

    if device.physical_device == VK_NULL_HANDLE {
        #assert COMPATIBLE_PHYSICAL_DEVICE_TYPES.count == 2;
        assertMessage("Vulkan back end supports only % types of GPUs: % and %. None of them were found",
                      COMPATIBLE_PHYSICAL_DEVICE_TYPES.count,
                      COMPATIBLE_PHYSICAL_DEVICE_TYPES[0],
                      COMPATIBLE_PHYSICAL_DEVICE_TYPES[1]);
    }

    infoMessage("Using % device with % GB of memory", device.type, available_device_memory / 1_073_741_824.0);

    if properties.apiVersion < VulkanDevice.MINIMAL_SUPPORTED_API_VERSION {
        assertMessage("Physical device API version is less than minimal requied API version: %.%.%.%",
                      VK_API_VERSION_VARIANT(VulkanDevice.MINIMAL_SUPPORTED_API_VERSION),
                      VK_API_VERSION_MAJOR(VulkanDevice.MINIMAL_SUPPORTED_API_VERSION),
                      VK_API_VERSION_MINOR(VulkanDevice.MINIMAL_SUPPORTED_API_VERSION),
                      VK_API_VERSION_PATCH(VulkanDevice.MINIMAL_SUPPORTED_API_VERSION));
    }

    device.vendor_id = cast(PCIVendorID) properties.vendorID;

    PHYSICAL_DEVICE_INFO_MESSAGE :: #string END
Physical device info:
            API version:    %.%.%.%
            Driver version: 0x%
            Vendor ID:      % (0x%)
            Device ID:      0x%
            Device type:    %
            Device name:    %
END;

    infoMessage(PHYSICAL_DEVICE_INFO_MESSAGE,
                VK_API_VERSION_VARIANT(properties.apiVersion),
                VK_API_VERSION_MAJOR(properties.apiVersion),
                VK_API_VERSION_MINOR(properties.apiVersion),
                VK_API_VERSION_PATCH(properties.apiVersion),
                Basic.formatInt(properties.driverVersion, base = 16),
                vendorIdToString(properties.vendorID),
                Basic.formatInt(properties.vendorID, base = 16),
                Basic.formatInt(properties.deviceID, base = 16),
                properties.deviceType,
                s8_array_to_string(properties.deviceName),
                new_line = false);

    driver_properties := VkPhysicalDeviceDriverProperties.{
        sType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DRIVER_PROPERTIES,
        pNext = null,
    };

    physical_device_properties.pNext = *driver_properties;
    vkGetPhysicalDeviceProperties2(device.physical_device, *physical_device_properties);

    DRIVER_INFO_MESSAGE :: #string END
Driver info:
            Driver ID:           %
            Driver name:         %
            Driver info:         %
            Conformance version: %.%.%.%
END;

    infoMessage(DRIVER_INFO_MESSAGE,
                driver_properties.driverID,
                s8_array_to_string(driver_properties.driverName),
                s8_array_to_string(driver_properties.driverInfo),
                driver_properties.conformanceVersion.major,
                driver_properties.conformanceVersion.minor,
                driver_properties.conformanceVersion.subminor,
                driver_properties.conformanceVersion.patch,
                new_line = false);

    return properties.apiVersion;
}

findQueueFamily :: ($condition : Code) #expand {
    `queue_family_properties_it = `queue_family_properties;

    for 0 .. `queue_family_properties_count - 1 {
        queue_family_flags := `queue_family_properties_it.queueFamilyProperties.queueFlags;

        if #insert,scope() condition {
            `queue_it.family_index = it;
            break;
        }

        `queue_family_properties_it += 1;
    }
}

gatherQueuesInfo :: (device : *VulkanDevice) {
    queue_family_properties_count : u32;
    vkGetPhysicalDeviceQueueFamilyProperties2(device.physical_device, *queue_family_properties_count, null);
    assert(queue_family_properties_count > 0);

    queue_family_properties := pushToArena(*context.pet.per_frame_arena, VkQueueFamilyProperties2, queue_family_properties_count);

    queue_family_properties_it := queue_family_properties;
    for 0 .. queue_family_properties_count - 1 {
        queue_family_properties_it.sType = .VK_STRUCTURE_TYPE_QUEUE_FAMILY_PROPERTIES_2;
        queue_family_properties_it += 1;
    }

    vkGetPhysicalDeviceQueueFamilyProperties2(device.physical_device, *queue_family_properties_count, queue_family_properties);

    // Print info about available queue families
    {
        builder : Basic.String_Builder;

        Basic.append(*builder, "Available queue families:\n");

        queue_family_properties_it = queue_family_properties;
        for 0 .. queue_family_properties_count - 1 {
            properties := *queue_family_properties_it.queueFamilyProperties;

            Basic.print_to_builder(*builder, "            [%]: Flags:        %\n", it, properties.queueFlags);
            Basic.print_to_builder(*builder, "                 Queues count: %\n", properties.queueCount);

            queue_family_properties_it += 1;
        }

        infoMessage("%", Basic.builder_to_string(*builder), new_line = false);
    }

    // Find queue family indices
    // @TODO: #NotExistedQueues
    for * queue_it : device.queues {
        queue_type := cast(QueueType) it_index;

        QUEUE_TYPE_TO_VK_QUEUE_FLAGS :: VkQueueFlags.[
            .VK_QUEUE_GRAPHICS_BIT,
            .VK_QUEUE_COMPUTE_BIT,
            .VK_QUEUE_TRANSFER_BIT,
        ];
        vk_queue_type        := QUEUE_TYPE_TO_VK_QUEUE_FLAGS[queue_type];
        vk_queue_other_types := (VkQueueFlags.VK_QUEUE_GRAPHICS_BIT | .VK_QUEUE_COMPUTE_BIT) & ~vk_queue_type;

        // 1. We are trying to find a queue family that supports ONLY concrete queue type (ideal situation).
        // 2. We are trying to find a queue family that supports needed queue type, but may support several queue type (ok situation).

        findQueueFamily(#code (queue_family_flags & `vk_queue_type) && !(queue_family_flags & `vk_queue_other_types));

        if queue_it.family_index == 0xFFFF_FFFF {
            findQueueFamily(#code queue_family_flags & `vk_queue_type);

            if queue_it.family_index == 0xFFFF_FFFF && queue_type == .ASYNC_TRANSFER {
                // According to vulkan spec, declaring transfer queue capability is optional.
                FLAGS :: VkQueueFlags.VK_QUEUE_GRAPHICS_BIT | .VK_QUEUE_COMPUTE_BIT;
                findQueueFamily(#code queue_family_flags & `FLAGS);
            }
        }

        assert(queue_it.family_index != 0xFFFF_FFFF, "% queue family was not found", queue_type);
    }

    graphics_queue := *device.queues[QueueType.GRAPHICS];
    compute_queue  := *device.queues[QueueType.ASYNC_COMPUTE];
    transfer_queue := *device.queues[QueueType.ASYNC_TRANSFER];

    // Detect queue index in queue family
    {
        if compute_queue.family_index == graphics_queue.family_index {
            compute_queue.index_in_family = graphics_queue.index_in_family + 1;
        } else if transfer_queue.family_index == graphics_queue.family_index {
            transfer_queue.index_in_family = graphics_queue.index_in_family + 1;
        }

        if transfer_queue.family_index == compute_queue.family_index {
            transfer_queue.index_in_family = compute_queue.index_in_family + 1;
        }
    }

    // Print info about queues
    {
        QUEUE_INFO_MESSAGE :: #string END
Queues info:
            Graphics:
                Family flags:    %
                Family index:    %
                Index in family: %
            Compute:
                Family flags:    %
                Family index:    %
                Index in family: %
            Transfer:
                Family flags:    %
                Family index:    %
                Index in family: %
END;

        infoMessage(QUEUE_INFO_MESSAGE,
                    queue_family_properties[graphics_queue.family_index].queueFamilyProperties.queueFlags,
                    graphics_queue.family_index,
                    graphics_queue.index_in_family,
                    queue_family_properties[compute_queue.family_index].queueFamilyProperties.queueFlags,
                    compute_queue.family_index,
                    compute_queue.index_in_family,
                    queue_family_properties[transfer_queue.family_index].queueFamilyProperties.queueFlags,
                    transfer_queue.family_index,
                    transfer_queue.index_in_family,
                    new_line = false);
    }
}

// @TODO:
//    VkQueueFamilyGlobalPriorityPropertiesKHR (VK_KHR_global_priority).
//    vkEnumeratePhysicalDeviceQueueFamilyPerformanceQueryCountersKHR (VK_KHR_performance_query) Is it actully useful?
//    VkDeviceMemoryOverallocationCreateInfoAMD (VK_AMD_memory_overallocation_behavior) sounds useful.
createDevice :: (device : *VulkanDevice, enabled_device_extensions : *[..] string) {
    queues_per_family : [VulkanDevice.queues.count] u32;

    for * device.queues {
        queues_per_family[it.family_index] += 1;
    }

    // @TODO: For now queues have equal priority. Should be tweaked later.
    QUEUE_PRIORITIES :: f32.[ 1.0, 1.0, 1.0 ];

    queue_create_infos       : [VulkanDevice.queues.count] VkDeviceQueueCreateInfo = ---;
    queue_create_infos_count : u32 = 0;

    for * device.queues {
        queues_in_family := queues_per_family[it.family_index];
        if queues_in_family {
            queue_create_info := *queue_create_infos[queue_create_infos_count];

            queue_create_info.sType            = .VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
            queue_create_info.pNext            = null;
            queue_create_info.flags            = 0;
            queue_create_info.queueFamilyIndex = it.family_index;
            queue_create_info.queueCount       = queues_in_family;
            queue_create_info.pQueuePriorities = QUEUE_PRIORITIES.data;

            queue_create_infos_count += 1;
        }
    }

    defer Basic.reset_temporary_storage();

    builder : Basic.String_Builder;
    builder.allocator = Basic.temporary_allocator;

    extensions_to_apply : [..] *s8;
    extensions_to_apply.allocator = Basic.temporary_allocator;

    {
        extensions_count : u32;
        debugCheckVK(vkEnumerateDeviceExtensionProperties(device.physical_device, null, *extensions_count, null));

        extensions := pushToArena(*context.pet.per_frame_arena, VkExtensionProperties, extensions_count);
        debugCheckVK(vkEnumerateDeviceExtensionProperties(device.physical_device, null, *extensions_count, extensions));

        extensions_it := extensions;

        Basic.print_to_builder(*builder, "Available device extensions (%):\n", extensions_count);
        for 0 .. extensions_count - 1 {
            Basic.print_to_builder(*builder, "            %\n", to_string(cast(*u8) extensions_it.extensionName.data));
            extensions_it += 1;
        }
        infoMessage("%", Basic.builder_to_string(*builder), new_line = false);

        REQUIRED_EXTENSIONS, OPTIONAL_EXTENSIONS :: #run gatherVulkanDeviceExtensions();

        for required_extensions_it : REQUIRED_EXTENSIONS {
            extensions_it = extensions;

            extension_found := false;
            for 0 .. extensions_count - 1 {
                if String.equal(to_string(cast(*u8) extensions_it.extensionName.data), required_extensions_it) {
                    extension_found = true;
                    break;
                }
                extensions_it += 1;
            }

            if extension_found {
                Basic.array_add(enabled_device_extensions, required_extensions_it);
            } else {
                assertMessage("Required device extension \"%\" has not been found in available device extensions", required_extensions_it);
            }
        }

        for optional_extensions_it : OPTIONAL_EXTENSIONS {
            extensions_it = extensions;

            extension_found := false;
            for 0 .. extensions_count - 1 {
                if String.equal(to_string(cast(*u8) extensions_it.extensionName.data), optional_extensions_it) {
                    extension_found = true;
                    break;
                }
                extensions_it += 1;
            }

            if extension_found {
                Basic.array_add(enabled_device_extensions, optional_extensions_it);
            } else {
                warningMessage("Optional device extension \"%\" has not been found in available device extensions", optional_extensions_it);
            }
        }

        Basic.print_to_builder(*builder, "Applying device extensions (%):\n", enabled_device_extensions.count);
        for enabled_device_extensions.* {
            Basic.array_add(*extensions_to_apply, cast(*s8) it.data);
            Basic.print_to_builder(*builder, "            %\n", it);
        }
        infoMessage("%", Basic.builder_to_string(*builder), new_line = false);
    }

    // @TODO: #Features
    #if false {
        available_features_1_3 := VkPhysicalDeviceVulkan13Features.{
            sType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
            pNext = null,
        };

        available_features_1_2 := VkPhysicalDeviceVulkan12Features.{
            sType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
            pNext = ifx  device.api_version >= VK_API_VERSION_1_3
                    then *available_features_1_3
                    else null,
        };

        available_features_1_1 := VkPhysicalDeviceVulkan11Features.{
            sType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES,
            pNext = *available_features_1_2,
        };

        available_features_1_0 := VkPhysicalDeviceFeatures2.{
            sType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2,
            pNext = *available_features_1_1,
        };

        vkGetPhysicalDeviceFeatures2(device.physical_device, *available_features_1_0);

        // @TODO: #Features. define optional and required features and validate it.
    }

    device_create_info := VkDeviceCreateInfo.{
        sType                   = .VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        pNext                   = null, // @TODO: #Features
        flags                   = 0,
        queueCreateInfoCount    = queue_create_infos_count,
        pQueueCreateInfos       = queue_create_infos.data,
        enabledLayerCount       = 0,    // Deprecated and ignored.
        ppEnabledLayerNames     = null, // Deprecated and ignored.
        enabledExtensionCount   = cast(u32)  extensions_to_apply.count,
        ppEnabledExtensionNames = cast(**s8) extensions_to_apply.data,
        pEnabledFeatures        = null, // We are using pNext for VkPhysicalDeviceFeatures2
    };

    // @TODO: VkAllocationCallbacks
    debugCheckVK(vkCreateDevice(device.physical_device, *device_create_info, null, *device.device));
}

// @TODO: #NotExistedQueues
getQueues :: (device : *VulkanDevice) {
    for * device.queues {
        queue_info := VkDeviceQueueInfo2.{
            sType            = .VK_STRUCTURE_TYPE_DEVICE_QUEUE_INFO_2,
            pNext            = null,
            flags            = 0,
            queueFamilyIndex = it.family_index,
            queueIndex       = it.index_in_family
        };

        vkGetDeviceQueue2(device.device, *queue_info, *it.handle);
        assert(it.handle != VK_NULL_HANDLE);

        setVulkanObjectName(device, .VK_OBJECT_TYPE_QUEUE, it.handle, "% queue", cast(QueueType) it_index);
    }
}

createSurface :: (device : *VulkanDevice, window : *Window) {
    #if OS == .WINDOWS {
        win32_window := cast(*Win32Window) window;

        create_info := VkWin32SurfaceCreateInfoKHR.{
            sType     = .VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
            pNext     = null,
            flags     = 0,
            hinstance = win32_window.manager.app_instance,
            hwnd      = win32_window.handle
        };

        // @TODO: VkAllocationCallbacks
        debugCheckVK(device.loader.extensions.instance.required.vkCreateWin32SurfaceKHR(device.instance, *create_info, null, *device.surface));
    } else {
        notImplemented();
    }
}

createSwapchainAndInitImages :: (device : *VulkanDevice, window : *Window, old_swapchain : VkSwapchainKHR) {
    surface_capabilities : VkSurfaceCapabilitiesKHR = ---;
    debugCheckVK(device.loader.extensions.instance.required.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device.physical_device,
                                                                                                      device.surface,
                                                                                                      *surface_capabilities));

    surface_formats_count : u32;
    debugCheckVK(device.loader.extensions.instance.required.vkGetPhysicalDeviceSurfaceFormatsKHR(device.physical_device,
                                                                                                 device.surface,
                                                                                                 *surface_formats_count,
                                                                                                 null));

    surface_formats := pushToArena(*context.pet.per_frame_arena, VkSurfaceFormatKHR, surface_formats_count);
    debugCheckVK(device.loader.extensions.instance.required.vkGetPhysicalDeviceSurfaceFormatsKHR(device.physical_device,
                                                                                                 device.surface,
                                                                                                 *surface_formats_count,
                                                                                                 surface_formats));

    // @TODO: #Settings. Get the number of swapchain buffers from settings
    requested_swapchain_buffers_count : u32 = 2;
    if requested_swapchain_buffers_count < surface_capabilities.minImageCount {
        warningMessage("Requested number of swapchain buffers is %, but surface supports at least % of them. % will be used",
                       requested_swapchain_buffers_count,
                       surface_capabilities.minImageCount,
                       surface_capabilities.minImageCount);
        requested_swapchain_buffers_count = surface_capabilities.minImageCount;
    } else if requested_swapchain_buffers_count > surface_capabilities.maxImageCount && surface_capabilities.maxImageCount > 0 {
        warningMessage("Requested number of swapchain buffers is %, but surface supports maximum % of them. % will be used",
                       requested_swapchain_buffers_count,
                       surface_capabilities.maxImageCount,
                       surface_capabilities.maxImageCount);
        requested_swapchain_buffers_count = surface_capabilities.maxImageCount;
    }
    assert(requested_swapchain_buffers_count <= Device.MAX_SWAPCHAIN_BUFFERS,
           "You want too many swapchain buffers: %. If you really need that much you can increase Device.MAX_SWAPCHAIN_BUFFERS",
           requested_swapchain_buffers_count);

    infoMessage("Requested swapchain buffers count: %", requested_swapchain_buffers_count);

    surface_format := surface_formats;
    for 0 .. surface_formats_count - 1 {
        if surface_format.format == .VK_FORMAT_B8G8R8A8_UNORM {
            break;
        }
        surface_format += 1;
    }

    if surface_format >= surface_formats + surface_formats_count {
        assertMessage("Chosen image format (VK_FORMAT_B8G8R8A8_UNORM) for swapchain images is not supported on this device");
    }

    surface_extent : VkExtent2D = ---;
    surface_extent.width  = window.surface.width;
    surface_extent.height = window.surface.height;

    if !memcmp(*surface_capabilities.maxImageExtent, *VkExtent2D.{0, 0}, size_of(VkExtent2D)) {
        assertMessage("There is no way to create swapchain while window is minimized");
    } else if memcmp(*surface_extent, *surface_capabilities.maxImageExtent, size_of(VkExtent2D)) > 0 {
        warningMessage("Requested surface extent for swapchain (% x %) is too big. Will be adjusted to % x %",
                       surface_extent.width,
                       surface_extent.height,
                       surface_capabilities.maxImageExtent.width,
                       surface_capabilities.maxImageExtent.height);
        surface_extent = surface_capabilities.maxImageExtent;
    } else if memcmp(*surface_extent, *surface_capabilities.minImageExtent, size_of(VkExtent2D)) < 0 {
        warningMessage("Requested surface extent for swapchain (% x %) is too small. Will be adjusted to % x %",
                       surface_extent.width,
                       surface_extent.height,
                       surface_capabilities.minImageExtent.width,
                       surface_capabilities.minImageExtent.height);
        surface_extent = surface_capabilities.minImageExtent;
    }

    REQUESTED_USAGE_FLAGS :: VkImageUsageFlags.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT
                           | .VK_IMAGE_USAGE_SAMPLED_BIT
                           | .VK_IMAGE_USAGE_TRANSFER_DST_BIT;
    allowed_usage_flags   := REQUESTED_USAGE_FLAGS & surface_capabilities.supportedUsageFlags;

    if allowed_usage_flags != REQUESTED_USAGE_FLAGS {
        assertMessage("Requested surface image usage flags are %, but surface supports only % flags. % flags can not be used",
                      REQUESTED_USAGE_FLAGS,
                      surface_capabilities.supportedUsageFlags,
                      ~allowed_usage_flags & REQUESTED_USAGE_FLAGS);
    }

    // @TODO: #NotExistedQueues
    queue_families_having_access_to_swapchain_images : [1] u32;
    queue_families_having_access_to_swapchain_images[0] = device.queues[QueueType.GRAPHICS].family_index;

    // @TODO: What if the monitor is located vertically?
    if !(surface_capabilities.supportedTransforms & .VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR) {
        assertMessage("For some reason monitor does not support landscape mode");
    }

    if surface_capabilities.currentTransform != .VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR {
        warningMessage("Requested surface transform is %, but current surface transform is %. The fact they differ may perform in worse performance",
                       VkSurfaceTransformFlagsKHR.VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
                       surface_capabilities.currentTransform);
    }

    if !(surface_capabilities.supportedCompositeAlpha & .VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR) {
        assertMessage("Surface does not support opaque alpha mode");
    }

    create_info := VkSwapchainCreateInfoKHR.{
        sType                 = .VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        pNext                 = null,
        flags                 = 0,
        surface               = device.surface,
        minImageCount         = requested_swapchain_buffers_count,
        imageFormat           = surface_format.format,
        imageColorSpace       = surface_format.colorSpace,
        imageExtent           = surface_extent,
        imageArrayLayers      = 1,
        imageUsage            = REQUESTED_USAGE_FLAGS,
        imageSharingMode      = .VK_SHARING_MODE_EXCLUSIVE,
        queueFamilyIndexCount = cast(u32) queue_families_having_access_to_swapchain_images.count,
        pQueueFamilyIndices   = queue_families_having_access_to_swapchain_images.data,
        preTransform          = .VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
        compositeAlpha        = .VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        presentMode           = .VK_PRESENT_MODE_MAILBOX_KHR, // @TODO: #Settings. Vsync (fifo), allow tearing (immediate), vsync + allow tearing (fifo_relaxed)
        clipped               = VK_TRUE,
        oldSwapchain          = old_swapchain
    };

    // @TODO: VkAllocationCallbacks
    debugCheckVK(device.loader.extensions.device.required.vkCreateSwapchainKHR(device.device, *create_info, null, *device.swapchain));

    // Initialize swapchain images
    {
        swapchain_buffers_count : u32 = ---;
        device.loader.extensions.device.required.vkGetSwapchainImagesKHR(device.device,
                                                                         device.swapchain,
                                                                         *swapchain_buffers_count,
                                                                         null);
        device.swapchain_buffers_count = cast,no_check(u8) swapchain_buffers_count;

        assert(device.swapchain_buffers_count > 0);
        assert(device.swapchain_buffers_count <= Device.MAX_SWAPCHAIN_BUFFERS,
               "Number of swapchain buffers is too high: %. It seems like driver does some weird things, so you may just increase Device.MAX_SWAPCHAIN_BUFFERS",
               device.swapchain_buffers_count);

        infoMessage("Actual swapchain buffers count: %", device.swapchain_buffers_count);

        swapchain_images : [Device.MAX_SWAPCHAIN_BUFFERS] VkImage;
        device.loader.extensions.device.required.vkGetSwapchainImagesKHR(device.device,
                                                                         device.swapchain,
                                                                         *swapchain_buffers_count,
                                                                         swapchain_images.data);
        assert(swapchain_buffers_count == device.swapchain_buffers_count);

        frame_data_it       := device.frame_data.data;
        swapchain_images_it := swapchain_images.data;

        // @Important: Should be with default allocator
        builder : Basic.String_Builder;

        // @TODO: #VulkanTexture. Add these images to texture manager
        for 0 .. device.swapchain_buffers_count - 1 {
            Basic.print_to_builder(*builder, "Swapchain image #%", it);

            if frame_data_it.swapchain_texture.name.data {
                Basic.free(frame_data_it.swapchain_texture.name.data);
            }

            frame_data_it.swapchain_texture.dimension             = ._2D;
            frame_data_it.swapchain_texture.format                = vulkanFormatToTextureFormat(surface_format.format);
            frame_data_it.swapchain_texture.flags                 = Texture.Flags.SWAPCHAIN | .RESOLUTION_DEPENDENT;
            frame_data_it.swapchain_texture.width                 = cast(u16) surface_extent.width;
            frame_data_it.swapchain_texture.height                = cast(u16) surface_extent.height;
            frame_data_it.swapchain_texture.depth                 = 0;
            frame_data_it.swapchain_texture.samples_count         = 1;
            frame_data_it.swapchain_texture.mips_count            = 1;
            frame_data_it.swapchain_texture.name                  = Basic.builder_to_string(*builder);
            frame_data_it.swapchain_texture.possible_owners_count = 1;
            frame_data_it.swapchain_texture.possible_owners[0]    = .GRAPHICS;
            frame_data_it.swapchain_texture.current_owner         = .GRAPHICS;
            frame_data_it.swapchain_texture.image                 = swapchain_images_it.*;
            frame_data_it.swapchain_texture.current_layout        = .VK_IMAGE_LAYOUT_UNDEFINED;

            #if REQUESTED_USAGE_FLAGS & .VK_IMAGE_USAGE_SAMPLED_BIT          then frame_data_it.swapchain_texture.flags |= .COHERENT;
            #if REQUESTED_USAGE_FLAGS & .VK_IMAGE_USAGE_STORAGE_BIT          then frame_data_it.swapchain_texture.flags |= .NONCOHERENT;
            #if REQUESTED_USAGE_FLAGS & .VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT then frame_data_it.swapchain_texture.flags |= .COLOR_TARGET;

            setVulkanObjectName(device, .VK_OBJECT_TYPE_IMAGE, frame_data_it.swapchain_texture.image, frame_data_it.swapchain_texture.name);

            frame_data_it       += 1;
            swapchain_images_it += 1;
        }
    }
}

createSemaphores :: (device : *VulkanDevice) {
    create_info := VkSemaphoreCreateInfo.{
        sType = .VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
        pNext = null,
        flags = 0
    };

    for * device.semaphores {
        // @TODO: VkAllocationCallbacks
        debugCheckVK(vkCreateSemaphore(device.device, *create_info, null, it));

        setVulkanObjectName(device, .VK_OBJECT_TYPE_SEMAPHORE, it.*, "% semaphore", cast(SemaphoreKind) it_index);
    }
}

createFences :: (device : *VulkanDevice) {
    create_info := VkFenceCreateInfo.{
        sType = .VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        pNext = null,
        flags = .VK_FENCE_CREATE_SIGNALED_BIT,
    };

    frame_data_it := device.frame_data.data;

    for swapchain_buffer_index : 0 .. device.swapchain_buffers_count - 1 {
        for * frame_data_it.fences {
            // @TODO: VkAllocationCallbacks
            debugCheckVK(vkCreateFence(device.device, *create_info, null, it));

            setVulkanObjectName(device, .VK_OBJECT_TYPE_FENCE, it.*, "% fence for swapchain buffer #%",
                                cast(QueueType) it_index,
                                swapchain_buffer_index);
        }

        frame_data_it += 1;
    }
}

// Actually, we do not want to create additional command pools for queues we don't have,
// but anyway it's just chipper to have slightly bigger amount of them.
// Maybe someday we will have better behaviour for not existed compute and transfer queues.
// @TODO: #NotExistedQueues
createCommandPools :: (device : *VulkanDevice) {
    create_info := VkCommandPoolCreateInfo.{
        sType            = .VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        pNext            = null,
        flags            = .VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        queueFamilyIndex = 0xFFFF_FFFF // Will be set in a loop
    };

    frame_data_it := device.frame_data.data;

    for buffer_index : 0 .. device.swapchain_buffers_count - 1 {
        queues_it := device.queues.data;

        for * frame_data_it.command_pools {
            create_info.queueFamilyIndex = queues_it.family_index;

            // @TODO: VkAllocationCallbacks
            debugCheckVK(vkCreateCommandPool(device.device, *create_info, null, it));

            setVulkanObjectName(device, .VK_OBJECT_TYPE_COMMAND_POOL, it.*, "% command pool for swapchain buffer #%",
                                cast(QueueType) it_index,
                                buffer_index);

            queues_it += 1;
        }

        frame_data_it += 1;
    }
}

createCommandBuffers :: (device : *VulkanDevice) {
    allocation_info := VkCommandBufferAllocateInfo.{
        sType              = .VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        pNext              = null,
        commandPool        = null, // Will be set in a loop
        level              = .VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        commandBufferCount = cast(u32) Device.MAX_COMMAND_BUFFERS
    };

    frame_data_it := device.frame_data.data;

    for swapchain_buffer_index : 0 .. device.swapchain_buffers_count - 1 {
        command_buffers_it := frame_data_it.command_buffers.data;

        for command_pool, command_pool_index : frame_data_it.command_pools {
            allocation_info.commandPool = command_pool;

            debugCheckVK(vkAllocateCommandBuffers(device.device, *allocation_info, command_buffers_it));

            #if DEBUG_BUILD {
                local_command_buffers_it := command_buffers_it;

                for 0 .. Device.MAX_COMMAND_BUFFERS - 1 {
                    setVulkanObjectName(device,
                                        .VK_OBJECT_TYPE_COMMAND_BUFFER,
                                        local_command_buffers_it.*,
                                        "% command buffer #% for swapchain buffer #%",
                                        cast(QueueType) command_pool_index,
                                        it,
                                        swapchain_buffer_index);

                    local_command_buffers_it += 1;
                }
            }

            command_buffers_it += Device.MAX_COMMAND_BUFFERS;
        }

        frame_data_it += 1;
    }
}

createSystemCommandBuffers :: (device : *VulkanDevice) {
    frame_data_it := device.frame_data.data;

    allocation_info := VkCommandBufferAllocateInfo.{
        sType              = .VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        pNext              = null,
        commandPool        = null, // Will be set in a loop
        level              = .VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        commandBufferCount = frame_data_it.system_command_buffers.count
    };

    for swapchain_buffer_index : 0 .. device.swapchain_buffers_count - 1 {
        allocation_info.commandPool = frame_data_it.command_pools[QueueType.GRAPHICS];

        debugCheckVK(vkAllocateCommandBuffers(device.device, *allocation_info, frame_data_it.system_command_buffers.data));

        #if DEBUG_BUILD {
            for frame_data_it.system_command_buffers {
                setVulkanObjectName(device, .VK_OBJECT_TYPE_COMMAND_BUFFER, it, "% system command buffer for swapchain buffer #%",
                                    cast(SystemCommandBufferKind) it_index,
                                    swapchain_buffer_index);
            }
        }

        frame_data_it += 1;
    }
}

vendorIdToString :: (vendor_id : u32) -> string #no_context {
    info := type_info(PCIVendorID);

    for info.values {
        if it == vendor_id {
            return info.names[it_index];
        }
    }

    return "Unknown";
}
