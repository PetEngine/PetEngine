// @Cleanup: Reorder fields
VulkanDevice :: struct {
    #as using public_data : Device;

    MINIMAL_SUPPORTED_API_VERSION :: VK_API_VERSION_1_2;
    LATEST_VULKAN_MINOR_VERSION   :: 3;

    need_to_recreate_swapchain : bool;

    api_version : u32;

    instance        : VkInstance;
    physical_device : VkPhysicalDevice;
    device          : VkDevice;

    queues : [QUEUE_TYPES_COUNT] Queue;

    surface            : VkSurfaceKHR;
    swapchain          : VkSwapchainKHR;
    swapchain_textures : StaticArray(VulkanTexture, MAX_SWAPCHAIN_BUFFERS);

    frame_data : StaticArray(FrameData, MAX_FRAME_BUFFERING);

    messenger      : VkDebugUtilsMessengerEXT;
    message_hashes : [..] u32;

    // @TODO: #ContextDependency
    jai_context : *Context;

    loader : VulkanLoader;

    properties11      : VkPhysicalDeviceVulkan11Properties;
    properties12      : VkPhysicalDeviceVulkan12Properties;
    limits            : VkPhysicalDeviceLimits;
    memory_properties : VkPhysicalDeviceMemoryProperties2;
}

createVulkanDevice :: (window : *Window, frame_buffering : FrameBuffering) -> *VulkanDevice #must {
    device := pushToArena(*context.pet.persistent_arena, VulkanDevice);

    #insert -> string { return generatePlatformVtableInitialization(Device, "device", "Vulkan"); }

    device.jai_context      = *context;
    device.frame_buffering  = frame_buffering;
    device.frame_data.count = cast,no_check(s64) frame_buffering;

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

    device.api_version = min(instance_api_version, physical_device_api_version);
    infoMessage("Using Vulkan API version: %.%.%.%",
                VK_API_VERSION_VARIANT(device.api_version),
                VK_API_VERSION_MAJOR(device.api_version),
                VK_API_VERSION_MINOR(device.api_version),
                VK_API_VERSION_PATCH(device.api_version));

    vkGetPhysicalDeviceMemoryProperties2(device.physical_device, *device.memory_properties);

    gatherQueuesInfo(device);
    createDevice(device, *enabled_device_extensions);
    loadVulkanDeviceExtensionsFunctions(*device.loader, device.device, *enabled_device_extensions);
    getQueues(device);
    createSurface(device, window);
    recreateVulkanSwapchain(device, window);
    createSemaphores(device);
    createFences(device);
    createCommandPools(device);
    createCommandBuffers(device);
    createSystemCommandBuffers(device);

    return device;
}

destroyVulkanDevice :: (device_ : *Device) {
    device := cast(*VulkanDevice) device_;

    // @Important: Should be the first call
    waitVulkanDeviceIdle(device);

    for device.frame_data {
        for it.command_pools {
            if it != VK_NULL_HANDLE {
                // @TODO: VkAllocationCallbacks
                vkDestroyCommandPool(device.device, it, null);
            }
        }

        for it.fences {
            if it != VK_NULL_HANDLE {
                // @TODO: VkAllocationCallbacks
                vkDestroyFence(device.device, it, null);
            }
        }

        for it.semaphores {
            // @TODO: VkAllocationCallbacks
            vkDestroySemaphore(device.device, it, null);
        }
    }

    for device.swapchain_textures {
        if it.view != VK_NULL_HANDLE {
            // @TODO: #Views.
            // @TODO: VkAllocationCallbacks
            vkDestroyImageView(device.device, it.view, null);
        }

        if it.name {
            Basic.free(it.name.data);
        }
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

beginVulkanFrame :: (device_ : *Device, window : *Window) {
    device := cast(*VulkanDevice) device_;
    assertThreadKind(.MAIN);

    //
    // Go to the next frame data
    //
    device.frame_index = (device.frame_index + 1) % cast(u8) device.frame_data.count;
    frame_data := *device.frame_data[device.frame_index];

    //
    // Wait for current frame command pools memory
    //
    debugCheckVK(vkWaitForFences(device.device, frame_data.fences.count, frame_data.fences.data, VK_TRUE, 0xFFFF_FFFF_FFFF_FFFF));

    //
    // Reset command pools
    //
    for frame_data.command_pools {
        debugCheckVK(vkResetCommandPool(device.device, it, 0));
    }

    //
    // Begin used command buffers
    //
    {
        begin_info := VkCommandBufferBeginInfo.{
            flags = .VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT
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

    if device.need_to_recreate_swapchain {
        recreateVulkanSwapchain(device, window);
    }

    //
    // Acquire next swapchain buffer
    //
    {
        acquire_info := VkAcquireNextImageInfoKHR.{
            swapchain  = device.swapchain,
            timeout    = 0xFFFF_FFFF_FFFF_FFFF,
            semaphore  = frame_data.semaphores[SemaphoreKind.ACQUIRE_IMAGE],
            fence      = VK_NULL_HANDLE,
            deviceMask = 1
        };

        back_buffer_index : u32 = ---;
        debugCheckVK(device.loader.extensions.device.required.vkAcquireNextImage2KHR(device.device, *acquire_info, *back_buffer_index));

        device.back_buffer_index = cast,no_check(u8) back_buffer_index;
    }
}

// @TODO: Revisit submits and post frame job
endVulkanFrame :: (device_ : *Device) {
    device := cast(*VulkanDevice) device_;
    assertThreadKind(.MAIN);

    frame_data := *device.frame_data[device.frame_index];

    //
    // End used command buffers
    //
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

    //
    // Submit frame job
    //
    {
        submit_info : VkSubmitInfo;

        WHICH_STAGE_WILL_WAIT_FOR_THE_SEMAPHORE :: VkPipelineStageFlags.[
            .VK_PIPELINE_STAGE_VERTEX_SHADER_BIT | .VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT | .VK_PIPELINE_STAGE_TRANSFER_BIT,
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
                    submit_info.pWaitSemaphores      = *frame_data.semaphores[SemaphoreKind.ACQUIRE_IMAGE];
                    submit_info.signalSemaphoreCount = 1;
                    submit_info.pSignalSemaphores    = *frame_data.semaphores[SemaphoreKind.GRAPHICS_DONE];

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

    //
    // Post frame job
    //
    {
        post_frame_command_buffer := frame_data.system_command_buffers[SystemCommandBufferKind.POST_FRAME];
        back_buffer               := *device.swapchain_textures[device.back_buffer_index];
        fence_to_signal           := frame_data.fences[QueueType.GRAPHICS];

        begin_info := VkCommandBufferBeginInfo.{
            flags = .VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT
        };

        debugCheckVK(vkBeginCommandBuffer(post_frame_command_buffer, *begin_info));
        {
            assert(back_buffer.current_owner == .GRAPHICS);
            changeVulkanTextureLayout(post_frame_command_buffer, back_buffer, .VK_IMAGE_LAYOUT_PRESENT_SRC_KHR);
        }
        debugCheckVK(vkEndCommandBuffer(post_frame_command_buffer));

        debugCheckVK(vkResetFences(device.device, 1, *fence_to_signal));

        submit_info := VkSubmitInfo.{
            waitSemaphoreCount   = 1,
            pWaitSemaphores      = ifx  frame_data.command_buffers_used[QueueType.GRAPHICS] > 0
                                   then *frame_data.semaphores[SemaphoreKind.GRAPHICS_DONE]
                                   else *frame_data.semaphores[SemaphoreKind.ACQUIRE_IMAGE],
            pWaitDstStageMask    = VkPipelineStageFlags.[ .VK_PIPELINE_STAGE_ALL_COMMANDS_BIT ].data,
            commandBufferCount   = 1,
            pCommandBuffers      = *post_frame_command_buffer,
            signalSemaphoreCount = 1,
            pSignalSemaphores    = *frame_data.semaphores[SemaphoreKind.POST_FRAME]
        };

        debugCheckVK(vkQueueSubmit(device.queues[QueueType.GRAPHICS].handle, 1, *submit_info, fence_to_signal));
    }

    //
    // Present
    //
    {
        back_buffer_indices := u32.[
            device.back_buffer_index
        ];

        present_info := VkPresentInfoKHR.{
            waitSemaphoreCount = 1,
            pWaitSemaphores    = *frame_data.semaphores[SemaphoreKind.POST_FRAME],
            swapchainCount     = 1,
            pSwapchains        = *device.swapchain,
            pImageIndices      = back_buffer_indices.data,
            pResults           = null
        };

        result := device.loader.extensions.device.required.vkQueuePresentKHR(device.queues[QueueType.GRAPHICS].handle, *present_info);
        if result == .VK_ERROR_OUT_OF_DATE_KHR {
            device.need_to_recreate_swapchain = true;
        } else {
            // VK_SUBOPTIMAL_KHR seems to be OK. The only platform where I had this VkResult code was Android,
            // so let's just do not bother ourselves with it for now.
            debugCheckVK(result, strict = false);
        }
    }
}

waitVulkanDeviceIdle :: (device_ : *Device) {
    assertThreadKind(.MAIN);
    device := cast(*VulkanDevice) device_;

    debugCheckVK(vkDeviceWaitIdle(device.device));
}

getVulkanSwapchainTexture :: inline (device_ : *Device, swapchain_buffer_index : u32) -> *Texture {
    device := cast(*VulkanDevice) device_;
    return *device.swapchain_textures[swapchain_buffer_index];
}

setVulkanObjectName :: (device : *VulkanDevice, object : $T, name : string) {
    #if DEBUG_BUILD {
        if device.loader.extensions.instance.optional.vkSetDebugUtilsObjectNameEXT {
            #if T == {
                case VkInstance;               OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_INSTANCE;
                case VkPhysicalDevice;         OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_PHYSICAL_DEVICE;
                case VkDevice;                 OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_DEVICE;
                case VkQueue;                  OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_QUEUE;
                case VkSemaphore;              OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_SEMAPHORE;
                case VkCommandBuffer;          OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_COMMAND_BUFFER;
                case VkFence;                  OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_FENCE;
                case VkDeviceMemory;           OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_DEVICE_MEMORY;
                case VkBuffer;                 OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_BUFFER;
                case VkImage;                  OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_IMAGE;
                case VkImageView;              OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_IMAGE_VIEW;
                case VkShaderModule;           OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_SHADER_MODULE;
                case VkPipelineCache;          OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_PIPELINE_CACHE;
                case VkPipelineLayout;         OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_PIPELINE_LAYOUT;
                case VkRenderPass;             OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_RENDER_PASS;
                case VkPipeline;               OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_PIPELINE;
                case VkDescriptorSetLayout;    OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_DESCRIPTOR_SET_LAYOUT;
                case VkFramebuffer;            OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_FRAMEBUFFER;
                case VkCommandPool;            OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_COMMAND_POOL;
                case VkSurfaceKHR;             OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_SURFACE_KHR;
                case VkSwapchainKHR;           OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_SWAPCHAIN_KHR;
                case VkDebugUtilsMessengerEXT; OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_DEBUG_UTILS_MESSENGER_EXT;
                case;                          OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_UNKNOWN;
                    #assert false "Unhandled Vk* type";
            }

            object_name := pushToArena(*context.pet.per_frame_arena, s8, name.count + 1);
            memcpy(object_name, name.data, name.count);

            name_info := VkDebugUtilsObjectNameInfoEXT.{
                objectType   = OBJECT_TYPE,
                objectHandle = cast(u64) object,
                pObjectName  = object_name
            };

            debugCheckVK(device.loader.extensions.instance.optional.vkSetDebugUtilsObjectNameEXT(device.device, *name_info));
        }
    }
}

setVulkanObjectName :: (device : *VulkanDevice, object : $T, $format : string, args : ..Any) {
    #if DEBUG_BUILD {
        if device.loader.extensions.instance.optional.vkSetDebugUtilsObjectNameEXT {
            builder : Basic.String_Builder;
            builder.allocator = Basic.temp;

            Basic.print(*builder, format, ..args);
            Basic.append(*builder, "\0");

            #if T == {
                case VkInstance;               OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_INSTANCE;
                case VkPhysicalDevice;         OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_PHYSICAL_DEVICE;
                case VkDevice;                 OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_DEVICE;
                case VkQueue;                  OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_QUEUE;
                case VkSemaphore;              OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_SEMAPHORE;
                case VkCommandBuffer;          OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_COMMAND_BUFFER;
                case VkFence;                  OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_FENCE;
                case VkDeviceMemory;           OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_DEVICE_MEMORY;
                case VkBuffer;                 OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_BUFFER;
                case VkImage;                  OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_IMAGE;
                case VkImageView;              OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_IMAGE_VIEW;
                case VkShaderModule;           OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_SHADER_MODULE;
                case VkPipelineCache;          OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_PIPELINE_CACHE;
                case VkPipelineLayout;         OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_PIPELINE_LAYOUT;
                case VkRenderPass;             OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_RENDER_PASS;
                case VkPipeline;               OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_PIPELINE;
                case VkDescriptorSetLayout;    OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_DESCRIPTOR_SET_LAYOUT;
                case VkFramebuffer;            OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_FRAMEBUFFER;
                case VkCommandPool;            OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_COMMAND_POOL;
                case VkSurfaceKHR;             OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_SURFACE_KHR;
                case VkSwapchainKHR;           OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_SWAPCHAIN_KHR;
                case VkDebugUtilsMessengerEXT; OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_DEBUG_UTILS_MESSENGER_EXT;
                case;                          OBJECT_TYPE :: VkObjectType.VK_OBJECT_TYPE_UNKNOWN;
                    #assert false "Unhandled Vk* type";
            }

            object_name := Basic.builder_to_string(*builder,, allocator = Basic.temp);

            name_info := VkDebugUtilsObjectNameInfoEXT.{
                objectType   = OBJECT_TYPE,
                objectHandle = cast(u64) object,
                pObjectName  = cast(*s8) object_name.data
            };

            debugCheckVK(device.loader.extensions.instance.optional.vkSetDebugUtilsObjectNameEXT(device.device, *name_info));
        }
    }
}

#scope_file

Hash :: #import "Hash";

FrameData :: struct {
    semaphores : [#run Basic.enum_highest_value(SemaphoreKind) + 1] VkSemaphore;
    fences     : [VulkanDevice.queues.count]                        VkFence;

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
    builder.allocator = Basic.temp;

    layers_to_apply : [..] *s8;
    layers_to_apply.allocator = Basic.temp;

    {
        available_layers : [] VkLayerProperties;
        debugCheckVK(vkEnumerateInstanceLayerProperties(cast(*u32) *available_layers.count, null));

        available_layers.data = pushToArena(*context.pet.per_frame_arena, VkLayerProperties, available_layers.count);
        debugCheckVK(vkEnumerateInstanceLayerProperties(cast(*u32) *available_layers.count, available_layers.data));

        #if PRINT_VERBOSE_MESSAGES {
            Basic.print(*builder, "Available instance layers (%):\n", available_layers.count);
            for available_layers {
                Basic.print(*builder, "    %\n", to_string(cast(*u8) it.layerName.data));
            }
            verboseMessage("%", Basic.builder_to_string(*builder,, allocator = Basic.temp));
        }

        REQUIRED_LAYERS, OPTIONAL_LAYERS :: #run gatherVulkanLayers();

        for required_layer : REQUIRED_LAYERS {
            layer_found : bool;

            for available_layers {
                if to_string(cast(*u8) it.layerName.data) == required_layer {
                    layer_found = true;
                    break;
                }
            }

            if layer_found {
                Basic.array_add(*layers_to_apply, cast(*s8) required_layer.data);
            } else {
                assertMessage("Required instance layer \"%\" has not been found in available instance layers", required_layer);
            }
        }

        for optional_layer : OPTIONAL_LAYERS {
            layer_found : bool;

            for available_layers {
                if to_string(cast(*u8) it.layerName.data) == optional_layer {
                    layer_found = true;
                    break;
                }
            }

            if layer_found {
                Basic.array_add(*layers_to_apply, cast(*s8) optional_layer.data);
            } else {
                warningMessage("Optional instance layer \"%\" has not been found in available instance layers", optional_layer);
            }
        }

        Basic.print(*builder, "Applying instance layers (%):\n", layers_to_apply.count);
        for layers_to_apply {
            Basic.print(*builder, "    %\n", to_string(cast(*u8) it));
        }
        infoMessage("%", Basic.builder_to_string(*builder,, allocator = Basic.temp));
    }

    extensions_to_apply : [..] *s8;
    extensions_to_apply.allocator = Basic.temp;

    {
        available_extensions : [] VkExtensionProperties;
        debugCheckVK(vkEnumerateInstanceExtensionProperties(null, cast(*u32) *available_extensions.count, null));

        available_extensions.data = pushToArena(*context.pet.per_frame_arena, VkExtensionProperties, available_extensions.count);
        debugCheckVK(vkEnumerateInstanceExtensionProperties(null, cast(*u32) *available_extensions.count, available_extensions.data));

        #if PRINT_VERBOSE_MESSAGES {
            Basic.print(*builder, "Available instance extensions (%):\n", available_extensions.count);
            for available_extensions {
                Basic.print(*builder, "    %\n", to_string(cast(*u8) it.extensionName.data));
            }
            verboseMessage("%", Basic.builder_to_string(*builder,, allocator = Basic.temp));
        }

        #if DEBUG_BUILD {
            validation_extensions : [] VkExtensionProperties;
            debugCheckVK(vkEnumerateInstanceExtensionProperties(cast(*s8) "VK_LAYER_KHRONOS_validation".data, cast(*u32) *validation_extensions.count, null));

            validation_extensions.data = pushToArena(*context.pet.per_frame_arena, VkExtensionProperties, validation_extensions.count);
            debugCheckVK(vkEnumerateInstanceExtensionProperties(cast(*s8) "VK_LAYER_KHRONOS_validation".data, cast(*u32) *validation_extensions.count, validation_extensions.data));

            #if PRINT_VERBOSE_MESSAGES {
                Basic.print(*builder, "Available VK_LAYER_KHRONOS_validation's instance extensions (%):\n", validation_extensions.count);
                for validation_extensions {
                    Basic.print(*builder, "    %\n", to_string(cast(*u8) it.extensionName.data));
                }
                verboseMessage("%", Basic.builder_to_string(*builder,, allocator = Basic.temp));
            }
        }

        REQUIRED_EXTENSIONS, OPTIONAL_EXTENSIONS :: #run gatherVulkanInstanceExtensions();

        for required_extension : REQUIRED_EXTENSIONS {
            extension_found : bool;

            for available_extensions {
                if to_string(cast(*u8) it.extensionName.data) == required_extension {
                    extension_found = true;
                    break;
                }
            }

            if extension_found {
                Basic.array_add(enabled_instance_extensions, required_extension);
                Basic.array_add(*extensions_to_apply, cast(*s8) required_extension.data);
            } else {
                assertMessage("Required instance extension \"%\" has not been found in available instance extensions", required_extension);
            }
        }

        for optional_extension : OPTIONAL_EXTENSIONS {
            extension_found : bool;

            for available_extensions {
                if to_string(cast(*u8) it.extensionName.data) == optional_extension {
                    extension_found = true;
                    break;
                }
            }

            if extension_found {
                Basic.array_add(enabled_instance_extensions, optional_extension);
                Basic.array_add(*extensions_to_apply, cast(*s8) optional_extension.data);
            } else {
                warningMessage("Optional instance extension \"%\" has not been found in available instance extensions", optional_extension);
            }
        }

        #if DEBUG_BUILD {
            extension_found : bool;

            for validation_extensions {
                if to_string(cast(*u8) it.extensionName.data) == "VK_EXT_validation_features" {
                    extension_found = true;
                    break;
                }
            }

            if extension_found {
                Basic.array_add(enabled_instance_extensions, "VK_EXT_validation_features");
                Basic.array_add(*extensions_to_apply, cast(*s8) "VK_EXT_validation_features".data);
            } else {
                warningMessage("Optional instance extension \"VK_EXT_validation_features\" has not been found in available VK_LAYER_KHRONOS_validation's instance extensions");
            }
        }

        Basic.print(*builder, "Applying instance extensions (%):\n", enabled_instance_extensions.count);
        for enabled_instance_extensions.* {
            Basic.print(*builder, "    %\n", it);
        }
        infoMessage("%", Basic.builder_to_string(*builder,, allocator = Basic.temp));
    }

    nt_engine_name : [ENGINE_NAME.count + 1] s8;
    memcpy(nt_engine_name.data, ENGINE_NAME.data, ENGINE_NAME.count);

    application_info := VkApplicationInfo.{
        pApplicationName   = null, // @TODO: window.title or something, don't know
        applicationVersion = 0,
        pEngineName        = nt_engine_name.data,
        engineVersion      = ENGINE_VERSION,
        apiVersion         = api_version
    };

    instance_create_info := VkInstanceCreateInfo.{
        flags                   = 0,
        pApplicationInfo        = *application_info,
        enabledLayerCount       = cast(u32) layers_to_apply.count,
        ppEnabledLayerNames     = layers_to_apply.data,
        enabledExtensionCount   = cast(u32) extensions_to_apply.count,
        ppEnabledExtensionNames = extensions_to_apply.data
    };

    #if DEBUG_BUILD {
        ENABLED_VALIDATION_FEATURES :: VkValidationFeatureEnableEXT.[
            .VK_VALIDATION_FEATURE_ENABLE_GPU_ASSISTED_EXT,
//          .VK_VALIDATION_FEATURE_ENABLE_BEST_PRACTICES_EXT,
            .VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXT
        ];

        validation_features := VkValidationFeaturesEXT.{
            enabledValidationFeatureCount = ENABLED_VALIDATION_FEATURES.count,
            pEnabledValidationFeatures    = ENABLED_VALIDATION_FEATURES.data
        };

        instance_create_info.pNext = *validation_features;
    }

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
        #if MESSAGE_DEDUPLICATION_STRATEGY == {
            case .VUID_HASH;
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

                vuid_string := string.{ vuid_end - vuid_start, vuid_start };

                hash := Hash.get_hash(vuid_string);

                should_be_printed := Basic.array_add_if_unique(*device.message_hashes, hash);
            case .MESSAGE_HASH;
                hash := Hash.get_hash(message);

                should_be_printed := Basic.array_add_if_unique(*device.message_hashes, hash);
            case;
                should_be_printed :: true;
        }

        if should_be_printed {
            SHORTEN_MESSAGE :: true;
            #if SHORTEN_MESSAGE {
                index := String.find_index_from_left(message, "Object");
                if index != -1 {
                    builder : Basic.String_Builder;
                    builder.allocator = Basic.temp;

                    severity_and_vuid := string.{ index, message.data };
                    Basic.append(*builder, severity_and_vuid);

                    advance(*message, index);

                    index = String.find_index_from_left(message, "MessageID");
                    if index != -1 {
                        advance(*message, index);

                        index = String.find_index_from_left(message, "| ");
                        if index != -1 {
                            advance(*message, index + 2);
                        }
                    }

                    Basic.append(*builder, message);

                    message = Basic.builder_to_string(*builder,, allocator = Basic.temp);
                }
            }

            MESSAGE_FORMAT :: #string END
%
--------------------------------------------------------------------------------------------------------
END;

            if messageSeverity & .VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT {
                errorMessage(MESSAGE_FORMAT, message);
            } else if messageSeverity & .VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT {
                warningMessage(MESSAGE_FORMAT, message);
            } else if messageSeverity & .VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT {
                verboseMessage(MESSAGE_FORMAT, message);
            } else {
                infoMessage(MESSAGE_FORMAT, message);
            }
        }
    }

    return VK_FALSE;
}

initMessengerCallback :: (device : *VulkanDevice) {
    if device.loader.extensions.instance.optional.vkCreateDebugUtilsMessengerEXT {
        severities : VkDebugUtilsMessageSeverityFlagsEXT = .VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT
                                                         | .VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT
                                                         | .VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;

        #if PRINT_VERBOSE_MESSAGES {
            severities |= .VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT;
        }

        create_info := VkDebugUtilsMessengerCreateInfoEXT.{
            flags           = 0,
            messageSeverity = severities,
            messageType     = .VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT
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
    physical_devices : [] VkPhysicalDevice;
    debugCheckVK(vkEnumeratePhysicalDevices(device.instance, cast(*u32) *physical_devices.count, null));

    physical_devices.data = pushToArena(*context.pet.per_frame_arena, VkPhysicalDevice, physical_devices.count);
    debugCheckVK(vkEnumeratePhysicalDevices(device.instance, cast(*u32) *physical_devices.count, physical_devices.data));

    physical_device_properties : VkPhysicalDeviceProperties2;
    properties := *physical_device_properties.properties;

    COMPATIBLE_PHYSICAL_DEVICE_TYPES :: VkPhysicalDeviceType.[
        .VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU,
        .VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU
    ];

    memory_properties : VkPhysicalDeviceMemoryProperties2;

    available_device_memory : VkDeviceSize;

    for type : COMPATIBLE_PHYSICAL_DEVICE_TYPES {
        max_memory_size : VkDeviceSize;

        for physical_devices {
            vkGetPhysicalDeviceProperties2(it, *physical_device_properties);

            if properties.deviceType == type {
                vkGetPhysicalDeviceMemoryProperties2(it, *memory_properties);

                memory_heaps := toView(memory_properties.memoryProperties.memoryHeaps.data,
                                       memory_properties.memoryProperties.memoryHeapCount);

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
                    device.physical_device = it;
                }
            }
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

    infoMessage("Using % physical device with % GB of memory", device.type, available_device_memory / 1_073_741_824.0);

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
                formatHex(properties.driverVersion),
                vendorIdToString(properties.vendorID),
                formatHex(properties.vendorID),
                formatHex(properties.deviceID),
                properties.deviceType,
                cast(string) properties.deviceName);

    physical_device_properties.pNext = *device.properties11;
    device.properties11.pNext        = *device.properties12;

    vkGetPhysicalDeviceProperties2(device.physical_device, *physical_device_properties);

    DRIVER_INFO_MESSAGE :: #string END
Driver info:
    Driver ID:           %
    Driver name:         %
    Driver info:         %
    Conformance version: %.%.%.%
END;

    infoMessage(DRIVER_INFO_MESSAGE,
                device.properties12.driverID,
                cast(string) device.properties12.driverName,
                cast(string) device.properties12.driverInfo,
                device.properties12.conformanceVersion.major,
                device.properties12.conformanceVersion.minor,
                device.properties12.conformanceVersion.subminor,
                device.properties12.conformanceVersion.patch);

    device.limits = properties.limits;

    return properties.apiVersion;
}

findQueueFamily :: ($condition : Code) #expand {
    queues_in_family_used_it := `queues_in_family_used;

    for `queue_family_properties {
        queue_family_flags := it.queueFamilyProperties.queueFlags;

        if #insert,scope() condition {
            `queue_it.family_index      = cast(u32) it_index;
            `queue_it.index_in_family   = queues_in_family_used_it.*;
            queues_in_family_used_it.* += 1;

            assert(queues_in_family_used_it.* <= it.queueFamilyProperties.queueCount,
                   "You are trying to use too many queues from the same family: %/%. Queue family flags: %, queue family index: %. Requested queue type: %",
                   queues_in_family_used_it.*,
                   it.queueFamilyProperties.queueCount,
                   it.queueFamilyProperties.queueFlags,
                   it_index,
                   `queue_type);

            break;
        }

        queues_in_family_used_it += 1;
    }
}

gatherQueuesInfo :: (device : *VulkanDevice) {
    queue_family_properties : [] VkQueueFamilyProperties2;
    vkGetPhysicalDeviceQueueFamilyProperties2(device.physical_device, cast(*u32) *queue_family_properties.count, null);

    queue_family_properties.data = pushToArena(*context.pet.per_frame_arena, VkQueueFamilyProperties2, queue_family_properties.count);
    vkGetPhysicalDeviceQueueFamilyProperties2(device.physical_device, cast(*u32) *queue_family_properties.count, queue_family_properties.data);

    defer Basic.reset_temporary_storage();

    // Print info about available queue families
    #if PRINT_VERBOSE_MESSAGES {
        builder : Basic.String_Builder;
        builder.allocator = Basic.temp;

        Basic.print(*builder, "Available queue families (%):\n", queue_family_properties.count);

QUEUE_FAMILY_INFO_FORMAT_STRING :: #string END
    [%]: Flags:        %
         Queues count: %
END;

        for queue_family_properties {
            Basic.print(*builder,
                        QUEUE_FAMILY_INFO_FORMAT_STRING,
                        it_index,
                        it.queueFamilyProperties.queueFlags,
                        it.queueFamilyProperties.queueCount);
        }

        verboseMessage("%", Basic.builder_to_string(*builder,, allocator = Basic.temp));
    }

    QUEUE_TYPE_TO_VK_QUEUE_FLAGS :: VkQueueFlags.[
        .VK_QUEUE_GRAPHICS_BIT,
        .VK_QUEUE_COMPUTE_BIT,
        .VK_QUEUE_TRANSFER_BIT,
    ];

    queues_in_family_used := pushToArena(*context.pet.per_frame_arena, u32, queue_family_properties.count);

    // Find queue family indices
    for * queue_it : device.queues {
        queue_type := cast(QueueType) it_index;

        vk_queue_flags       := QUEUE_TYPE_TO_VK_QUEUE_FLAGS[queue_type];
        vk_queue_other_flags := (.VK_QUEUE_GRAPHICS_BIT | .VK_QUEUE_COMPUTE_BIT) & ~vk_queue_flags;

        // 1. We are trying to find a queue family that supports only concrete queue type (ideal situation).
        findQueueFamily(#code (queue_family_flags & `vk_queue_flags) && !(queue_family_flags & `vk_queue_other_flags));

        if queue_it.family_index == 0xFFFF_FFFF {
            // 2. We are trying to find a queue family that supports needed queue type, but may support several queue types (ok situation).
            findQueueFamily(#code queue_family_flags & `vk_queue_flags);

            if queue_type == .ASYNC_TRANSFER && queue_it.family_index == 0xFFFF_FFFF {
                // According to vulkan spec, declaring transfer queue capability is optional.
                findQueueFamily(#code queue_family_flags & (.VK_QUEUE_GRAPHICS_BIT | .VK_QUEUE_COMPUTE_BIT));
            }
        }

        assert(queue_it.family_index != 0xFFFF_FFFF, "% queue family was not found", queue_type);
    }

    // Print info about queues
    {
        builder : Basic.String_Builder;
        builder.allocator = Basic.temp;

        Basic.append(*builder, "Queues info:\n");

QUEUE_INFO_FORMAT_STRING :: #string END
    %:
        Family flags: %
        Family index: %
        Index in family: %
END;

        for device.queues {
            Basic.print(*builder,
                        QUEUE_INFO_FORMAT_STRING,
                        cast(QueueType) it_index,
                        queue_family_properties[it.family_index].queueFamilyProperties.queueFlags,
                        it.family_index,
                        it.index_in_family);
        }

        infoMessage("%", Basic.builder_to_string(*builder,, allocator = Basic.temp));
    }
}

// @TODO: VkDeviceMemoryOverallocationCreateInfoAMD (VK_AMD_memory_overallocation_behavior) sounds useful.
createDevice :: (device : *VulkanDevice, enabled_device_extensions : *[..] string) {
    queues_count_per_family : [VulkanDevice.queues.count] u32;
    for device.queues  queues_count_per_family[it.family_index] += 1;

    // @TODO: For now queues have equal priority. Should be tweaked later.
    queues_priorities : [VulkanDevice.queues.count] f32;
    for * queues_priorities  it.* = 1.0;

    queue_create_infos       : [VulkanDevice.queues.count] VkDeviceQueueCreateInfo = ---;
    queue_create_infos_count : u32 = 0;

    for device.queues {
        // queue_create_infos must be unique
        if it.index_in_family > 0 continue;

        queues_count_in_family := queues_count_per_family[it.family_index];
        if queues_count_in_family {
            queue_create_info := *queue_create_infos[queue_create_infos_count];

            queue_create_info.sType            = .VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
            queue_create_info.pNext            = null;
            queue_create_info.flags            = 0;
            queue_create_info.queueFamilyIndex = it.family_index;
            queue_create_info.queueCount       = queues_count_in_family;
            queue_create_info.pQueuePriorities = queues_priorities.data;

            queue_create_infos_count += 1;
        }
    }

    defer Basic.reset_temporary_storage();

    builder : Basic.String_Builder;
    builder.allocator = Basic.temp;

    extensions_to_apply : [..] *s8;
    extensions_to_apply.allocator = Basic.temp;

    {
        available_extensions : [] VkExtensionProperties;
        debugCheckVK(vkEnumerateDeviceExtensionProperties(device.physical_device, null, cast(*u32) *available_extensions.count, null));

        available_extensions.data = pushToArena(*context.pet.per_frame_arena, VkExtensionProperties, available_extensions.count);
        debugCheckVK(vkEnumerateDeviceExtensionProperties(device.physical_device, null, cast(*u32) *available_extensions.count, available_extensions.data));

        #if PRINT_VERBOSE_MESSAGES {
            Basic.print(*builder, "Available device extensions (%):\n", available_extensions.count);
            for available_extensions {
                Basic.print(*builder, "    %\n", to_string(cast(*u8) it.extensionName.data));
            }
            verboseMessage("%", Basic.builder_to_string(*builder,, allocator = Basic.temp));
        }

        REQUIRED_EXTENSIONS, OPTIONAL_EXTENSIONS :: #run gatherVulkanDeviceExtensions();

        for required_extension : REQUIRED_EXTENSIONS {
            extension_found : bool;

            for available_extensions {
                if to_string(cast(*u8) it.extensionName.data) == required_extension {
                    extension_found = true;
                    break;
                }
            }

            if extension_found {
                Basic.array_add(enabled_device_extensions, required_extension);
                Basic.array_add(*extensions_to_apply, cast(*s8) required_extension.data);
            } else {
                assertMessage("Required device extension \"%\" has not been found in available device extensions", required_extension);
            }
        }

        for optional_extension : OPTIONAL_EXTENSIONS {
            extension_found : bool;

            for available_extensions {
                if to_string(cast(*u8) it.extensionName.data) == optional_extension {
                    extension_found = true;
                    break;
                }
            }

            if extension_found {
                Basic.array_add(enabled_device_extensions, optional_extension);
                Basic.array_add(*extensions_to_apply, cast(*s8) optional_extension.data);
            } else {
                warningMessage("Optional device extension \"%\" has not been found in available device extensions", optional_extension);
            }
        }

        Basic.print(*builder, "Applying device extensions (%):\n", enabled_device_extensions.count);
        for enabled_device_extensions.* {
            Basic.print(*builder, "    %\n", it);
        }
        infoMessage("%", Basic.builder_to_string(*builder,, allocator = Basic.temp));
    }

    dynamic_rendering_features : VkPhysicalDeviceDynamicRenderingFeatures;

    features_to_enable := VkPhysicalDeviceFeatures2.{ pNext = *dynamic_rendering_features };
    available_features := VkPhysicalDeviceFeatures2.{ pNext = *dynamic_rendering_features };

    vkGetPhysicalDeviceFeatures2(device.physical_device, *available_features);
    assert(dynamic_rendering_features.dynamicRendering == VK_TRUE);

    // @TODO: #Features. define optional and required features and validate it.

    device_create_info := VkDeviceCreateInfo.{
        pNext                   = *features_to_enable,
        flags                   = 0,
        queueCreateInfoCount    = queue_create_infos_count,
        pQueueCreateInfos       = queue_create_infos.data,
        enabledLayerCount       = 0,    // Deprecated and ignored.
        ppEnabledLayerNames     = null, // Deprecated and ignored.
        enabledExtensionCount   = cast(u32) extensions_to_apply.count,
        ppEnabledExtensionNames = extensions_to_apply.data,
        pEnabledFeatures        = null, // We are using pNext for VkPhysicalDeviceFeatures2
    };

    // @TODO: VkAllocationCallbacks
    debugCheckVK(vkCreateDevice(device.physical_device, *device_create_info, null, *device.device));
}

// @TODO: #NotExistedQueues
getQueues :: (device : *VulkanDevice) {
    for device.queues {
        queue_info := VkDeviceQueueInfo2.{
            flags            = 0,
            queueFamilyIndex = it.family_index,
            queueIndex       = it.index_in_family
        };

        vkGetDeviceQueue2(device.device, *queue_info, *it.handle);
        assert(it.handle != VK_NULL_HANDLE);

        setVulkanObjectName(device, it.handle, "% queue", cast(QueueType) it_index);
    }
}

createSurface :: (device : *VulkanDevice, window : *Window) {
    #if OS == .WINDOWS {
        win32_window := cast(*Win32Window) window;

        create_info := VkWin32SurfaceCreateInfoKHR.{
            flags     = 0,
            hinstance = win32_window.manager.app_instance,
            hwnd      = win32_window.handle
        };

        // @TODO: VkAllocationCallbacks
        debugCheckVK(device.loader.extensions.instance.required.vkCreateWin32SurfaceKHR(device.instance,
                                                                                        *create_info,
                                                                                        null,
                                                                                        *device.surface));
    } else {
        notImplemented();
    }

    // Query is graphics queue supports presentation to created sufrace
    {
        graphics_queue := *device.queues[QueueType.GRAPHICS];

        presentation_supported : VkBool32 = ---;
        debugCheckVK(device.loader.extensions.instance.required.vkGetPhysicalDeviceSurfaceSupportKHR(device.physical_device,
                                                                                                     graphics_queue.family_index,
                                                                                                     device.surface,
                                                                                                     *presentation_supported));
        if !presentation_supported {
            assertMessage("% queue #% in #% queue family does not support presentation to created surface",
                          QueueType.GRAPHICS,
                          graphics_queue.index_in_family,
                          graphics_queue.family_index);
        }
    }
}

recreateVulkanSwapchain :: (device : *VulkanDevice, window : *Window) {
    assertThreadKind(.MAIN);

    //
    // Surface formats
    //

    surface_formats : [] VkSurfaceFormatKHR;
    debugCheckVK(device.loader.extensions.instance.required.vkGetPhysicalDeviceSurfaceFormatsKHR(device.physical_device,
                                                                                                 device.surface,
                                                                                                 cast(*u32) *surface_formats.count,
                                                                                                 null));

    surface_formats.data = pushToArena(*context.pet.per_frame_arena, VkSurfaceFormatKHR, surface_formats.count);
    debugCheckVK(device.loader.extensions.instance.required.vkGetPhysicalDeviceSurfaceFormatsKHR(device.physical_device,
                                                                                                 device.surface,
                                                                                                 cast(*u32) *surface_formats.count,
                                                                                                 surface_formats.data));

    builder : Basic.String_Builder;
    builder.allocator = Basic.temp;

    #if PRINT_VERBOSE_MESSAGES {
        Basic.append(*builder, "Available surface formats:");
        for surface_formats {
            Basic.print(*builder, "\n    Format: %, space: %", it.format, it.colorSpace);
        }

        verboseMessage("%", Basic.builder_to_string(*builder,, allocator = Basic.temp));
    }

    // @TODO: #HDR. Hardware HDR support
    REQUESTED_SURFACE_FORMAT :: VkFormat.VK_FORMAT_B8G8R8A8_SRGB;
    allowed_surface_format : *VkSurfaceFormatKHR;

    for * surface_formats {
        // @TODO: #HDR. Hardware HDR support
        if it.format == REQUESTED_SURFACE_FORMAT && it.colorSpace == .VK_COLOR_SPACE_SRGB_NONLINEAR_KHR {
            allowed_surface_format = it;
            break;
        }
    }

    if allowed_surface_format {
        infoMessage("Using surface format: %, space: %", allowed_surface_format.format, allowed_surface_format.colorSpace);
    } else {
        assertMessage("Chosen surface format (%) is not supported on this device", REQUESTED_SURFACE_FORMAT);
    }

    //
    // Surface capabilities
    //

    surface_capabilities : VkSurfaceCapabilitiesKHR = ---;
    debugCheckVK(device.loader.extensions.instance.required.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device.physical_device,
                                                                                                      device.surface,
                                                                                                      *surface_capabilities));

    requested_swapchain_buffers_count := cast,no_check(u32) device.frame_buffering;
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

    if requested_swapchain_buffers_count > VulkanDevice.swapchain_textures.capacity {
        assertMessage("You want too many swapchain buffers: %. If you really need that much you can increase Device.MAX_SWAPCHAIN_BUFFERS",
                      requested_swapchain_buffers_count);
    }

    surface_extent := VkExtent2D.{
        width  = window.surface.width,
        height = window.surface.height
    };

    if !memcmp(*surface_capabilities.maxImageExtent, *(VkExtent2D.{}), size_of(VkExtent2D)) {
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

    //
    // Present mode
    //

    present_modes : [] VkPresentModeKHR;
    debugCheckVK(device.loader.extensions.instance.required.vkGetPhysicalDeviceSurfacePresentModesKHR(device.physical_device,
                                                                                                      device.surface,
                                                                                                      cast(*u32) *present_modes.count,
                                                                                                      null));

    present_modes.data = pushToArena(*context.pet.per_frame_arena, VkPresentModeKHR, present_modes.count);
    debugCheckVK(device.loader.extensions.instance.required.vkGetPhysicalDeviceSurfacePresentModesKHR(device.physical_device,
                                                                                                      device.surface,
                                                                                                      cast(*u32) *present_modes.count,
                                                                                                      present_modes.data));

    // @TODO: #Settings.
    //     Vsync off, allow tearing off: VK_PRESENT_MODE_MAILBOX_KHR
    //     Vsync off, allow tearing on:  VK_PRESENT_MODE_IMMEDIATE_KHR
    //     Vsync on,  allow tearing off: VK_PRESENT_MODE_FIFO_KHR
    //     Vsync on,  allow tearing on:  VK_PRESENT_MODE_FIFO_RELAXED_KHR
    REQUESTED_PRESENT_MODE :: VkPresentModeKHR.VK_PRESENT_MODE_MAILBOX_KHR;

    present_mode : VkPresentModeKHR = ---;
    if Basic.array_find(present_modes, REQUESTED_PRESENT_MODE) {
        present_mode = REQUESTED_PRESENT_MODE;
    } else {
        // FIFO is the only one which is guaranteed to be supported acording to Vulkan spec.
        present_mode = .VK_PRESENT_MODE_FIFO_KHR;
        warningMessage("Requested present mode (%) is not supported, % will be used", REQUESTED_PRESENT_MODE, present_mode);
    }

    queue_families_having_access_to_swapchain_images := u32.[
        device.queues[QueueType.GRAPHICS].family_index
    ];

    create_info := VkSwapchainCreateInfoKHR.{
        flags                 = 0,
        surface               = device.surface,
        minImageCount         = requested_swapchain_buffers_count,
        imageFormat           = allowed_surface_format.format,
        imageColorSpace       = allowed_surface_format.colorSpace,
        imageExtent           = surface_extent,
        imageArrayLayers      = 1,
        imageUsage            = REQUESTED_USAGE_FLAGS,
        imageSharingMode      = .VK_SHARING_MODE_EXCLUSIVE,
        queueFamilyIndexCount = cast(u32) queue_families_having_access_to_swapchain_images.count,
        pQueueFamilyIndices   = queue_families_having_access_to_swapchain_images.data,
        preTransform          = .VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
        compositeAlpha        = .VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        presentMode           = present_mode,
        clipped               = VK_TRUE,
        oldSwapchain          = device.swapchain
    };

    // @TODO: VkAllocationCallbacks
    debugCheckVK(device.loader.extensions.device.required.vkCreateSwapchainKHR(device.device, *create_info, null, *device.swapchain));
    device.need_to_recreate_swapchain = false;

    if create_info.oldSwapchain != VK_NULL_HANDLE {
        // @TODO: VkAllocationCallbacks
        device.loader.extensions.device.required.vkDestroySwapchainKHR(device.device, create_info.oldSwapchain, null);
    }

    //
    // Initialize swapchain images
    //

    swapchain_buffers_count : u32 = ---;
    device.loader.extensions.device.required.vkGetSwapchainImagesKHR(device.device,
                                                                     device.swapchain,
                                                                     *swapchain_buffers_count,
                                                                     null);
    device.swapchain_buffers_count = cast,no_check(u8) swapchain_buffers_count;
    assert(device.swapchain_buffers_count > 0);

    if device.swapchain_buffers_count > VulkanDevice.swapchain_textures.capacity {
        assertMessage("Swapchain buffers overflow: %/%. It seems like driver does some weird things, so you may just increase Device.MAX_SWAPCHAIN_BUFFERS",
                      device.swapchain_buffers_count,
                      VulkanDevice.swapchain_textures.capacity);
    }

    infoMessage("Requested swapchain images: %, got: %", requested_swapchain_buffers_count, device.swapchain_buffers_count);

    swapchain_images : [VulkanDevice.swapchain_textures.capacity] VkImage;
    device.loader.extensions.device.required.vkGetSwapchainImagesKHR(device.device,
                                                                     device.swapchain,
                                                                     *swapchain_buffers_count,
                                                                     swapchain_images.data);
    assert(swapchain_buffers_count == device.swapchain_buffers_count);

    device.swapchain_textures.count = device.swapchain_buffers_count;

    swapchain_images_it := swapchain_images.data;

    // @TODO: #Settings. Get back buffer clear color from settings.
    clear_color := gammaToLinear(.{ 0.3, 0.3, 0.3, 0.0 });

    // @TODO: #VulkanTexture #SwapchainBuffers. Add these images to texture manager
    for * device.swapchain_textures {
        it.dimension             = ._2D;
        it.format                = vulkanFormatToTextureFormat(allowed_surface_format.format);
        it.flags                 = .SWAPCHAIN;
        it.width                 = cast(u16) surface_extent.width;
        it.height                = cast(u16) surface_extent.height;
        it.depth                 = 0;
        it.samples_count         = 1;
        it.mips_count            = 1;
        it.clear_value.color_f32 = clear_color;
        it.current_owner         = .GRAPHICS;
        it.possible_owners.count = 1;
        it.possible_owners[0]    = .GRAPHICS;
        it.image                 = swapchain_images_it.*;
        it.current_layout        = .VK_IMAGE_LAYOUT_UNDEFINED;

        #if REQUESTED_USAGE_FLAGS & .VK_IMAGE_USAGE_SAMPLED_BIT          then it.usage |= .SHADER_READ;
        #if REQUESTED_USAGE_FLAGS & .VK_IMAGE_USAGE_STORAGE_BIT          then it.usage |= .SHADER_WRITE;
        #if REQUESTED_USAGE_FLAGS & .VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT then it.usage |= .COLOR_TARGET;

        if !it.name {
            Basic.print(*builder, "Swapchain image #%", it_index);
            it.name = Basic.builder_to_string(*builder); // We need to preserve it, so do not use Basic.temp
        }

        setVulkanObjectName(device, it.image, it.name);

        // @TODO: #Views.
        {
            if it.view {
                // @TODO: VkAllocationCallbacks
                vkDestroyImageView(device.device, it.view, null);
            }

            view_create_info := VkImageViewCreateInfo.{
                flags            = 0,
                image            = it.image,
                viewType         = .VK_IMAGE_VIEW_TYPE_2D,
                format           = allowed_surface_format.format,
                components       = .{
                    r = .VK_COMPONENT_SWIZZLE_R,
                    g = .VK_COMPONENT_SWIZZLE_G,
                    b = .VK_COMPONENT_SWIZZLE_B,
                    a = .VK_COMPONENT_SWIZZLE_A,
                },
                subresourceRange = .{
                    aspectMask     = .VK_IMAGE_ASPECT_COLOR_BIT,
                    baseMipLevel   = 0,
                    levelCount     = 1,
                    baseArrayLayer = 0,
                    layerCount     = 1,
                },
            };

            // @TODO: VkAllocationCallbacks
            debugCheckVK(vkCreateImageView(device.device, *view_create_info, null, *it.view));

            setVulkanObjectName(device, it.view, "% view", it.name);
        }

        swapchain_images_it += 1;
    }
}

createSemaphores :: (device : *VulkanDevice) {
    create_info : VkSemaphoreCreateInfo;

    for * frame_data, frame_index : device.frame_data {
        for * frame_data.semaphores {
            // @TODO: VkAllocationCallbacks
            debugCheckVK(vkCreateSemaphore(device.device, *create_info, null, it));

            setVulkanObjectName(device, it.*, "% semaphore for frame #%", cast(SemaphoreKind) it_index, frame_index);
        }
    }
}

createFences :: (device : *VulkanDevice) {
    create_info := VkFenceCreateInfo.{
        flags = .VK_FENCE_CREATE_SIGNALED_BIT,
    };

    for * frame_data, frame_index : device.frame_data {
        for * frame_data.fences {
            // @TODO: VkAllocationCallbacks
            debugCheckVK(vkCreateFence(device.device, *create_info, null, it));

            setVulkanObjectName(device, it.*, "% fence for frame #%", cast(QueueType) it_index, frame_index);
        }
    }
}

// Actually, we do not want to create additional command pools for queues we don't have,
// but anyway it's just chipper to have slightly bigger amount of them.
// Maybe someday we will have better behaviour for not existed compute and transfer queues.
// @TODO: #NotExistedQueues
createCommandPools :: (device : *VulkanDevice) {
    create_info := VkCommandPoolCreateInfo.{
        queueFamilyIndex = VK_QUEUE_FAMILY_IGNORED // Will be set in a loop
    };

    for * frame_data, frame_index : device.frame_data {
        queues_it := device.queues.data;

        for * frame_data.command_pools {
            create_info.queueFamilyIndex = queues_it.family_index;

            // @TODO: VkAllocationCallbacks
            debugCheckVK(vkCreateCommandPool(device.device, *create_info, null, it));

            setVulkanObjectName(device, it.*, "% command pool for frame #%", cast(QueueType) it_index, frame_index);

            queues_it += 1;
        }
    }
}

createCommandBuffers :: (device : *VulkanDevice) {
    allocation_info := VkCommandBufferAllocateInfo.{
        commandPool        = null, // Will be set in a loop
        level              = .VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        commandBufferCount = cast(u32) Device.MAX_COMMAND_BUFFERS
    };

    for * frame_data, frame_index : device.frame_data {
        command_buffers_it := frame_data.command_buffers.data;

        for command_pool, command_pool_index : frame_data.command_pools {
            allocation_info.commandPool = command_pool;

            debugCheckVK(vkAllocateCommandBuffers(device.device, *allocation_info, command_buffers_it));

            #if DEBUG_BUILD {
                local_command_buffers_it := command_buffers_it;

                for 0 .. Device.MAX_COMMAND_BUFFERS - 1 {
                    setVulkanObjectName(device,
                                        local_command_buffers_it.*,
                                        "% command buffer #% for frame #%",
                                        cast(QueueType) command_pool_index,
                                        it,
                                        frame_index);

                    local_command_buffers_it += 1;
                }
            }

            command_buffers_it += Device.MAX_COMMAND_BUFFERS;
        }
    }
}

createSystemCommandBuffers :: (device : *VulkanDevice) {
    allocation_info := VkCommandBufferAllocateInfo.{
        commandPool        = null, // Will be set in a loop
        level              = .VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        commandBufferCount = FrameData.system_command_buffers.count
    };

    for * frame_data, frame_index : device.frame_data {
        allocation_info.commandPool = frame_data.command_pools[QueueType.GRAPHICS];

        debugCheckVK(vkAllocateCommandBuffers(device.device, *allocation_info, frame_data.system_command_buffers.data));

        #if DEBUG_BUILD {
            for frame_data.system_command_buffers {
                setVulkanObjectName(device, it, "% system command buffer for frame #%", cast(SystemCommandBufferKind) it_index, frame_index);
            }
        }
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
