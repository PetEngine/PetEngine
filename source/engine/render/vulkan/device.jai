VulkanDevice :: struct {
    #as using public_data : Device;

    MINIMAL_SUPPORTED_API_VERSION :: VK_API_VERSION_1_2;

    api_version : u32;

    instance        : VkInstance;
    physical_device : VkPhysicalDevice;
    device          : VkDevice;
    queues          : [QUEUE_TYPES_COUNT] Queue;

    frame_data         : [MAX_FRAME_BUFFERING] FrameData;
    vulkan_window_data : [WindowManager.MAX_WINDOWS] VulkanWindowData;

    // Thanks RenderDoc...
    descriptor_buffers_supported : bool;

    messenger                           : VkDebugUtilsMessengerEXT;
    message_hashes                      : [..] u32;
    messenger_context                   : #Context;
    messenger_context_temporary_storage : Temporary_Storage;

    loader : VulkanLoader;

    properties11                 : VkPhysicalDeviceVulkan11Properties;
    properties12                 : VkPhysicalDeviceVulkan12Properties;
    limits                       : VkPhysicalDeviceLimits;
    memory_properties            : VkPhysicalDeviceMemoryProperties2;
    descriptor_buffer_properties : VkPhysicalDeviceDescriptorBufferPropertiesEXT;
}

createVulkanDevice :: (frame_buffering : FrameBuffering) {
    device := pushToArena(*context.pet.arenas.persistent, VulkanDevice);
    context.pet.render.device = device;

    #insert -> string { return generatePlatformVtableInitialization(Device, "device", "Vulkan"); }

    device.frame_buffering = frame_buffering;

    // @TODO: #PerFrameArena
    enabled_instance_extensions : [..] string;
    defer Basic.array_free(enabled_instance_extensions);

    // @TODO: #PerFrameArena
    enabled_device_extensions : [..] string;
    defer Basic.array_free(enabled_device_extensions);

    instance_api_version := createInstance(*enabled_instance_extensions);
    loadVulkanInstanceExtensionsFunctions(*device.loader, device.instance, *enabled_instance_extensions);
    initMessengerCallback();
    physical_device_api_version := selectPhysicalDevice();

    device.api_version = min(instance_api_version, physical_device_api_version);
    infoMessage("Using Vulkan API version: %.%.%.%",
                VK_API_VERSION_VARIANT(device.api_version),
                VK_API_VERSION_MAJOR(device.api_version),
                VK_API_VERSION_MINOR(device.api_version),
                VK_API_VERSION_PATCH(device.api_version));

    gatherQueuesInfo();
    createVirtualDevice(*enabled_device_extensions);
    loadVulkanDeviceExtensionsFunctions(*device.loader, device.device, *enabled_device_extensions);
    getQueues();
    createFences();
    createFrameSemaphores();
    createCommandPools();
    createCommandBuffers();
    createSystemCommandBuffers();
}

destroyVulkanDevice :: () {
    device := cast(*VulkanDevice) context.pet.render.device;

    // @Important: Should be the first call
    waitVulkanDeviceIdle();

    for toView(device.frame_data.data, cast(s64) device.frame_buffering) {
        for it.command_pools {
            vkDestroyCommandPool(device.device, it, null);
        }

        vkDestroySemaphore(device.device, it.post_frame_semaphore, null);
        vkDestroySemaphore(device.device, it.graphics_semaphore, null);
        for it.acquire_semaphores {
            if it != VK_NULL_HANDLE {
                vkDestroySemaphore(device.device, it, null);
            }
        }

        for it.fences {
            vkDestroyFence(device.device, it, null);
        }
    }

    for device.vulkan_window_data {
        for views : it.swapchain_texture_views {
            for views {
                if it.view != VK_NULL_HANDLE {
                    vkDestroyImageView(device.device, it.view, null);
                }

                if it.name {
                    Basic.free(it.name);
                }
            }
        }

        for it.swapchain_textures {
            if it.name {
                Basic.free(it.name);
            }
        }

        if it.swapchain != VK_NULL_HANDLE {
            device.loader.extensions.device.required.vkDestroySwapchainKHR(device.device, it.swapchain, null);
        }

        if it.surface != VK_NULL_HANDLE {
            device.loader.extensions.instance.required.vkDestroySurfaceKHR(device.instance, it.surface, null);
        }
    }

    vkDestroyDevice(device.device, null);

    if device.loader.extensions.instance.optional.vkDestroyDebugUtilsMessengerEXT {
        device.loader.extensions.instance.optional.vkDestroyDebugUtilsMessengerEXT(device.instance, device.messenger, null);

        push_context device.messenger_context {
            Basic.array_reset(*device.message_hashes);

            Allocator.rpfree(context.temporary_storage.original_data);
            context.allocator.proc(.THREAD_STOP, 0, 0, null, context.allocator.data);
        }
    }

    vkDestroyInstance(device.instance, null);
}

initVulkanWindowData :: (window : *Window) {
    device := cast(*VulkanDevice) context.pet.render.device;

    // Reset vulkan window data before potential reuse
    device.vulkan_window_data[window.id] = .{};

    createWindowSemaphores(window);
    createSurface(window);
    recreateVulkanSwapchain(window);
}

beginVulkanFrame :: () {
    assertThreadKind(.MAIN);
    device := cast(*VulkanDevice) context.pet.render.device;

    //
    // Go to the next frame data
    //
    device.frame_index = (device.frame_index + 1) % cast(u8) device.frame_buffering;
    frame_data := *device.frame_data[device.frame_index];

    //
    // Wait for current frame memory
    //
    debugCheckVK(vkWaitForFences(device.device, frame_data.fences.count, frame_data.fences.data, VK_TRUE, 0xFFFF_FFFF_FFFF_FFFF));

    //
    // Reset command pools
    //
    for frame_data.command_pools {
        debugCheckVK(vkResetCommandPool(device.device, it, 0));
    }

    //
    // Maybe recreate swapchains
    //
    for * context.pet.core.window_manager.windows {
        if device.window_data[it.id].swapchain_is_outdated {
            recreateVulkanSwapchain(it);
        }
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

    //
    // Acquire next swapchain buffer
    //
    {
        acquire_info := VkAcquireNextImageInfoKHR.{
            timeout    = 0xFFFF_FFFF_FFFF_FFFF,
            fence      = VK_NULL_HANDLE,
            deviceMask = 1
        };

        for * context.pet.core.window_manager.windows {
            acquire_info.swapchain = device.vulkan_window_data[it.id].swapchain;
            acquire_info.semaphore = frame_data.acquire_semaphores[it.id];

            back_buffer_index : u32 = ---;
            acquire_result := device.loader.extensions.device.required.vkAcquireNextImage2KHR(device.device, *acquire_info, *back_buffer_index);
            debugCheckVK(acquire_result);

            device.window_data[it.id].back_buffer_index = cast(u8) back_buffer_index;
        }
    }
}

endVulkanFrame :: () {
    assertThreadKind(.MAIN);
    device := cast(*VulkanDevice) context.pet.render.device;

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
    // Collect acquire semaphores from all windows
    //
    acquire_semaphores       : [WindowManager.MAX_WINDOWS] VkSemaphore;
    acquire_semaphores_count : u32;
    for * context.pet.core.window_manager.windows {
        acquire_semaphores[acquire_semaphores_count] = frame_data.acquire_semaphores[it.id];
        acquire_semaphores_count += 1;
    }
    assert(acquire_semaphores_count == context.pet.core.window_manager.windows.count);

    //
    // Submit frame job
    //
    {
        WHICH_STAGE_WILL_WAIT_FOR_THE_SEMAPHORE :: #run -> [WindowManager.MAX_WINDOWS] VkPipelineStageFlags {
            arr : [WindowManager.MAX_WINDOWS] VkPipelineStageFlags;
            for * arr {
                it.* = .VK_PIPELINE_STAGE_VERTEX_SHADER_BIT | .VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT | .VK_PIPELINE_STAGE_TRANSFER_BIT;
            }
            return arr;
        };

        submit_info : VkSubmitInfo;

        command_buffers_used_it := frame_data.command_buffers_used.data;
        command_buffers_it      := frame_data.command_buffers.data;

        for device.queues {
            if command_buffers_used_it.* > 0 {
                fence_to_signal : VkFence = ---;

                if it_index == cast,no_check(s64) QueueType.GRAPHICS {
                    submit_info.waitSemaphoreCount   = acquire_semaphores_count;
                    submit_info.pWaitSemaphores      = acquire_semaphores.data;
                    submit_info.pWaitDstStageMask    = WHICH_STAGE_WILL_WAIT_FOR_THE_SEMAPHORE.data;
                    submit_info.signalSemaphoreCount = 1;
                    submit_info.pSignalSemaphores    = *frame_data.graphics_semaphore;

                    fence_to_signal = VK_NULL_HANDLE;
                } else {
                    submit_info.waitSemaphoreCount   = 0;
                    submit_info.pWaitSemaphores      = null;
                    submit_info.signalSemaphoreCount = 0;
                    submit_info.pSignalSemaphores    = null;

                    fence_to_signal = frame_data.fences[it_index];

                    debugCheckVK(vkResetFences(device.device, 1, *fence_to_signal));
                }

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

        begin_info := VkCommandBufferBeginInfo.{
            flags = .VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT
        };

        debugCheckVK(vkBeginCommandBuffer(post_frame_command_buffer, *begin_info));

        BARRIER_TEMPLATE :: VkImageMemoryBarrier.{
            srcAccessMask                   = .VK_ACCESS_MEMORY_READ_BIT | .VK_ACCESS_MEMORY_WRITE_BIT,
            dstAccessMask                   = .VK_ACCESS_MEMORY_READ_BIT | .VK_ACCESS_MEMORY_WRITE_BIT,
            newLayout                       = .VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
            srcQueueFamilyIndex             = VK_QUEUE_FAMILY_IGNORED,
            dstQueueFamilyIndex             = VK_QUEUE_FAMILY_IGNORED,
            subresourceRange.aspectMask     = .VK_IMAGE_ASPECT_COLOR_BIT,
            subresourceRange.baseMipLevel   = 0,
            subresourceRange.levelCount     = 1,
            subresourceRange.baseArrayLayer = 0,
            subresourceRange.layerCount     = 1,
        };

        image_barriers       : [WindowManager.MAX_WINDOWS] VkImageMemoryBarrier = ---;
        image_barriers_count : u32;
        for * context.pet.core.window_manager.windows {
            window_data        := *device.window_data[it.id];
            vulkan_window_data := *device.vulkan_window_data[it.id];

            back_buffer := *vulkan_window_data.swapchain_textures[window_data.back_buffer_index];
            assert(back_buffer.current_owner == .GRAPHICS);

            if back_buffer.current_layout == .VK_IMAGE_LAYOUT_PRESENT_SRC_KHR {
                continue;
            }

            barrier := *image_barriers[image_barriers_count];
            image_barriers_count += 1;

            barrier.* = BARRIER_TEMPLATE;
            barrier.oldLayout = back_buffer.current_layout;
            barrier.image     = back_buffer.image;

            back_buffer.current_layout = .VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
        }

        vkCmdPipelineBarrier(post_frame_command_buffer,
                             .VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
                             .VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
                             0,
                             0, null,
                             0, null,
                             image_barriers_count, image_barriers.data);

        debugCheckVK(vkEndCommandBuffer(post_frame_command_buffer));

        fence_to_signal := frame_data.fences[QueueType.GRAPHICS];
        debugCheckVK(vkResetFences(device.device, 1, *fence_to_signal));

        which_stages_will_wait_for_the_semaphore := VkPipelineStageFlags.VK_PIPELINE_STAGE_VERTEX_SHADER_BIT
                                                  | .VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT
                                                  | .VK_PIPELINE_STAGE_TRANSFER_BIT;
        submit_info := VkSubmitInfo.{
            pWaitDstStageMask    = *which_stages_will_wait_for_the_semaphore,
            commandBufferCount   = 1,
            pCommandBuffers      = *post_frame_command_buffer,
            signalSemaphoreCount = 1,
            pSignalSemaphores    = *frame_data.post_frame_semaphore
        };

        if frame_data.command_buffers_used[QueueType.GRAPHICS] > 0 {
            submit_info.waitSemaphoreCount = 1;
            submit_info.pWaitSemaphores    = *frame_data.graphics_semaphore;
        } else {
            submit_info.waitSemaphoreCount = acquire_semaphores_count;
            submit_info.pWaitSemaphores    = acquire_semaphores.data;
        }

        debugCheckVK(vkQueueSubmit(device.queues[QueueType.GRAPHICS].handle, 1, *submit_info, fence_to_signal));
    }

    //
    // Present
    //
    {
        swapchains          : [WindowManager.MAX_WINDOWS] VkSwapchainKHR;
        back_buffer_indices : [WindowManager.MAX_WINDOWS] u32;
        index_to_id         : [WindowManager.MAX_WINDOWS] u8;
        swapchains_count    : u32;
        for * context.pet.core.window_manager.windows {
            swapchains[swapchains_count]          = device.vulkan_window_data[it.id].swapchain;
            back_buffer_indices[swapchains_count] = device.window_data[it.id].back_buffer_index;
            index_to_id[swapchains_count]         = it.id;
            swapchains_count += 1;
        }
        assert(swapchains_count == context.pet.core.window_manager.windows.count);

        results : [WindowManager.MAX_WINDOWS] VkResult;
        results_view := toView(results.data, swapchains_count);

        present_info := VkPresentInfoKHR.{
            waitSemaphoreCount = 1,
            pWaitSemaphores    = *frame_data.post_frame_semaphore,
            swapchainCount     = swapchains_count,
            pSwapchains        = swapchains.data,
            pImageIndices      = back_buffer_indices.data,
            pResults           = results.data
        };

        result := device.loader.extensions.device.required.vkQueuePresentKHR(device.queues[QueueType.GRAPHICS].handle, *present_info);
        if result == {
            case .VK_ERROR_OUT_OF_DATE_KHR;  #through;
            case .VK_ERROR_SURFACE_LOST_KHR; #through;
            case .VK_SUBOPTIMAL_KHR;
                for results_view {
                    if it == {
                        case .VK_ERROR_OUT_OF_DATE_KHR; #through;
                        case .VK_ERROR_SURFACE_LOST_KHR;
                            device.window_data[index_to_id[it_index]].swapchain_is_outdated = true;

                        case .VK_SUBOPTIMAL_KHR;
                            // Do nothing, it's because of scaling

                        case;
                            debugCheckVK(it);
                    }
                }

            case;
                debugCheckVK(result);
                for results_view {
                    debugCheckVK(it);
                }
        }
    }
}

waitVulkanDeviceIdle :: () {
    assertThreadKind(.MAIN);
    device := cast(*VulkanDevice) context.pet.render.device;

    debugCheckVK(vkDeviceWaitIdle(device.device));
}

getVulkanSwapchainTexture :: inline (window : *Window, swapchain_buffer_index : u32) -> *Texture {
    device := cast(*VulkanDevice) context.pet.render.device;
    return *device.vulkan_window_data[window.id].swapchain_textures[swapchain_buffer_index];
}

getVulkanSwapchainTextureView :: (window : *Window, swapchain_buffer_index : u32, usage : Texture.Usage) -> *TextureView {
    device := cast(*VulkanDevice) context.pet.render.device;

    index : u8 = ---;
    if usage == {
        case .COLOR_TARGET; index = 0;
        case .SHADER_READ;  index = 1;
        case;
            assertMessage("Unsupported swapchain texure view usage: %", usage);
    }

    return *device.vulkan_window_data[window.id].swapchain_texture_views[swapchain_buffer_index][index];
}

setVulkanObjectName :: (object : $T, name : string) {
    #if DEBUG_BUILD {
        device := cast(*VulkanDevice) context.pet.render.device;

        if device.loader.extensions.instance.optional.vkSetDebugUtilsObjectNameEXT {
            object_name := pushToArena(*context.pet.arenas.per_frame, u8, name.count + 1);
            memcpy(object_name, name.data, name.count);

            name_info := VkDebugUtilsObjectNameInfoEXT.{
                objectType   = #run vkTypeToObjectType(T),
                objectHandle = cast(u64) object,
                pObjectName  = object_name
            };

            debugCheckVK(device.loader.extensions.instance.optional.vkSetDebugUtilsObjectNameEXT(device.device, *name_info));
        }
    }
}

setVulkanObjectName :: (object : $T, $format : string, args : ..Any) {
    #if DEBUG_BUILD {
        device := cast(*VulkanDevice) context.pet.render.device;

        if device.loader.extensions.instance.optional.vkSetDebugUtilsObjectNameEXT {
            builder := Basic.String_Builder.{ allocator = Basic.temp };

            Basic.print(*builder, format, ..args);
            Basic.append(*builder, "\0");

            object_name := Basic.builder_to_string(*builder,, allocator = Basic.temp);

            name_info := VkDebugUtilsObjectNameInfoEXT.{
                objectType   = #run vkTypeToObjectType(T),
                objectHandle = cast(u64) object,
                pObjectName  = object_name.data
            };

            debugCheckVK(device.loader.extensions.instance.optional.vkSetDebugUtilsObjectNameEXT(device.device, *name_info));
        }
    }
}

#scope_file

Hash      :: #import "Hash";
IntroSort :: #import "IntroSort";

FrameData :: struct {
    fences : [VulkanDevice.queues.count] VkFence;

    acquire_semaphores   : [WindowManager.MAX_WINDOWS] VkSemaphore;
    graphics_semaphore   : VkSemaphore;
    post_frame_semaphore : VkSemaphore;

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

SystemCommandBufferKind :: enum u8 {
    POST_FRAME;
}

VulkanWindowData :: struct {
    surface                 : VkSurfaceKHR;
    swapchain               : VkSwapchainKHR;
    swapchain_textures      : [Device.MAX_SWAPCHAIN_BUFFERS] VulkanTexture;
    swapchain_texture_views : [Device.MAX_SWAPCHAIN_BUFFERS] [2] VulkanTextureView;
}

PhysicalDeviceInfo :: struct {
    physical_device : VkPhysicalDevice;

    //
    // Sorting
    //

    memory_size : VkDeviceSize;
    // bit 4       - device type priority
    // bits [3, 2] - API version priority
    // bits [1, 0] - vendor ID priority
    priority    : u8;

    //
    // Info
    //

    properties2                  : VkPhysicalDeviceProperties2;
    properties11                 : VkPhysicalDeviceVulkan11Properties;
    properties12                 : VkPhysicalDeviceVulkan12Properties;
    descriptor_buffer_properties : VkPhysicalDeviceDescriptorBufferPropertiesEXT;

    memory_properties            : VkPhysicalDeviceMemoryProperties2;
}

createInstance :: (enabled_instance_extensions : *[..] string) -> u32 {
    api_version := VK_API_VERSION_1_4;
    debugCheckVK(vkEnumerateInstanceVersion(*api_version));

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

    autoResetPerFrameArenas();

    builder := Basic.String_Builder.{ allocator = Basic.temp };

    layers_to_apply : [..] *u8;
    layers_to_apply.allocator = Basic.temp;

    {
        available_layers : [] VkLayerProperties;
        debugCheckVK(vkEnumerateInstanceLayerProperties(cast(*u32) *available_layers.count, null));

        available_layers.data = pushToArena(*context.pet.arenas.per_frame, VkLayerProperties, available_layers.count);
        debugCheckVK(vkEnumerateInstanceLayerProperties(cast(*u32) *available_layers.count, available_layers.data));

        #if PRINT_VERBOSE_MESSAGES {
            Basic.print(*builder, "Available instance layers (%):\n", available_layers.count);
            for available_layers {
                Basic.print(*builder, "    %\n", to_string(it.layerName.data));
            }
            verboseMessage("%", Basic.builder_to_string(*builder,, allocator = Basic.temp));
        }

        REQUIRED_LAYERS, OPTIONAL_LAYERS :: #run gatherVulkanLayers();

        for required_layer : REQUIRED_LAYERS {
            layer_found : bool;

            for available_layers {
                if to_string(it.layerName.data) == required_layer {
                    layer_found = true;
                    break;
                }
            }

            if layer_found {
                Basic.array_add(*layers_to_apply, required_layer.data);
            } else {
                assertMessage("Required instance layer \"%\" has not been found in available instance layers", required_layer);
            }
        }

        for optional_layer : OPTIONAL_LAYERS {
            layer_found : bool;

            for available_layers {
                if to_string(it.layerName.data) == optional_layer {
                    layer_found = true;
                    break;
                }
            }

            if layer_found {
                Basic.array_add(*layers_to_apply, optional_layer.data);
            } else {
                warningMessage("Optional instance layer \"%\" has not been found in available instance layers", optional_layer);
            }
        }

        Basic.print(*builder, "Applying instance layers (%):\n", layers_to_apply.count);
        for layers_to_apply {
            Basic.print(*builder, "    %\n", to_string(it));
        }
        infoMessage("%", Basic.builder_to_string(*builder,, allocator = Basic.temp));
    }

    extensions_to_apply : [..] *u8;
    extensions_to_apply.allocator = Basic.temp;

    {
        available_extensions : [] VkExtensionProperties;
        debugCheckVK(vkEnumerateInstanceExtensionProperties(null, cast(*u32) *available_extensions.count, null));

        available_extensions.data = pushToArena(*context.pet.arenas.per_frame, VkExtensionProperties, available_extensions.count);
        debugCheckVK(vkEnumerateInstanceExtensionProperties(null, cast(*u32) *available_extensions.count, available_extensions.data));

        #if PRINT_VERBOSE_MESSAGES {
            Basic.print(*builder, "Available instance extensions (%):\n", available_extensions.count);
            for available_extensions {
                Basic.print(*builder, "    %\n", to_string(it.extensionName.data));
            }
            verboseMessage("%", Basic.builder_to_string(*builder,, allocator = Basic.temp));
        }

        #if DEBUG_BUILD {
            validation_extensions : [] VkExtensionProperties;
            debugCheckVK(vkEnumerateInstanceExtensionProperties("VK_LAYER_KHRONOS_validation".data, cast(*u32) *validation_extensions.count, null));

            validation_extensions.data = pushToArena(*context.pet.arenas.per_frame, VkExtensionProperties, validation_extensions.count);
            debugCheckVK(vkEnumerateInstanceExtensionProperties("VK_LAYER_KHRONOS_validation".data, cast(*u32) *validation_extensions.count, validation_extensions.data));

            #if PRINT_VERBOSE_MESSAGES {
                Basic.print(*builder, "Available VK_LAYER_KHRONOS_validation's instance extensions (%):\n", validation_extensions.count);
                for validation_extensions {
                    Basic.print(*builder, "    %\n", to_string(it.extensionName.data));
                }
                verboseMessage("%", Basic.builder_to_string(*builder,, allocator = Basic.temp));
            }
        }

        REQUIRED_EXTENSIONS, OPTIONAL_EXTENSIONS :: #run gatherVulkanInstanceExtensions();

        for required_extension : REQUIRED_EXTENSIONS {
            extension_found : bool;

            for available_extensions {
                if to_string(it.extensionName.data) == required_extension {
                    extension_found = true;
                    break;
                }
            }

            if extension_found {
                Basic.array_add(enabled_instance_extensions, required_extension);
                Basic.array_add(*extensions_to_apply, required_extension.data);
            } else {
                assertMessage("Required instance extension \"%\" has not been found in available instance extensions", required_extension);
            }
        }

        for optional_extension : OPTIONAL_EXTENSIONS {
            extension_found : bool;

            for available_extensions {
                if to_string(it.extensionName.data) == optional_extension {
                    extension_found = true;
                    break;
                }
            }

            if extension_found {
                Basic.array_add(enabled_instance_extensions, optional_extension);
                Basic.array_add(*extensions_to_apply, optional_extension.data);
            } else {
                warningMessage("Optional instance extension \"%\" has not been found in available instance extensions", optional_extension);
            }
        }

        #if DEBUG_BUILD {
            extension_found : bool;

            for validation_extensions {
                if to_string(it.extensionName.data) == "VK_EXT_validation_features" {
                    extension_found = true;
                    break;
                }
            }

            if extension_found {
                Basic.array_add(enabled_instance_extensions, "VK_EXT_validation_features");
                Basic.array_add(*extensions_to_apply, "VK_EXT_validation_features".data);
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

    application_info := VkApplicationInfo.{
        pApplicationName   = null,
        applicationVersion = 0,
        pEngineName        = ENGINE_NAME.data,
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
            // @Important: GPU-AV breaks descriptor buffers. Hopefully will be fixed one day.
            //
            // .VK_VALIDATION_FEATURE_ENABLE_GPU_ASSISTED_EXT,
            // .VK_VALIDATION_FEATURE_ENABLE_GPU_ASSISTED_RESERVE_BINDING_SLOT_EXT,

            // .VK_VALIDATION_FEATURE_ENABLE_BEST_PRACTICES_EXT,
            .VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXT
        ];

        validation_features := VkValidationFeaturesEXT.{
            enabledValidationFeatureCount = ENABLED_VALIDATION_FEATURES.count,
            pEnabledValidationFeatures    = ENABLED_VALIDATION_FEATURES.data
        };

        instance_create_info.pNext = *validation_features;
    }

    device := cast(*VulkanDevice) context.pet.render.device;
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

    push_context,defer_pop device.messenger_context;
    assertThreadKind(.DEVICE_MESSENGER);

    // autoResetPerFrameArenas is not suittable here since device.messenger_context has no arenas
    Basic.auto_release_temp();

    message := to_string(pCallbackData.pMessage);
    if message[message.count - 1] == #char "." {
        message.count -= 1;
    }

    MESSAGE_DEDUPLICATION_STRATEGY : enum u8 {
        VUID_HASH    :: 1;
        MESSAGE_HASH;
    } : .MESSAGE_HASH;

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

    #if is_constant(should_be_printed) {
        #if !should_be_printed return VK_FALSE;
    } else {
        if !should_be_printed return VK_FALSE;
    }

    SHORTEN_MESSAGE :: true;
    #if SHORTEN_MESSAGE {
        index := String.find_index_from_left(message, "Object");
        if index != -1 {
            builder := Basic.String_Builder.{ allocator = Basic.temp };

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

    return VK_FALSE;
}

initMessengerCallback :: () {
    device := cast(*VulkanDevice) context.pet.render.device;

    if device.loader.extensions.instance.optional.vkCreateDebugUtilsMessengerEXT {
        device.messenger_context.allocator   = context.allocator;
        device.messenger_context.logger      = context.logger;
        device.messenger_context.logger_data = context.logger_data;
        device.messenger_context.print_style = context.print_style;
        // We do not need globals for messenger callback

        push_context device.messenger_context {
            context.thread_index    = getNextThreadIndex();
            context.pet.thread.name = "Vulkan Device Messenger";
            context.pet.thread.kind = .DEVICE_MESSENGER;

            context.allocator.proc(.THREAD_START, 0, 0, null, context.allocator.data);

            context.temporary_storage = *device.messenger_context_temporary_storage;

            // TEMPORARY_STORAGE_SIZE is defined by the compiler based on Build_Options.temporary_storage_size
            temporary_storage_data := Allocator.rpaligned_alloc(DEFAULT_CACHE_LINE_SIZE, TEMPORARY_STORAGE_SIZE);
            set_initial_data(context.temporary_storage, TEMPORARY_STORAGE_SIZE, temporary_storage_data);

            // We do not need arenas for messenger callback

            device.message_hashes.allocator = context.allocator;
        }

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

        debugCheckVK(device.loader.extensions.instance.optional.vkCreateDebugUtilsMessengerEXT(device.instance,
                                                                                               *create_info,
                                                                                               null,
                                                                                               *device.messenger));
    }
}

selectPhysicalDevice :: () -> u32 {
    device := cast(*VulkanDevice) context.pet.render.device;

    physical_device_infos := sortPhysicalDevices();

    #if PRINT_VERBOSE_MESSAGES {
        builder := Basic.String_Builder.{ allocator = Basic.temp };
        Basic.print(*builder, "Supported physical devices (%):\n", physical_device_infos.count);

        PHYSICAL_DEVICE_VERBOSE_MESSAGE :: #string END
    [%]: Vendor ID:      % (0x%)
         Device ID:      0x%
         Device type:    %
         Device name:    %
         Device memory:  % GB
         Driver ID:      %
         Driver name:    %
         Driver info:    %
         Driver version: %.%.%.% (0x%)
         API version:    %.%.%.%
END;

        for physical_device_infos {
            Basic.print(*builder,
                        PHYSICAL_DEVICE_VERBOSE_MESSAGE,
                        it_index,
                        vendorIdToString(it.properties2.properties.vendorID),
                        formatHex(it.properties2.properties.vendorID),
                        formatHex(it.properties2.properties.deviceID),
                        it.properties2.properties.deviceType,
                        to_string(it.properties2.properties.deviceName.data),
                        bytesToGigaBytes(it.memory_size),
                        it.properties12.driverID,
                        to_string(it.properties12.driverName.data),
                        to_string(it.properties12.driverInfo.data),
                        it.properties12.conformanceVersion.major,
                        it.properties12.conformanceVersion.minor,
                        it.properties12.conformanceVersion.subminor,
                        it.properties12.conformanceVersion.patch,
                        formatHex(it.properties2.properties.driverVersion),
                        VK_API_VERSION_VARIANT(it.properties2.properties.apiVersion),
                        VK_API_VERSION_MAJOR(it.properties2.properties.apiVersion),
                        VK_API_VERSION_MINOR(it.properties2.properties.apiVersion),
                        VK_API_VERSION_PATCH(it.properties2.properties.apiVersion));
        }

        verboseMessage("%", Basic.builder_to_string(*builder,, allocator = Basic.temp));
    }

    if !physical_device_infos {
        assertMessage("There are no supported physical devices in the system");
    }

    gpu_name  := readSetting("render.gpu");
    gpu_index : s64 = ---;
    if gpu_name {
        gpu_index = -1;
        for physical_device_infos {
            if to_string(it.properties2.properties.deviceName.data) == gpu_name {
                gpu_index = it_index;
                break;
            }
        }

        if gpu_index == -1 {
            gpu_index          = 0;
            fallback_gpu_name := to_string(physical_device_infos[gpu_index].properties2.properties.deviceName.data);

            warningMessage("GPU with name \"%\" was not found. Fallback to the first one: \"%\"", gpu_name, fallback_gpu_name);
            gpu_name = fallback_gpu_name;

            writeSetting("render.gpu", gpu_name);
            commitSettings();
        }
    } else {
        gpu_index  = 0;
        gpu_name  := to_string(physical_device_infos[gpu_index].properties2.properties.deviceName.data);

        writeSetting("render.gpu", gpu_name);
        commitSettings();
    }

    selected_physical_device_info := *physical_device_infos[gpu_index];

    device.physical_device              = selected_physical_device_info.physical_device;
    device.properties11                 = selected_physical_device_info.properties11;
    device.properties12                 = selected_physical_device_info.properties12;
    device.limits                       = selected_physical_device_info.properties2.properties.limits;
    device.memory_properties            = selected_physical_device_info.memory_properties;
    device.descriptor_buffer_properties = selected_physical_device_info.descriptor_buffer_properties;

    device.vendor_id = cast(PCIVendorID) selected_physical_device_info.properties2.properties.vendorID;

    if #complete selected_physical_device_info.properties2.properties.deviceType == {
        case .VK_PHYSICAL_DEVICE_TYPE_OTHER;          device.type = .UNKNOWN;
        case .VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU; device.type = .INTEGRATED;
        case .VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU;   device.type = .DISCRETE;
        case .VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU;    device.type = .VIRTUAL;
        case .VK_PHYSICAL_DEVICE_TYPE_CPU;            device.type = .CPU;
    }

    PHYSICAL_DEVICE_INFO_MESSAGE :: #string END
Using physical device:
    Vendor ID:      % (0x%)
    Device ID:      0x%
    Device type:    %
    Device name:    %
    Device memory:  % GB
    Driver ID:      %
    Driver name:    %
    Driver info:    %
    Driver version: %.%.%.% (0x%)
    API version:    %.%.%.%
END;

    infoMessage(PHYSICAL_DEVICE_INFO_MESSAGE,
                vendorIdToString(selected_physical_device_info.properties2.properties.vendorID),
                formatHex(selected_physical_device_info.properties2.properties.vendorID),
                formatHex(selected_physical_device_info.properties2.properties.deviceID),
                selected_physical_device_info.properties2.properties.deviceType,
                to_string(selected_physical_device_info.properties2.properties.deviceName.data),
                bytesToGigaBytes(selected_physical_device_info.memory_size),
                device.properties12.driverID,
                to_string(device.properties12.driverName.data),
                to_string(device.properties12.driverInfo.data),
                device.properties12.conformanceVersion.major,
                device.properties12.conformanceVersion.minor,
                device.properties12.conformanceVersion.subminor,
                device.properties12.conformanceVersion.patch,
                formatHex(selected_physical_device_info.properties2.properties.driverVersion),
                VK_API_VERSION_VARIANT(selected_physical_device_info.properties2.properties.apiVersion),
                VK_API_VERSION_MAJOR(selected_physical_device_info.properties2.properties.apiVersion),
                VK_API_VERSION_MINOR(selected_physical_device_info.properties2.properties.apiVersion),
                VK_API_VERSION_PATCH(selected_physical_device_info.properties2.properties.apiVersion));

    return selected_physical_device_info.properties2.properties.apiVersion;
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

gatherQueuesInfo :: () {
    device := cast(*VulkanDevice) context.pet.render.device;

    queue_family_properties : [] VkQueueFamilyProperties2;
    vkGetPhysicalDeviceQueueFamilyProperties2(device.physical_device, cast(*u32) *queue_family_properties.count, null);

    queue_family_properties.data = pushToArena(*context.pet.arenas.per_frame, VkQueueFamilyProperties2, queue_family_properties.count);
    vkGetPhysicalDeviceQueueFamilyProperties2(device.physical_device, cast(*u32) *queue_family_properties.count, queue_family_properties.data);

    autoResetPerFrameArenas();

    // Print info about available queue families
    #if PRINT_VERBOSE_MESSAGES {
        builder := Basic.String_Builder.{ allocator = Basic.temp };

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

    queues_in_family_used := pushToArena(*context.pet.arenas.per_frame, u32, queue_family_properties.count);

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
        builder := Basic.String_Builder.{ allocator = Basic.temp };

        Basic.append(*builder, "Queues info:\n");

QUEUE_INFO_FORMAT_STRING :: #string END
    %:
        Family flags:    %
        Family index:    %
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

createVirtualDevice :: (enabled_device_extensions : *[..] string) {
    device := cast(*VulkanDevice) context.pet.render.device;

    queues_count_per_family : [VulkanDevice.queues.count] u32;
    for device.queues  queues_count_per_family[it.family_index] += 1;

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

    autoResetPerFrameArenas();

    builder := Basic.String_Builder.{ allocator = Basic.temp };

    extensions_to_apply : [..] *u8;
    extensions_to_apply.allocator = Basic.temp;

    {
        available_extensions : [] VkExtensionProperties;
        debugCheckVK(vkEnumerateDeviceExtensionProperties(device.physical_device, null, cast(*u32) *available_extensions.count, null));

        available_extensions.data = pushToArena(*context.pet.arenas.per_frame, VkExtensionProperties, available_extensions.count);
        debugCheckVK(vkEnumerateDeviceExtensionProperties(device.physical_device, null, cast(*u32) *available_extensions.count, available_extensions.data));

        #if PRINT_VERBOSE_MESSAGES {
            Basic.print(*builder, "Available device extensions (%):\n", available_extensions.count);
            for available_extensions {
                Basic.print(*builder, "    %\n", to_string(it.extensionName.data));
            }
            verboseMessage("%", Basic.builder_to_string(*builder,, allocator = Basic.temp));
        }

        REQUIRED_EXTENSIONS, OPTIONAL_EXTENSIONS :: #run gatherVulkanDeviceExtensions();

        for required_extension : REQUIRED_EXTENSIONS {
            extension_found : bool;

            for available_extensions {
                if to_string(it.extensionName.data) == required_extension {
                    extension_found = true;
                    break;
                }
            }

            if extension_found {
                Basic.array_add(enabled_device_extensions, required_extension);
                Basic.array_add(*extensions_to_apply, required_extension.data);
            } else {
                assertMessage("Required device extension \"%\" has not been found in available device extensions", required_extension);
            }
        }

        for optional_extension : OPTIONAL_EXTENSIONS {
            extension_found : bool;

            for available_extensions {
                if to_string(it.extensionName.data) == optional_extension {
                    extension_found = true;
                    break;
                }
            }

            if extension_found {
                Basic.array_add(enabled_device_extensions, optional_extension);
                Basic.array_add(*extensions_to_apply, optional_extension.data);
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

    device.descriptor_buffers_supported = Basic.array_find(enabled_device_extensions.*, "VK_EXT_descriptor_buffer");

    // Test feature support
    {
        available_swapchain_maintenance1_features :  VkPhysicalDeviceSwapchainMaintenance1FeaturesEXT;
        available_descriptor_buffer_features      := VkPhysicalDeviceDescriptorBufferFeaturesEXT.{ pNext = *available_swapchain_maintenance1_features };
        available_dynamic_rendering_features      :  VkPhysicalDeviceDynamicRenderingFeatures;
        available_features_1_2                    := VkPhysicalDeviceVulkan12Features.{ pNext = *available_dynamic_rendering_features };
        available_features_1_1                    := VkPhysicalDeviceVulkan11Features.{ pNext = *available_features_1_2 };
        available_features                        := VkPhysicalDeviceFeatures2.{ pNext = *available_features_1_1 };

        if device.descriptor_buffers_supported {
            available_dynamic_rendering_features.pNext = *available_descriptor_buffer_features;
        } else {
            available_dynamic_rendering_features.pNext = *available_swapchain_maintenance1_features;
        }

        vkGetPhysicalDeviceFeatures2(device.physical_device, *available_features);

        // Image cube array support
        assert(available_features.features.imageCubeArray == VK_TRUE);
        // Anisotropy filtering support
        assert(available_features.features.samplerAnisotropy == VK_TRUE);
        // UAV support
        assert(available_features.features.vertexPipelineStoresAndAtomics == VK_TRUE);
        assert(available_features.features.fragmentStoresAndAtomics       == VK_TRUE);
        assert(available_features.features.shaderStorageImageMultisample  == VK_TRUE);
        // GL_EXT_shader_explicit_arithmetic_types support
        assert(available_features.features.shaderInt64 == VK_TRUE);
        assert(available_features.features.shaderInt16 == VK_TRUE);
        // Dynamic rendering support
        assert(available_dynamic_rendering_features.dynamicRendering == VK_TRUE);
        // Descriptor buffer support
        device.descriptor_buffers_supported &= available_descriptor_buffer_features.descriptorBuffer == VK_TRUE;
        // Device address support
        assert(available_features_1_2.bufferDeviceAddress == VK_TRUE);
        // 16-bit types in push constants
        assert(available_features_1_1.storagePushConstant16 == VK_TRUE);
        // gl_BaseInstance etc support
        assert(available_features_1_1.shaderDrawParameters == VK_TRUE);
        // VK_EXT_swapchain_maintenance1
        assert(available_swapchain_maintenance1_features.swapchainMaintenance1 == VK_TRUE);
    }

    swapchain_maintenance1_features_to_enable := VkPhysicalDeviceSwapchainMaintenance1FeaturesEXT.{
        swapchainMaintenance1 = VK_TRUE,
    };
    descriptor_buffer_features_to_enable := VkPhysicalDeviceDescriptorBufferFeaturesEXT.{
        pNext            = *swapchain_maintenance1_features_to_enable,
        descriptorBuffer = VK_TRUE,
    };
    dynamic_rendering_features_to_enable := VkPhysicalDeviceDynamicRenderingFeatures.{
        pNext            = ifx  device.descriptor_buffers_supported
                           then cast(*void) *descriptor_buffer_features_to_enable
                           else cast(*void) *swapchain_maintenance1_features_to_enable,
        dynamicRendering = VK_TRUE,
    };
    features_1_2_to_enable := VkPhysicalDeviceVulkan12Features.{
        pNext               = *dynamic_rendering_features_to_enable,
        bufferDeviceAddress = VK_TRUE,
    };
    features_1_1_to_enable := VkPhysicalDeviceVulkan11Features.{
        pNext                 = *features_1_2_to_enable,
        storagePushConstant16 = VK_TRUE,
        shaderDrawParameters  = VK_TRUE,
    };
    features_to_enable := VkPhysicalDeviceFeatures2.{
        pNext                                   = *features_1_1_to_enable,
        features.imageCubeArray                 = VK_TRUE,
        features.samplerAnisotropy              = VK_TRUE,
        features.vertexPipelineStoresAndAtomics = VK_TRUE,
        features.fragmentStoresAndAtomics       = VK_TRUE,
        features.shaderStorageImageMultisample  = VK_TRUE,
        features.shaderInt64                    = VK_TRUE,
        features.shaderInt16                    = VK_TRUE,
    };

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

    debugCheckVK(vkCreateDevice(device.physical_device, *device_create_info, null, *device.device));
}

// @TODO: #NotExistedQueues
getQueues :: () {
    device := cast(*VulkanDevice) context.pet.render.device;

    for device.queues {
        queue_info := VkDeviceQueueInfo2.{
            flags            = 0,
            queueFamilyIndex = it.family_index,
            queueIndex       = it.index_in_family
        };

        vkGetDeviceQueue2(device.device, *queue_info, *it.handle);
        assert(it.handle != VK_NULL_HANDLE);

        setVulkanObjectName(it.handle, "% queue", cast(QueueType) it_index);
    }
}

createSurface :: (window : *Window) {
    device := cast(*VulkanDevice) context.pet.render.device;

    vulkan_window_data := *device.vulkan_window_data[window.id];

    #if OS == .WINDOWS {
        win32_window         := cast(*Win32Window) window;
        win32_window_manager := cast(*Win32WindowManager) context.pet.core.window_manager;

        create_info := VkWin32SurfaceCreateInfoKHR.{
            flags     = 0,
            hinstance = win32_window_manager.app_instance,
            hwnd      = win32_window.handle
        };

        debugCheckVK(device.loader.extensions.instance.required.vkCreateWin32SurfaceKHR(device.instance,
                                                                                        *create_info,
                                                                                        null,
                                                                                        *vulkan_window_data.surface));
    } else {
        notImplemented();
    }

    // Query is graphics queue supports presentation to created sufrace
    {
        graphics_queue := *device.queues[QueueType.GRAPHICS];

        presentation_supported : VkBool32 = ---;
        debugCheckVK(device.loader.extensions.instance.required.vkGetPhysicalDeviceSurfaceSupportKHR(device.physical_device,
                                                                                                     graphics_queue.family_index,
                                                                                                     vulkan_window_data.surface,
                                                                                                     *presentation_supported));
        if !presentation_supported {
            assertMessage("% queue #% in #% queue family does not support presentation to created surface",
                          QueueType.GRAPHICS,
                          graphics_queue.index_in_family,
                          graphics_queue.family_index);
        }
    }
}

// @Speed: Ask for surface capabilities only once at surface creation time
recreateVulkanSwapchain :: (window : *Window) {
    assertThreadKind(.MAIN);
    device := cast(*VulkanDevice) context.pet.render.device;

    window_data        := *device.window_data[window.id];
    vulkan_window_data := *device.vulkan_window_data[window.id];

    //
    // Surface formats
    //

    surface_formats : [] VkSurfaceFormatKHR;
    debugCheckVK(device.loader.extensions.instance.required.vkGetPhysicalDeviceSurfaceFormatsKHR(device.physical_device,
                                                                                                 vulkan_window_data.surface,
                                                                                                 cast(*u32) *surface_formats.count,
                                                                                                 null));

    surface_formats.data = pushToArena(*context.pet.arenas.per_frame, VkSurfaceFormatKHR, surface_formats.count);
    debugCheckVK(device.loader.extensions.instance.required.vkGetPhysicalDeviceSurfaceFormatsKHR(device.physical_device,
                                                                                                 vulkan_window_data.surface,
                                                                                                 cast(*u32) *surface_formats.count,
                                                                                                 surface_formats.data));

    builder := Basic.String_Builder.{ allocator = Basic.temp };

    #if PRINT_VERBOSE_MESSAGES {
        FORMAT_NAME_WIDTH :: #run -> s64 {
            max_width := -1;
            for type_info(VkFormat).names { max_width = max(max_width, it.count); }
            assert(max_width != -1);
            return max_width;
        }

        spaces : [FORMAT_NAME_WIDTH] u8 = ---;
        for * spaces { it.* = #char " "; }

        info := type_info(VkFormat);

        Basic.print(*builder, "Available surface formats (%):\n", surface_formats.count);
        for surface_formats {
            Basic.print(*builder, "    [%]: Format: %\n         Space:  %\n", it_index, it.format, it.colorSpace);
        }

        verboseMessage("%", Basic.builder_to_string(*builder,, allocator = Basic.temp));
    }

    // @TODO: #HDR.
    REQUESTED_SURFACE_FORMAT :: VkFormat.VK_FORMAT_B8G8R8A8_SRGB;
    allowed_surface_format : *VkSurfaceFormatKHR;

    for * surface_formats {
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
    // Present mode
    //

    present_modes : [] VkPresentModeKHR;
    debugCheckVK(device.loader.extensions.instance.required.vkGetPhysicalDeviceSurfacePresentModesKHR(device.physical_device,
                                                                                                      vulkan_window_data.surface,
                                                                                                      cast(*u32) *present_modes.count,
                                                                                                      null));

    present_modes.data = pushToArena(*context.pet.arenas.per_frame, VkPresentModeKHR, present_modes.count);
    debugCheckVK(device.loader.extensions.instance.required.vkGetPhysicalDeviceSurfacePresentModesKHR(device.physical_device,
                                                                                                      vulkan_window_data.surface,
                                                                                                      cast(*u32) *present_modes.count,
                                                                                                      present_modes.data));

    #if PRINT_VERBOSE_MESSAGES {
        Basic.print(*builder, "Supported present modes (%):\n", present_modes.count);
        for present_modes {
            Basic.print(*builder, "    %\n", it);
        }
        verboseMessage("%", Basic.builder_to_string(*builder,, allocator = Basic.temp));
    }

    present_mode := getVkPresentMode(readSetting("render.vsync"), readSetting("render.tearing_allowed"));
    if Basic.array_find(present_modes, present_mode) {
        infoMessage("Using present mode: %", present_mode);
    } else {
        // FIFO is the only one which is guaranteed to be supported acording to Vulkan spec.
        FALLBACK_PRESENT_MODE :: VkPresentModeKHR.VK_PRESENT_MODE_FIFO_KHR;

        warningMessage("Requested present mode (%) is not supported, % will be used", present_mode, FALLBACK_PRESENT_MODE);
        present_mode = FALLBACK_PRESENT_MODE;
    }

    //
    // Surface capabilities
    //

    surface_present_mode := VkSurfacePresentModeEXT.{
        presentMode = present_mode,
    };
    surface_info := VkPhysicalDeviceSurfaceInfo2KHR.{
        pNext   = *surface_present_mode,
        surface = vulkan_window_data.surface
    };

    scaling_capabilities  : VkSurfacePresentScalingCapabilitiesEXT;
    surface_capabilities2 := VkSurfaceCapabilities2KHR.{ pNext = *scaling_capabilities };
    debugCheckVK(device.loader.extensions.instance.required.vkGetPhysicalDeviceSurfaceCapabilities2KHR(device.physical_device,
                                                                                                       *surface_info,
                                                                                                       *surface_capabilities2));
    surface_capabilities := surface_capabilities2.surfaceCapabilities;

    //
    // Swapchain buffers count
    //

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

    if requested_swapchain_buffers_count > VulkanWindowData.swapchain_textures.count {
        assertMessage("You want too many swapchain buffers: %. If you really need that much you can increase Device.MAX_SWAPCHAIN_BUFFERS",
                      requested_swapchain_buffers_count);
    }

    //
    // Swapchain scaling
    //

    present_scaling := scalingModeToVkPresentScalingFlags(readSetting("render.scaling"));
    if !(scaling_capabilities.supportedPresentScaling & present_scaling) {
        FALLBACK_SCALING :: VkPresentScalingFlagsEXT.VK_PRESENT_SCALING_ONE_TO_ONE_BIT_EXT;

        warningMessage("Requested scaling mode (%) is not supported, % will be used", present_scaling, FALLBACK_SCALING);
        present_scaling = FALLBACK_SCALING;

        infoMessage("Supported scaling modes: %", scaling_capabilities.supportedPresentScaling);
    }

    REQUESTED_GRAVITY_MODE :: VkPresentGravityFlagsEXT.VK_PRESENT_GRAVITY_CENTERED_BIT_EXT;
    if !(scaling_capabilities.supportedPresentGravityX & REQUESTED_GRAVITY_MODE) {
        assertMessage("Requested gravity mode along x axis is not supported: %. Supported are: %",
                      REQUESTED_GRAVITY_MODE,
                      scaling_capabilities.supportedPresentGravityX);
    }
    if !(scaling_capabilities.supportedPresentGravityY & REQUESTED_GRAVITY_MODE) {
        assertMessage("Requested gravity mode along y axis is not supported: %. Supported are: %",
                      REQUESTED_GRAVITY_MODE,
                      scaling_capabilities.supportedPresentGravityY);
    }

    //
    // Swapchain resolution
    //

    surface_extent := VkExtent2D.{
        width  = device.render_resolution.width,
        height = device.render_resolution.height
    };

    if scaling_capabilities.maxScaledImageExtent.width != 0xFFFF_FFFF {
        assert(scaling_capabilities.maxScaledImageExtent.height != 0xFFFF_FFFF);

        adjusted : bool;
        if surface_extent.width > scaling_capabilities.maxScaledImageExtent.width {
            surface_extent.width = scaling_capabilities.maxScaledImageExtent.width;
            adjusted = true;
        }
        if surface_extent.height > scaling_capabilities.maxScaledImageExtent.height {
            surface_extent.height = scaling_capabilities.maxScaledImageExtent.height;
            adjusted = true;
        }

        if adjusted {
            warningMessage("Requested surface extent for swapchain (% x %) is too big. It will be adjusted to % x %",
                           surface_extent.width,
                           surface_extent.height,
                           scaling_capabilities.maxScaledImageExtent.width,
                           scaling_capabilities.maxScaledImageExtent.height);
        }
    }
    if scaling_capabilities.minScaledImageExtent.width != 0xFFFF_FFFF {
        assert(scaling_capabilities.minScaledImageExtent.height != 0xFFFF_FFFF);

        adjusted : bool;
        if surface_extent.width < scaling_capabilities.minScaledImageExtent.width {
            surface_extent.width = scaling_capabilities.minScaledImageExtent.width;
            adjusted = true;
        }
        if surface_extent.height < scaling_capabilities.minScaledImageExtent.height {
            surface_extent.height = scaling_capabilities.minScaledImageExtent.height;
            adjusted = true;
        }

        if adjusted {
            warningMessage("Requested surface extent for swapchain (% x %) is too small. It will be adjusted to % x %",
                           surface_extent.width,
                           surface_extent.height,
                           scaling_capabilities.minScaledImageExtent.width,
                           scaling_capabilities.minScaledImageExtent.height);
        }
    }

    //
    // Other stuff
    //

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

    queue_families_having_access_to_swapchain_images := u32.[
        device.queues[QueueType.GRAPHICS].family_index
    ];

    scaling_behaviour := VkSwapchainPresentScalingCreateInfoEXT.{
        scalingBehavior = present_scaling,
        presentGravityX = REQUESTED_GRAVITY_MODE,
        presentGravityY = REQUESTED_GRAVITY_MODE,
    };

    create_info := VkSwapchainCreateInfoKHR.{
        pNext                 = *scaling_behaviour,
        flags                 = 0,
        surface               = vulkan_window_data.surface,
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
        oldSwapchain          = vulkan_window_data.swapchain
    };

    debugCheckVK(device.loader.extensions.device.required.vkCreateSwapchainKHR(device.device, *create_info, null, *vulkan_window_data.swapchain));
    window_data.swapchain_is_outdated = false;

    if create_info.oldSwapchain != VK_NULL_HANDLE {
        device.loader.extensions.device.required.vkDestroySwapchainKHR(device.device, create_info.oldSwapchain, null);
    }

    //
    // Initialize swapchain images
    //

    swapchain_buffers_count : u32 = ---;
    device.loader.extensions.device.required.vkGetSwapchainImagesKHR(device.device,
                                                                     vulkan_window_data.swapchain,
                                                                     *swapchain_buffers_count,
                                                                     null);
    window_data.swapchain_buffers_count = cast,no_check(u8) swapchain_buffers_count;
    assert(window_data.swapchain_buffers_count > 0);

    if window_data.swapchain_buffers_count > VulkanWindowData.swapchain_textures.count {
        assertMessage("Swapchain buffers overflow: %/%. It seems like driver does some weird things, so you may just increase Device.MAX_SWAPCHAIN_BUFFERS",
                      window_data.swapchain_buffers_count,
                      VulkanWindowData.swapchain_textures.count);
    }

    infoMessage("Requested swapchain images: %, got: %", requested_swapchain_buffers_count, window_data.swapchain_buffers_count);

    swapchain_images : [VulkanWindowData.swapchain_textures.count] VkImage;
    device.loader.extensions.device.required.vkGetSwapchainImagesKHR(device.device,
                                                                     vulkan_window_data.swapchain,
                                                                     *swapchain_buffers_count,
                                                                     swapchain_images.data);
    assert(swapchain_buffers_count == window_data.swapchain_buffers_count);

    device.back_buffer_format = vulkanFormatToTextureFormat(allowed_surface_format.format);

    #if DEBUG_BUILD {
        clear_color := v4f.{ 0.3, 0.3, 0.3, 0.0 };
        if textureFormatFlags(device.back_buffer_format) & .SRGB {
            clear_color = gammaToLinear(clear_color);
        }
    } else {
        clear_color :: v4f.{};
    }

    window_title := getWindowTitle(window);

    swapchain_images_it := swapchain_images.data;

    // @TODO: #SwapchainBuffers.
    for * texture : toView(vulkan_window_data.swapchain_textures.data, window_data.swapchain_buffers_count) {
        texture.dimension             = ._2D;
        texture.format                = device.back_buffer_format;
        texture.flags                 = .SWAPCHAIN;
        texture.width                 = cast(u16) surface_extent.width;
        texture.height                = cast(u16) surface_extent.height;
        texture.depth                 = 0;
        texture.samples_count         = 1;
        texture.mips_count            = 1;
        texture.clear_value.color_f32 = clear_color;
        texture.current_owner         = .GRAPHICS;
        texture.possible_owners.count = 1;
        texture.possible_owners[0]    = .GRAPHICS;
        texture.image                 = swapchain_images_it.*;
        texture.current_layout        = .VK_IMAGE_LAYOUT_UNDEFINED;

        #if REQUESTED_USAGE_FLAGS & .VK_IMAGE_USAGE_SAMPLED_BIT          then texture.usages |= .SHADER_READ;
        #if REQUESTED_USAGE_FLAGS & .VK_IMAGE_USAGE_STORAGE_BIT          then texture.usages |= .SHADER_WRITE;
        #if REQUESTED_USAGE_FLAGS & .VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT then texture.usages |= .COLOR_TARGET;

        if !texture.name {
            Basic.print(*builder, "Window \"%\"/Swapchain image #%", window_title, it_index);
            texture.name = Basic.builder_to_string(*builder); // We need to preserve it, so do not use Basic.temp
        }

        setVulkanObjectName(texture.image, texture.name);

        VIEW_USAGES :: Texture.Usage.[
            .COLOR_TARGET,
            .SHADER_READ,
        ];

        for * view : vulkan_window_data.swapchain_texture_views[it_index] {
            if !(texture.usages & VIEW_USAGES[it_index]) continue;

            view.texture    = texture;
            view.dimension  = texture.dimension;
            view.format     = texture.format;
            view.usage      = VIEW_USAGES[it_index];
            view.mips_count = 1;

            if view.view {
                vkDestroyImageView(device.device, view.view, null);
            }

            usage_info := VkImageViewUsageCreateInfo.{
                usage = textureUsageToVulkanUsageFlags(view.usage, false)
            };

            view_create_info := VkImageViewCreateInfo.{
                pNext            = *usage_info,
                flags            = 0,
                image            = texture.image,
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

            debugCheckVK(vkCreateImageView(device.device, *view_create_info, null, *view.view));

            if !view.name {
                Basic.print(*builder, "% % view", texture.name, view.usage);
                view.name = Basic.builder_to_string(*builder); // We need to preserve it, so do not use Basic.temp
            }

            setVulkanObjectName(view.view, view.name);
        }

        swapchain_images_it += 1;
    }
}

createFences :: () {
    device := cast(*VulkanDevice) context.pet.render.device;

    create_info := VkFenceCreateInfo.{
        flags = .VK_FENCE_CREATE_SIGNALED_BIT,
    };

    for * frame_data, frame_index : toView(device.frame_data.data, cast(s64) device.frame_buffering) {
        for * frame_data.fences {
            debugCheckVK(vkCreateFence(device.device, *create_info, null, it));
            setVulkanObjectName(it.*, "Frame #%/% Fence", frame_index, cast(QueueType) it_index);
        }
    }
}

createFrameSemaphores :: () {
    device := cast(*VulkanDevice) context.pet.render.device;

    create_info : VkSemaphoreCreateInfo;

    for * toView(device.frame_data.data, cast(s64) device.frame_buffering) {
        debugCheckVK(vkCreateSemaphore(device.device, *create_info, null, *it.graphics_semaphore));
        setVulkanObjectName(it.graphics_semaphore, "Frame #%/Graphics semaphore", it_index);

        debugCheckVK(vkCreateSemaphore(device.device, *create_info, null, *it.post_frame_semaphore));
        setVulkanObjectName(it.post_frame_semaphore, "Frame #%/Post frame semaphore", it_index);
    }
}

createWindowSemaphores :: (window : *Window) {
    device := cast(*VulkanDevice) context.pet.render.device;

    create_info : VkSemaphoreCreateInfo;

    for * toView(device.frame_data.data, cast(s64) device.frame_buffering) {
        debugCheckVK(vkCreateSemaphore(device.device, *create_info, null, *it.acquire_semaphores[window.id]));
        setVulkanObjectName(it.acquire_semaphores[window.id], "Frame #%/Graphics semaphore", it_index);
    }
}

// @TODO: #NotExistedQueues
createCommandPools :: () {
    device := cast(*VulkanDevice) context.pet.render.device;

    create_info := VkCommandPoolCreateInfo.{
        queueFamilyIndex = VK_QUEUE_FAMILY_IGNORED // Will be set in a loop
    };

    for * frame_data, frame_index : toView(device.frame_data.data, cast(s64) device.frame_buffering) {
        queues_it := device.queues.data;

        for * frame_data.command_pools {
            create_info.queueFamilyIndex = queues_it.family_index;

            debugCheckVK(vkCreateCommandPool(device.device, *create_info, null, it));
            setVulkanObjectName(it.*, "Frame #%/% command pool", frame_index, cast(QueueType) it_index);

            queues_it += 1;
        }
    }
}

createCommandBuffers :: () {
    device := cast(*VulkanDevice) context.pet.render.device;

    allocation_info := VkCommandBufferAllocateInfo.{
        commandPool        = null, // Will be set in a loop
        level              = .VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        commandBufferCount = cast(u32) Device.MAX_COMMAND_BUFFERS
    };

    for * frame_data, frame_index : toView(device.frame_data.data, cast(s64) device.frame_buffering) {
        command_buffers_it := frame_data.command_buffers.data;

        for command_pool, command_pool_index : frame_data.command_pools {
            allocation_info.commandPool = command_pool;

            debugCheckVK(vkAllocateCommandBuffers(device.device, *allocation_info, command_buffers_it));

            #if DEBUG_BUILD {
                local_command_buffers_it := command_buffers_it;

                for 0 .. Device.MAX_COMMAND_BUFFERS - 1 {
                    setVulkanObjectName(local_command_buffers_it.*,
                                        "Frame #%/% command buffer #%",
                                        frame_index,
                                        cast(QueueType) command_pool_index,
                                        it);

                    local_command_buffers_it += 1;
                }
            }

            command_buffers_it += Device.MAX_COMMAND_BUFFERS;
        }
    }
}

createSystemCommandBuffers :: () {
    device := cast(*VulkanDevice) context.pet.render.device;

    allocation_info := VkCommandBufferAllocateInfo.{
        commandPool        = null, // Will be set in a loop
        level              = .VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        commandBufferCount = FrameData.system_command_buffers.count
    };

    for * frame_data, frame_index : toView(device.frame_data.data, cast(s64) device.frame_buffering) {
        allocation_info.commandPool = frame_data.command_pools[QueueType.GRAPHICS];

        debugCheckVK(vkAllocateCommandBuffers(device.device, *allocation_info, frame_data.system_command_buffers.data));

        #if DEBUG_BUILD {
            for frame_data.system_command_buffers {
                setVulkanObjectName(it, "Frame #%/% system command buffer", frame_index, cast(SystemCommandBufferKind) it_index);
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

vkTypeToObjectType :: inline ($vkType : Type) -> VkObjectType #compile_time {
    #if vkType == {
        case VkInstance;               return .VK_OBJECT_TYPE_INSTANCE;
        case VkPhysicalDevice;         return .VK_OBJECT_TYPE_PHYSICAL_DEVICE;
        case VkDevice;                 return .VK_OBJECT_TYPE_DEVICE;
        case VkQueue;                  return .VK_OBJECT_TYPE_QUEUE;
        case VkSemaphore;              return .VK_OBJECT_TYPE_SEMAPHORE;
        case VkCommandBuffer;          return .VK_OBJECT_TYPE_COMMAND_BUFFER;
        case VkFence;                  return .VK_OBJECT_TYPE_FENCE;
        case VkDeviceMemory;           return .VK_OBJECT_TYPE_DEVICE_MEMORY;
        case VkBuffer;                 return .VK_OBJECT_TYPE_BUFFER;
        case VkImage;                  return .VK_OBJECT_TYPE_IMAGE;
        case VkEvent;                  return .VK_OBJECT_TYPE_EVENT;
        case VkBufferView;             return .VK_OBJECT_TYPE_BUFFER_VIEW;
        case VkImageView;              return .VK_OBJECT_TYPE_IMAGE_VIEW;
        case VkShaderModule;           return .VK_OBJECT_TYPE_SHADER_MODULE;
        case VkPipelineCache;          return .VK_OBJECT_TYPE_PIPELINE_CACHE;
        case VkPipelineLayout;         return .VK_OBJECT_TYPE_PIPELINE_LAYOUT;
        case VkRenderPass;             return .VK_OBJECT_TYPE_RENDER_PASS;
        case VkPipeline;               return .VK_OBJECT_TYPE_PIPELINE;
        case VkDescriptorSetLayout;    return .VK_OBJECT_TYPE_DESCRIPTOR_SET_LAYOUT;
        case VkSampler;                return .VK_OBJECT_TYPE_SAMPLER;
        case VkDescriptorPool;         return .VK_OBJECT_TYPE_DESCRIPTOR_POOL;
        case VkDescriptorSet;          return .VK_OBJECT_TYPE_DESCRIPTOR_SET;
        case VkFramebuffer;            return .VK_OBJECT_TYPE_FRAMEBUFFER;
        case VkCommandPool;            return .VK_OBJECT_TYPE_COMMAND_POOL;
        case VkSurfaceKHR;             return .VK_OBJECT_TYPE_SURFACE_KHR;
        case VkSwapchainKHR;           return .VK_OBJECT_TYPE_SWAPCHAIN_KHR;
        case VkDebugUtilsMessengerEXT; return .VK_OBJECT_TYPE_DEBUG_UTILS_MESSENGER_EXT;
        case;
            #assert false "Unhandled Vk* type";
            return .VK_OBJECT_TYPE_UNKNOWN;
    }
}

sortPhysicalDevices :: () -> [] PhysicalDeviceInfo {
    device := cast(*VulkanDevice) context.pet.render.device;

    physical_devices : [] VkPhysicalDevice;
    debugCheckVK(vkEnumeratePhysicalDevices(device.instance, cast(*u32) *physical_devices.count, null));

    if physical_devices.count <= 0 {
        assertMessage("Vulkan did not found compatible GPU");
        return .{};
    }

    physical_devices.data = pushToArena(*context.pet.arenas.per_frame, VkPhysicalDevice, physical_devices.count);
    debugCheckVK(vkEnumeratePhysicalDevices(device.instance, cast(*u32) *physical_devices.count, physical_devices.data));

    infos : [] PhysicalDeviceInfo = ---;
    infos.count = physical_devices.count;
    infos.data  = pushToArena(*context.pet.arenas.per_frame, PhysicalDeviceInfo, infos.count);

    infos_it := infos.data;
    for physical_devices {
        infos_it.physical_device = it;

        msft_properties : VkPhysicalDeviceLayeredDriverPropertiesMSFT;
        infos_it.descriptor_buffer_properties.pNext = *msft_properties;
        infos_it.properties12.pNext                 = *infos_it.descriptor_buffer_properties;
        infos_it.properties11.pNext                 = *infos_it.properties12;
        infos_it.properties2.pNext                  = *infos_it.properties11;
        vkGetPhysicalDeviceProperties2(infos_it.physical_device, *infos_it.properties2);

        if msft_properties.underlyingAPI != .VK_LAYERED_DRIVER_UNDERLYING_API_NONE_MSFT {
            infos.count -= 1;
            continue;
        }

        if infos_it.properties2.properties.apiVersion < VulkanDevice.MINIMAL_SUPPORTED_API_VERSION {
            infos.count -= 1;
            continue;
        }

        if infos_it.properties2.properties.deviceType == {
            case .VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU; #through;
            case .VK_PHYSICAL_DEVICE_TYPE_CPU;         #through;
            case .VK_PHYSICAL_DEVICE_TYPE_OTHER;
                infos.count -= 1;
                continue;
        }

        vkGetPhysicalDeviceMemoryProperties2(infos_it.physical_device, *infos_it.memory_properties);
        memory_heaps := toView(infos_it.memory_properties.memoryProperties.memoryHeaps.data,
                               infos_it.memory_properties.memoryProperties.memoryHeapCount);

        if infos_it.properties2.properties.deviceType == {
            case .VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU;
                infos_it.priority |= 1 << 4;

                for heap : memory_heaps {
                    if heap.flags & .VK_MEMORY_HEAP_DEVICE_LOCAL_BIT {
                        infos_it.memory_size += heap.size;
                    }
                }

            case .VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU;
                // infos_it.priority |= 0 << 4;

                for heap : memory_heaps {
                    infos_it.memory_size += heap.size;
                }
        }

        if infos_it.properties2.properties.apiVersion >= VK_API_VERSION_1_4 {
            infos_it.priority |= 2 << 2;
        } else if infos_it.properties2.properties.apiVersion >= VK_API_VERSION_1_3 {
            infos_it.priority |= 1 << 2;
        } else {
            #assert VulkanDevice.MINIMAL_SUPPORTED_API_VERSION == VK_API_VERSION_1_2;
            // infos_it.priority |= 0 << 2;
        }

        if cast(PCIVendorID) infos_it.properties2.properties.vendorID == {
            case .NVIDIA; infos_it.priority |= 3 << 0;
            case .AMD;    infos_it.priority |= 2 << 0;
            case .INTEL;  infos_it.priority |= 1 << 0;
            case;         // infos_it.priority |= 0 << 0;
        }

        infos_it += 1;
    }
    assert(infos_it == infos.data + infos.count);

    IntroSort.intro_sort(infos, (left : PhysicalDeviceInfo, right : PhysicalDeviceInfo) -> int {
        if left.priority > right.priority return -1;
        if left.priority < right.priority return  1;

        if left.memory_size > right.memory_size return -1;
        if left.memory_size < right.memory_size return  1;

        return 0;
    });

    return infos;
}

getVkPresentMode :: inline (vsync_enabled : bool, tearing_allowed : bool) -> VkPresentModeKHR {
    if vsync_enabled {
        if tearing_allowed {
            return .VK_PRESENT_MODE_FIFO_RELAXED_KHR;
        }
        return .VK_PRESENT_MODE_FIFO_KHR;
    }
    if tearing_allowed {
        return .VK_PRESENT_MODE_IMMEDIATE_KHR;
    }
    return .VK_PRESENT_MODE_MAILBOX_KHR;
}

scalingModeToVkPresentScalingFlags :: inline (scaling_mode : ScalingMode) -> VkPresentScalingFlagsEXT {
    if #complete scaling_mode == {
        case .NONE;         return .VK_PRESENT_SCALING_ONE_TO_ONE_BIT_EXT;
        case .ASPECT_RATIO; return .VK_PRESENT_SCALING_ASPECT_RATIO_STRETCH_BIT_EXT;
        case .STRETCH;      return .VK_PRESENT_SCALING_STRETCH_BIT_EXT;
    }
    return .VK_PRESENT_SCALING_ONE_TO_ONE_BIT_EXT;
}
