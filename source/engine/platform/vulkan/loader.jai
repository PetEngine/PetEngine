// @TODO: Link all Vulkan functions dynamically
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
                vkDestroySurfaceKHR                       : PFN_vkDestroySurfaceKHR;                       @VK_KHR_surface;
                vkGetPhysicalDeviceSurfaceCapabilitiesKHR : PFN_vkGetPhysicalDeviceSurfaceCapabilitiesKHR; @VK_KHR_surface;
                vkGetPhysicalDeviceSurfaceFormatsKHR      : PFN_vkGetPhysicalDeviceSurfaceFormatsKHR;      @VK_KHR_surface;
                #if OS == .WINDOWS {
                    vkCreateWin32SurfaceKHR               : PFN_vkCreateWin32SurfaceKHR;                   @VK_KHR_win32_surface;
                } else {
                    notImplemented();
                }
            };

            optional : struct {
                #if DEBUG_BUILD {
                    vkSetDebugUtilsObjectNameEXT : PFN_vkSetDebugUtilsObjectNameEXT;    @VK_EXT_debug_utils
                }
                vkQueueBeginDebugUtilsLabelEXT   : PFN_vkQueueBeginDebugUtilsLabelEXT;  @VK_EXT_debug_utils
                vkQueueEndDebugUtilsLabelEXT     : PFN_vkQueueEndDebugUtilsLabelEXT;    @VK_EXT_debug_utils
                vkCmdBeginDebugUtilsLabelEXT     : PFN_vkCmdBeginDebugUtilsLabelEXT;    @VK_EXT_debug_utils
                vkCmdEndDebugUtilsLabelEXT       : PFN_vkCmdEndDebugUtilsLabelEXT;      @VK_EXT_debug_utils
                vkCreateDebugUtilsMessengerEXT   : PFN_vkCreateDebugUtilsMessengerEXT;  @VK_EXT_debug_utils
                vkDestroyDebugUtilsMessengerEXT  : PFN_vkDestroyDebugUtilsMessengerEXT; @VK_EXT_debug_utils
            };
        };

        device : struct {
            required : struct {
                vkAcquireNextImage2KHR  : PFN_vkAcquireNextImage2KHR;  @VK_KHR_swapchain
                vkCreateSwapchainKHR    : PFN_vkCreateSwapchainKHR;    @VK_KHR_swapchain
                vkDestroySwapchainKHR   : PFN_vkDestroySwapchainKHR;   @VK_KHR_swapchain
                vkGetSwapchainImagesKHR : PFN_vkGetSwapchainImagesKHR; @VK_KHR_swapchain
            };

            optional : struct {
            };
        };
    };
}

// @TODO: #PerFrameArena
gatherVulkanLayers :: () -> (required : [] string, optional : [] string) {
    required_layers : [..] string;
    required_layers.allocator = Basic.temporary_allocator;

    struct_info := type_info(type_of(VulkanLoader.layers.required));

    if struct_info.members.count > 0 {
        Basic.array_reserve(*required_layers, struct_info.members.count);

        for * struct_info.members {
            layer_name := it.notes[0];

            already_added := false;
            for required_layers {
                if String.equal(it, layer_name) {
                    already_added = true;
                    break;
                }
            }

            if !already_added {
                assert(layer_name.count < VK_MAX_EXTENSION_NAME_SIZE);
                Basic.array_add(*required_layers, layer_name);
            }
        }
    }

    optional_layers : [..] string;
    optional_layers.allocator = Basic.temporary_allocator;

    struct_info = type_info(type_of(VulkanLoader.layers.optional));

    if struct_info.members.count > 0 {
        Basic.array_reserve(*optional_layers, struct_info.members.count);

        for * struct_info.members {
            layer_name := it.notes[0];

            already_added := false;
            for optional_layers {
                if String.equal(it, layer_name) {
                    already_added = true;
                    break;
                }
            }

            if !already_added {
                assert(layer_name.count < VK_MAX_EXTENSION_NAME_SIZE);
                Basic.array_add(*optional_layers, layer_name);
            }
        }
    }

    return required_layers, optional_layers;
}

// @TODO: #PerFrameArena
gatherVulkanInstanceExtensions :: () -> (required : [] string, optional : [] string) {
    required_extensions : [..] string;
    required_extensions.allocator = Basic.temporary_allocator;

    struct_info := type_info(type_of(VulkanLoader.extensions.instance.required));

    if struct_info.members.count > 0 {
        Basic.array_reserve(*required_extensions, struct_info.members.count);

        for * struct_info.members {
            extension_name := it.notes[0];

            already_added := false;
            for required_extensions {
                if String.equal(it, extension_name) {
                    already_added = true;
                    break;
                }
            }

            if !already_added {
                assert(extension_name.count < VK_MAX_EXTENSION_NAME_SIZE);
                Basic.array_add(*required_extensions, extension_name);
            }
        }
    }

    optional_extensions : [..] string;
    optional_extensions.allocator = Basic.temporary_allocator;

    struct_info = type_info(type_of(VulkanLoader.extensions.instance.optional));

    if struct_info.members.count > 0 {
        Basic.array_reserve(*optional_extensions, struct_info.members.count);

        for * struct_info.members {
            extension_name := it.notes[0];

            already_added := false;
            for optional_extensions {
                if String.equal(it, extension_name) {
                    already_added = true;
                    break;
                }
            }

            if !already_added {
                assert(extension_name.count < VK_MAX_EXTENSION_NAME_SIZE);
                Basic.array_add(*optional_extensions, extension_name);
            }
        }
    }

    return required_extensions, optional_extensions;
}

// @TODO: #PerFrameArena
gatherVulkanDeviceExtensions :: () -> (required : [] string, optional : [] string) {
    required_extensions : [..] string;
    required_extensions.allocator = Basic.temporary_allocator;

    struct_info := type_info(type_of(VulkanLoader.extensions.device.required));

    if struct_info.members.count > 0 {
        Basic.array_reserve(*required_extensions, struct_info.members.count);

        for * struct_info.members {
            extension_name := it.notes[0];

            already_added := false;
            for required_extensions {
                if String.equal(it, extension_name) {
                    already_added = true;
                    break;
                }
            }

            if !already_added {
                assert(extension_name.count < VK_MAX_EXTENSION_NAME_SIZE);
                Basic.array_add(*required_extensions, extension_name);
            }
        }
    }


    optional_extensions : [..] string;
    optional_extensions.allocator = Basic.temporary_allocator;

    struct_info = type_info(type_of(VulkanLoader.extensions.device.optional));

    if struct_info.members.count > 0 {
        Basic.array_reserve(*optional_extensions, struct_info.members.count);

        for * struct_info.members {
            extension_name := it.notes[0];

            already_added := false;
            for optional_extensions {
                if String.equal(it, extension_name) {
                    already_added = true;
                    break;
                }
            }

            if !already_added {
                assert(extension_name.count < VK_MAX_EXTENSION_NAME_SIZE);
                Basic.array_add(*optional_extensions, extension_name);
            }
        }
    }

    return required_extensions, optional_extensions;
}

loadVulkanInstanceExtensionsFunctions :: (loader : *VulkanLoader, instance : VkInstance, enabled_instance_extensions : *[..] string) {
    base_address := cast(*void) *loader.extensions.instance.required;

    for * type_info(type_of(loader.extensions.instance.required)).members {
        function := vkGetInstanceProcAddr(instance, cast(*s8) it.name.data);
        if function == null {
            assertMessage("Function \"%\" was not found, but \"%\" instance extension was enabled", it.name, it.notes[0]);
        }

        member_address   := cast(**void) (base_address + it.offset_in_bytes);
        <<member_address  = cast(*void) function;
    }

    base_address = cast(*void) *loader.extensions.instance.optional;

    for *members_it : type_info(type_of(loader.extensions.instance.optional)).members {
        memeber_extension_name := members_it.notes[0];
        function               := vkGetInstanceProcAddr(instance, cast(*s8) members_it.name.data);

        for <<enabled_instance_extensions {
            if String.equal(it, memeber_extension_name) {
                if function == null {
                    assertMessage("Function \"%\" was not found, but \"%\" instance extension was enabled",
                                  members_it.name,
                                  memeber_extension_name);
                }
                break;
            }
        }

        member_address   := cast(**void) (base_address + members_it.offset_in_bytes);
        <<member_address  = cast(*void) function;
    }
}

loadVulkanDeviceExtensionsFunctions :: (loader : *VulkanLoader, device : VkDevice, enabled_device_extensions : *[..] string) {
    base_address := cast(*void) *loader.extensions.device.required;

    for * type_info(type_of(loader.extensions.device.required)).members {
        function := vkGetDeviceProcAddr(device, cast(*s8) it.name.data);
        if function == null {
            assertMessage("Function \"%\" was not found, but \"%\" device extension was enabled", it.name, it.notes[0]);
        }

        member_address   := cast(**void) (base_address + it.offset_in_bytes);
        <<member_address  = cast(*void) function;
    }

    base_address = cast(*void) *loader.extensions.device.optional;

    for *members_it : type_info(type_of(loader.extensions.device.optional)).members {
        memeber_extension_name := members_it.notes[0];
        function               := vkGetDeviceProcAddr(device, cast(*s8) members_it.name.data);

        for <<enabled_device_extensions {
            if String.equal(it, memeber_extension_name) {
                if function == null {
                    assertMessage("Function \"%\" was not found, but \"%\" device extension was enabled",
                                  members_it.name, memeber_extension_name);
                }
                break;
            }
        }

        member_address   := cast(**void) (base_address + members_it.offset_in_bytes);
        <<member_address  = cast(*void) function;
    }
}
