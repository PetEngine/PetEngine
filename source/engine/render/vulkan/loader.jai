VulkanLoader :: struct {
    layers : struct {
        required : struct {
            #if DEBUG_BUILD {
                validation : void; @VK_LAYER_KHRONOS_validation
            }
        };

        optional : struct {
        };
    };

    extensions : struct {
        instance : struct {
            required : struct {
                vkDestroySurfaceKHR                       : PFN_vkDestroySurfaceKHR;                       @VK_KHR_surface
                vkGetPhysicalDeviceSurfaceSupportKHR      : PFN_vkGetPhysicalDeviceSurfaceSupportKHR;      @VK_KHR_surface
                vkGetPhysicalDeviceSurfaceCapabilitiesKHR : PFN_vkGetPhysicalDeviceSurfaceCapabilitiesKHR; @VK_KHR_surface
                vkGetPhysicalDeviceSurfaceFormatsKHR      : PFN_vkGetPhysicalDeviceSurfaceFormatsKHR;      @VK_KHR_surface
                vkGetPhysicalDeviceSurfacePresentModesKHR : PFN_vkGetPhysicalDeviceSurfacePresentModesKHR; @VK_KHR_surface
                #if OS == .WINDOWS {
                    vkCreateWin32SurfaceKHR : PFN_vkCreateWin32SurfaceKHR; @VK_KHR_win32_surface
                } else {
                    notImplemented();
                }
                vkGetPhysicalDeviceSurfaceCapabilities2KHR : PFN_vkGetPhysicalDeviceSurfaceCapabilities2KHR; @VK_KHR_get_surface_capabilities2
                surface_maintenance1                       : void;                                           @VK_EXT_surface_maintenance1
            };

            optional : struct {
                #if DEBUG_BUILD {
                    vkSetDebugUtilsObjectNameEXT   : PFN_vkSetDebugUtilsObjectNameEXT;   @VK_EXT_debug_utils
                    vkQueueBeginDebugUtilsLabelEXT : PFN_vkQueueBeginDebugUtilsLabelEXT; @VK_EXT_debug_utils
                    vkQueueEndDebugUtilsLabelEXT   : PFN_vkQueueEndDebugUtilsLabelEXT;   @VK_EXT_debug_utils
                    vkCmdBeginDebugUtilsLabelEXT   : PFN_vkCmdBeginDebugUtilsLabelEXT;   @VK_EXT_debug_utils
                    vkCmdEndDebugUtilsLabelEXT     : PFN_vkCmdEndDebugUtilsLabelEXT;     @VK_EXT_debug_utils
                }
                vkCreateDebugUtilsMessengerEXT  : PFN_vkCreateDebugUtilsMessengerEXT;  @VK_EXT_debug_utils
                vkDestroyDebugUtilsMessengerEXT : PFN_vkDestroyDebugUtilsMessengerEXT; @VK_EXT_debug_utils
            };
        };

        device : struct {
            required : struct {
                vkCreateSwapchainKHR    : PFN_vkCreateSwapchainKHR;    @VK_KHR_swapchain
                vkDestroySwapchainKHR   : PFN_vkDestroySwapchainKHR;   @VK_KHR_swapchain
                vkGetSwapchainImagesKHR : PFN_vkGetSwapchainImagesKHR; @VK_KHR_swapchain
                vkAcquireNextImage2KHR  : PFN_vkAcquireNextImage2KHR;  @VK_KHR_swapchain
                vkQueuePresentKHR       : PFN_vkQueuePresentKHR;       @VK_KHR_swapchain
                swapchain_maintenance1  : void;                        @VK_EXT_swapchain_maintenance1
            };

            optional : struct {
                vkGetDescriptorSetLayoutSizeEXT          : PFN_vkGetDescriptorSetLayoutSizeEXT;          @VK_EXT_descriptor_buffer
                vkGetDescriptorSetLayoutBindingOffsetEXT : PFN_vkGetDescriptorSetLayoutBindingOffsetEXT; @VK_EXT_descriptor_buffer
                vkGetDescriptorEXT                       : PFN_vkGetDescriptorEXT;                       @VK_EXT_descriptor_buffer
                vkCmdBindDescriptorBuffersEXT            : PFN_vkCmdBindDescriptorBuffersEXT;            @VK_EXT_descriptor_buffer
                vkCmdSetDescriptorBufferOffsetsEXT       : PFN_vkCmdSetDescriptorBufferOffsetsEXT;       @VK_EXT_descriptor_buffer
            };
        };
    };
}

gatherVulkanLayers :: () -> (required : [] string, optional : [] string) #compile_time {
    required_layers : [..] string;
    required_layers.allocator = Basic.temp;

    struct_info := type_info(type_of(VulkanLoader.layers.required));
    assert(struct_info.type == .STRUCT);

    if struct_info.members.count > 0 {
        Basic.array_reserve(*required_layers, struct_info.members.count);

        for struct_info.members {
            layer_name := it.notes[0];

            assert(layer_name);
            assert(layer_name.count < VK_MAX_EXTENSION_NAME_SIZE);

            Basic.array_add_if_unique(*required_layers, layer_name);
        }
    }

    optional_layers : [..] string;
    optional_layers.allocator = Basic.temp;

    struct_info = type_info(type_of(VulkanLoader.layers.optional));
    assert(struct_info.type == .STRUCT);

    if struct_info.members.count > 0 {
        Basic.array_reserve(*optional_layers, struct_info.members.count);

        for struct_info.members {
            layer_name := it.notes[0];

            assert(layer_name);
            assert(layer_name.count < VK_MAX_EXTENSION_NAME_SIZE);

            Basic.array_add_if_unique(*optional_layers, layer_name);
        }
    }

    return required_layers, optional_layers;
}

gatherVulkanInstanceExtensions :: () -> (required : [] string, optional : [] string) #compile_time {
    required_extensions : [..] string;
    required_extensions.allocator = Basic.temp;

    struct_info := type_info(type_of(VulkanLoader.extensions.instance.required));
    assert(struct_info.type == .STRUCT);

    if struct_info.members.count > 0 {
        Basic.array_reserve(*required_extensions, struct_info.members.count);

        for struct_info.members {
            extension_name := it.notes[0];

            assert(extension_name);
            assert(extension_name.count < VK_MAX_EXTENSION_NAME_SIZE);

            Basic.array_add_if_unique(*required_extensions, extension_name);
        }
    }

    optional_extensions : [..] string;
    optional_extensions.allocator = Basic.temp;

    struct_info = type_info(type_of(VulkanLoader.extensions.instance.optional));
    assert(struct_info.type == .STRUCT);

    if struct_info.members.count > 0 {
        Basic.array_reserve(*optional_extensions, struct_info.members.count);

        for struct_info.members {
            extension_name := it.notes[0];

            assert(extension_name);
            assert(extension_name.count < VK_MAX_EXTENSION_NAME_SIZE);

            Basic.array_add_if_unique(*optional_extensions, extension_name);
        }
    }

    return required_extensions, optional_extensions;
}

gatherVulkanDeviceExtensions :: () -> (required : [] string, optional : [] string) #compile_time {
    required_extensions : [..] string;
    required_extensions.allocator = Basic.temp;

    struct_info := type_info(type_of(VulkanLoader.extensions.device.required));
    assert(struct_info.type == .STRUCT);

    if struct_info.members.count > 0 {
        Basic.array_reserve(*required_extensions, struct_info.members.count);

        for struct_info.members {
            extension_name := it.notes[0];

            assert(extension_name);
            assert(extension_name.count < VK_MAX_EXTENSION_NAME_SIZE);

            Basic.array_add_if_unique(*required_extensions, extension_name);
        }
    }

    optional_extensions : [..] string;
    optional_extensions.allocator = Basic.temp;

    struct_info = type_info(type_of(VulkanLoader.extensions.device.optional));
    assert(struct_info.type == .STRUCT);

    if struct_info.members.count > 0 {
        Basic.array_reserve(*optional_extensions, struct_info.members.count);

        for struct_info.members {
            extension_name := it.notes[0];

            assert(extension_name);
            assert(extension_name.count < VK_MAX_EXTENSION_NAME_SIZE);

            Basic.array_add_if_unique(*optional_extensions, extension_name);
        }
    }

    return required_extensions, optional_extensions;
}

loadVulkanInstanceExtensionsFunctions :: (loader : *VulkanLoader, instance : VkInstance, enabled_instance_extensions : *[..] string) {
    base_address := cast(*void) *loader.extensions.instance.required;

    struct_info := type_info(type_of(loader.extensions.instance.required));
    assert(struct_info.type == .STRUCT);

    for struct_info.members {
        if it.type.type == .VOID continue;

        function := vkGetInstanceProcAddr(instance, it.name.data);
        if function == null {
            assertMessage("Function \"%\" was not found, but \"%\" instance extension was enabled", it.name, it.notes[0]);
        }

        member_address   := cast(**void) (base_address + it.offset_in_bytes);
        member_address.*  = cast(*void) function;
    }

    base_address = cast(*void) *loader.extensions.instance.optional;

    struct_info = type_info(type_of(loader.extensions.instance.optional));
    assert(struct_info.type == .STRUCT);

    for struct_info.members {
        if it.type.type == .VOID continue;

        member_extension_name := it.notes[0];
        if !Basic.array_find(enabled_instance_extensions.*, member_extension_name) {
            continue;
        }

        function := vkGetInstanceProcAddr(instance, it.name.data);
        if function == null {
            assertMessage("Function \"%\" was not found, but \"%\" instance extension was enabled", it.name, member_extension_name);
        }

        member_address   := cast(**void) (base_address + it.offset_in_bytes);
        member_address.*  = cast(*void) function;
    }
}

loadVulkanDeviceExtensionsFunctions :: (loader : *VulkanLoader, device : VkDevice, enabled_device_extensions : *[..] string) {
    base_address := cast(*void) *loader.extensions.device.required;

    struct_info := type_info(type_of(loader.extensions.device.required));
    assert(struct_info.type == .STRUCT);

    for struct_info.members {
        if it.type.type == .VOID continue;

        function := vkGetDeviceProcAddr(device, it.name.data);
        if function == null {
            assertMessage("Function \"%\" was not found, but \"%\" device extension was enabled", it.name, it.notes[0]);
        }

        member_address   := cast(**void) (base_address + it.offset_in_bytes);
        member_address.*  = cast(*void) function;
    }

    base_address = cast(*void) *loader.extensions.device.optional;

    struct_info = type_info(type_of(loader.extensions.device.optional));
    assert(struct_info.type == .STRUCT);

    for struct_info.members {
        if it.type.type == .VOID continue;

        member_extension_name := it.notes[0];
        if !Basic.array_find(enabled_device_extensions.*, member_extension_name) {
            continue;
        }

        function := vkGetDeviceProcAddr(device, it.name.data);
        if function == null {
            assertMessage("Function \"%\" was not found, but \"%\" device extension was enabled", it.name, member_extension_name);
        }

        member_address   := cast(**void) (base_address + it.offset_in_bytes);
        member_address.*  = cast(*void) function;
    }
}
