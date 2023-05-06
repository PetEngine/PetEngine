VulkanDevice :: struct {
    #as using public_data : Device;

    MINIMAL_REQUIRED_API_VERSION :: VK_API_VERSION_1_1;

    instance        : VkInstance       = VK_NULL_HANDLE;
    physical_device : VkPhysicalDevice = VK_NULL_HANDLE;
    device          : VkDevice         = VK_NULL_HANDLE;

    queues : [#run Basic.enum_highest_value(QueueTypes) + 1] VulkanQueue;

    surface   : VkSurfaceKHR;
    swapchain : VkSwapchainKHR;

    messenger : VkDebugUtilsMessengerEXT = VK_NULL_HANDLE;

    api_versions : struct {
        instance        : u32;
        physical_device : u32;
    };

    instance_layers : struct {
        required : struct {
            #if DEBUG_BUILD {
                validation : void; @VK_LAYER_KHRONOS_validation
            }
        };

        optional : struct {
        };
    };

    instance_extensions : struct {
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

    device_extensions : struct {
        required : struct {
            vkAcquireNextImage2KHR  : PFN_vkAcquireNextImage2KHR;  @VK_KHR_swapchain
            vkCreateSwapchainKHR    : PFN_vkCreateSwapchainKHR;    @VK_KHR_swapchain
            vkDestroySwapchainKHR   : PFN_vkDestroySwapchainKHR;   @VK_KHR_swapchain
            vkGetSwapchainImagesKHR : PFN_vkGetSwapchainImagesKHR; @VK_KHR_swapchain
        };

        optional : struct {
        };
    };
}

VulkanQueue :: struct {
    handle          : VkQueue = VK_NULL_HANDLE;
    family_index    : u32     = 0xFFFF_FFFF;
    index_in_family : u32;
}

// @TODO: #VulkanDeviceStorage. Find a better way.
g_device : VulkanDevice;

createVulkanDevice :: (window : *Window) -> *VulkanDevice #must {
    device := *g_device;

    enabled_instance_extensions : [..] string;
    defer Basic.array_free(enabled_instance_extensions);

    enabled_device_extensions : [..] string;
    defer Basic.array_free(enabled_device_extensions);

    createInstance(device, *enabled_instance_extensions);
    loadInstanceExtensionsFunctions(device, *enabled_instance_extensions);
    initMessengerCallback(device);
    findCompatiblePhysicalDevice(device);
    gatherQueuesInfo(device);
    createDevice(device, *enabled_device_extensions);
    loadDeviceExtensionsFunctions(device, *enabled_device_extensions);
    getQueues(device);
    createSurface(device, window);
    createSwapchain(device, window);

    return device;
}

destroyVulkanDevice :: (device : *VulkanDevice) {
    assert(device == *g_device);

    device.device_extensions.required.vkDestroySwapchainKHR(device.device, device.swapchain, null); // @TODO: VkAllocationCallbacks
    device.instance_extensions.required.vkDestroySurfaceKHR(device.instance, device.surface, null); // @TODO: VkAllocationCallbacks

    vkDestroyDevice(device.device, null); // @TODO: VkAllocationCallbacks

    if device.instance_extensions.optional.vkDestroyDebugUtilsMessengerEXT {
        // @TODO: VkAllocationCallbacks
        device.instance_extensions.optional.vkDestroyDebugUtilsMessengerEXT(device.instance, device.messenger, null);
    }
    vkDestroyInstance(device.instance, null); // @TODO: VkAllocationCallbacks
}

setObjectName :: (device : *VulkanDevice, object_type : VkObjectType, object : *void, name : string) {
    #if DEBUG_BUILD {
        if device.instance_extensions.optional.vkSetDebugUtilsObjectNameEXT {
            object_name := pushToArena(*context.pet_engine_state.per_frame_arena, s8, name.count + 1);
            memcpy(object_name, name.data, name.count);

            name_info := VkDebugUtilsObjectNameInfoEXT.{
                sType        = .VK_STRUCTURE_TYPE_DEBUG_UTILS_OBJECT_NAME_INFO_EXT,
                pNext        = null,
                objectType   = object_type,
                objectHandle = cast(u64) object,
                pObjectName  = object_name
            };

            device.instance_extensions.optional.vkSetDebugUtilsObjectNameEXT(device.device, *name_info);
            assert(result == .VK_SUCCESS);
        }
    }
}

setObjectName :: (device : *VulkanDevice, object_type : VkObjectType, object : *void, $format : string, args : ..Any) {
    #if DEBUG_BUILD {
        if device.instance_extensions.optional.vkSetDebugUtilsObjectNameEXT {
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

            result := device.instance_extensions.optional.vkSetDebugUtilsObjectNameEXT(device.device, *name_info);
            assert(result == .VK_SUCCESS);
        }
    }
}

#scope_file

String   :: #import "String";
Compiler :: #import "Compiler";

scanVulkanDeviceForInstanceLayers :: () -> (required : [] string, optional : [] string) {
    required_layers : [..] string;
    required_layers.allocator = Basic.temporary_allocator;

    for * type_info(type_of(VulkanDevice.instance_layers.required)).members {
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

    optional_layers : [..] string;
    optional_layers.allocator = Basic.temporary_allocator;

    for * type_info(type_of(VulkanDevice.instance_layers.optional)).members {
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

    return required_layers, optional_layers;
}

scanVulkanDeviceForInstanceExtensions :: () -> (required : [] string, optional : [] string) {
    required_extensions : [..] string;
    required_extensions.allocator = Basic.temporary_allocator;

    for * type_info(type_of(VulkanDevice.instance_extensions.required)).members {
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

    optional_extensions : [..] string;
    optional_extensions.allocator = Basic.temporary_allocator;

    for * type_info(type_of(VulkanDevice.instance_extensions.optional)).members {
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

    return required_extensions, optional_extensions;
}

createInstance :: (device : *VulkanDevice, enabled_instance_extensions : *[..] string) {
    defer Basic.reset_temporary_storage();

    builder : Basic.String_Builder;
    builder.allocator = Basic.temporary_allocator;

    layers_to_apply : [..] *s8;
    layers_to_apply.allocator = Basic.temporary_allocator;

    {
        layers_count : u32;
        result := vkEnumerateInstanceLayerProperties(*layers_count, null);
        assert(result == .VK_SUCCESS);

        layers := pushToArena(*context.pet_engine_state.per_frame_arena, VkLayerProperties, layers_count);
        result = vkEnumerateInstanceLayerProperties(*layers_count, layers);
        assert(result == .VK_SUCCESS);

        Basic.print_to_builder(*builder, "Available instance layers (%):\n", layers_count);
        layers_it := layers;
        for 0 .. layers_count - 1 {
            Basic.print_to_builder(*builder, "            %\n", to_string(cast(*u8) layers_it.layerName.data));
            layers_it += 1;
        }

        infoMessage("%", Basic.builder_to_string(*builder), new_line = false);

        REQUIRED_LAYERS, OPTIONAL_LAYERS :: #run scanVulkanDeviceForInstanceLayers();

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
            for 0 .. layers_count - 1 {
                if String.equal(to_string(cast(*u8) layers_it.layerName.data), optional_layers_it) {
                    Basic.array_add(*layers_to_apply, cast(*s8) optional_layers_it.data);
                    break;
                }
                layers_it += 1;
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
        result := vkEnumerateInstanceExtensionProperties(null, *extensions_count, null);
        assert(result == .VK_SUCCESS);

        extensions := pushToArena(*context.pet_engine_state.per_frame_arena, VkExtensionProperties, extensions_count);
        result = vkEnumerateInstanceExtensionProperties(null, *extensions_count, extensions);
        assert(result == .VK_SUCCESS);

        Basic.print_to_builder(*builder, "Available instance extensions (%):\n", extensions_count);
        extensions_it := extensions;
        for 0 .. extensions_count - 1 {
            Basic.print_to_builder(*builder, "            %\n", to_string(cast(*u8) extensions_it.extensionName.data));
            extensions_it += 1;
        }

        infoMessage("%", Basic.builder_to_string(*builder), new_line = false);

        REQUIRED_EXTENSIONS, OPTIONAL_EXTENSIONS :: #run scanVulkanDeviceForInstanceExtensions();

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
            for 0 .. extensions_count - 1 {
                if String.equal(to_string(cast(*u8) extensions_it.extensionName.data), optional_extensions_it) {
                    Basic.array_add(enabled_instance_extensions, optional_extensions_it);
                    break;
                }
                extensions_it += 1;
            }
        }

        Basic.print_to_builder(*builder, "Applying instance extensions (%):\n", enabled_instance_extensions.count);
        for <<enabled_instance_extensions {
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
        apiVersion         = 0, // Will be set later in the loop
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

    for < 3..1 {
        application_info.apiVersion = VK_MAKE_API_VERSION(0, 1, cast(u32) it, 0);

        // @TODO: VkAllocationCallbacks
        if vkCreateInstance(*instance_create_info, null, *device.instance) == .VK_SUCCESS {
            break;
        }

        assert(device.instance == VK_NULL_HANDLE);
    }

    assert(device.instance != VK_NULL_HANDLE,
           "Vulkan instance initialization has failed for some reason. Maybe vulkan is just not supported");

    device.api_versions.instance = application_info.apiVersion;
    result := vkEnumerateInstanceVersion(*device.api_versions.instance);
    assert(result == .VK_SUCCESS);

    infoMessage("Instance API version: %.%.%.%",
                VK_API_VERSION_VARIANT(device.api_versions.instance),
                VK_API_VERSION_MAJOR(device.api_versions.instance),
                VK_API_VERSION_MINOR(device.api_versions.instance),
                VK_API_VERSION_PATCH(device.api_versions.instance));

    if device.api_versions.instance < VulkanDevice.MINIMAL_REQUIRED_API_VERSION {
        assertMessage("Instance API version is less than minimal requied API version: %.%.%.%",
                      VK_API_VERSION_VARIANT(VulkanDevice.MINIMAL_REQUIRED_API_VERSION),
                      VK_API_VERSION_MAJOR(VulkanDevice.MINIMAL_REQUIRED_API_VERSION),
                      VK_API_VERSION_MINOR(VulkanDevice.MINIMAL_REQUIRED_API_VERSION),
                      VK_API_VERSION_PATCH(VulkanDevice.MINIMAL_REQUIRED_API_VERSION));
    }
}

loadInstanceExtensionsFunctions :: (device : *VulkanDevice, enabled_instance_extensions : *[..] string) {
    base_address := cast(*void) *device.instance_extensions.required;

    for * type_info(type_of(device.instance_extensions.required)).members {
        if it.type.type == .VOID {
            continue;
        }

        function := vkGetInstanceProcAddr(device.instance, cast(*s8) it.name.data);
        if function == null {
            assertMessage("Function \"%\" was not found, but \"%\" instance extension was enabled", it.name, it.notes[0]);
        }

        member_address   := cast(**void) (base_address + it.offset_in_bytes);
        <<member_address  = cast(*void) function;
    }

    base_address = cast(*void) *device.instance_extensions.optional;

    for *members_it : type_info(type_of(device.instance_extensions.optional)).members {
        if members_it.type.type == .VOID {
            continue;
        }

        memeber_extension_name := members_it.notes[0];
        function               := vkGetInstanceProcAddr(device.instance, cast(*s8) members_it.name.data);

        for <<enabled_instance_extensions {
            if String.equal(it, memeber_extension_name) {
                if function == null {
                    assertMessage("Function \"%\" was not found, but \"%\" instance extension was enabled",
                                  members_it.name, memeber_extension_name);
                }
                break;
            }
        }

        member_address   := cast(**void) (base_address + members_it.offset_in_bytes);
        <<member_address  = cast(*void) function;
    }
}

messengerCallback :: (
    messageSeverity : VkDebugUtilsMessageSeverityFlagsEXT,
    messageTypes    : VkDebugUtilsMessageTypeFlagsEXT,
    pCallbackData   : *VkDebugUtilsMessengerCallbackDataEXT,
    pUserData       : *void
) -> VkBool32 #c_call {

    message := to_string(cast(*u8) pCallbackData.pMessage);
    if message[message.count - 1] == #char "." {
        message.count -= 1;
    }

    push_context cast(*Context) pUserData {
        if messageSeverity & .VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT {
            errorMessage("[VULKAN]: %", message, print_sys_error = false);
        } else if messageSeverity & .VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT {
            warningMessage("[VULKAN]: %", message);
        } else if messageSeverity & .VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT {
            debugMessage("[VULKAN]: %", message);
        } else {
            infoMessage("[VULKAN]: %", message);
        }
    }

    return VK_FALSE;
}

initMessengerCallback :: (device : *VulkanDevice) {
    if device.instance_extensions.optional.vkCreateDebugUtilsMessengerEXT {
        create_info := VkDebugUtilsMessengerCreateInfoEXT.{
            sType           = .VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            pNext           = null,
            flags           = 0,
            messageSeverity = VkDebugUtilsMessageSeverityFlagsEXT.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT
//                              | .VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT
                            | .VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
            messageType     = VkDebugUtilsMessageTypeFlagsEXT.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT
                            | .VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT
                            | .VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT
                            | .VK_DEBUG_UTILS_MESSAGE_TYPE_DEVICE_ADDRESS_BINDING_BIT_EXT,
            pfnUserCallback = messengerCallback,
            pUserData       = *context,
        };

        #if DEBUG_BUILD {
            create_info.messageSeverity |= .VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT;
        }

        // @TODO: VkAllocationCallbacks
        result := device.instance_extensions.optional.vkCreateDebugUtilsMessengerEXT(device.instance,
                                                                                     *create_info,
                                                                                     null,
                                                                                     *device.messenger);
        assert(result == .VK_SUCCESS);
    }
}

// @TODO: Multiple GPU support: vkEnumeratePhysicalDeviceGroupsKHR (VK_KHR_device_group_creation)
findCompatiblePhysicalDevice :: (device : *VulkanDevice) {
    physical_device_count : u32;
    result := vkEnumeratePhysicalDevices(device.instance, *physical_device_count, null);
    assert(result == .VK_SUCCESS);

    physical_devices := pushToArena(*context.pet_engine_state.per_frame_arena, VkPhysicalDevice, physical_device_count);
    result = vkEnumeratePhysicalDevices(device.instance, *physical_device_count, physical_devices);
    assert(result == .VK_SUCCESS);

    physical_device_properties : VkPhysicalDeviceProperties = ---;

    COMPATIBLE_PHYSICAL_DEVICE_TYPES :: VkPhysicalDeviceType.[
        .VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU,
        .VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU
    ];

    for type : COMPATIBLE_PHYSICAL_DEVICE_TYPES {
        physical_device_it := physical_devices;
        for 0 .. physical_device_count - 1 {
            vkGetPhysicalDeviceProperties(<<physical_device_it, *physical_device_properties);

            // @TODO: for VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU:   Choose one with the biggest amount of VRAM.
            //        for VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU: Choose one with the biggest amount of SRAM.
            if physical_device_properties.deviceType == type {
                device.physical_device = <<physical_device_it;

                if type == {
                    case .VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU;   device.type = .DISCRETE;
                    case .VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU; device.type = .INTEGRATED;
                }

                break type;
            }

            physical_device_it += 1;
        }
    }

    if device.physical_device == VK_NULL_HANDLE {
        #assert COMPATIBLE_PHYSICAL_DEVICE_TYPES.count == 2;
        assertMessage("Vulkan back end supports only % types of GPUs: % and %. None of them were found",
                      COMPATIBLE_PHYSICAL_DEVICE_TYPES.count,
                      COMPATIBLE_PHYSICAL_DEVICE_TYPES[0],
                      COMPATIBLE_PHYSICAL_DEVICE_TYPES[1]);
    }

    if physical_device_properties.apiVersion < VK_API_VERSION_1_1 {
        assertMessage("Physical device API version is less than minimal requied API version: %.%.%.%",
                      VK_API_VERSION_VARIANT(VulkanDevice.MINIMAL_REQUIRED_API_VERSION),
                      VK_API_VERSION_MAJOR(VulkanDevice.MINIMAL_REQUIRED_API_VERSION),
                      VK_API_VERSION_MINOR(VulkanDevice.MINIMAL_REQUIRED_API_VERSION),
                      VK_API_VERSION_PATCH(VulkanDevice.MINIMAL_REQUIRED_API_VERSION));
    }

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
                VK_API_VERSION_VARIANT(physical_device_properties.apiVersion),
                VK_API_VERSION_MAJOR(physical_device_properties.apiVersion),
                VK_API_VERSION_MINOR(physical_device_properties.apiVersion),
                VK_API_VERSION_PATCH(physical_device_properties.apiVersion),
                Basic.formatInt(physical_device_properties.driverVersion, base = 16),
                vendorIdToString(physical_device_properties.vendorID),
                Basic.formatInt(physical_device_properties.vendorID, base = 16),
                Basic.formatInt(physical_device_properties.deviceID, base = 16),
                physical_device_properties.deviceType,
                s8_array_to_string(physical_device_properties.deviceName),
                new_line = false);

    if physical_device_properties.apiVersion >= VK_API_VERSION_1_2 {
        driver_properties := VkPhysicalDeviceDriverProperties.{
            sType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DRIVER_PROPERTIES,
            pNext = null,
        };

        properties2 := VkPhysicalDeviceProperties2.{
            sType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2,
            pNext = *driver_properties,
        };

        vkGetPhysicalDeviceProperties2(device.physical_device, *properties2);

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
    }
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

    queue_family_properties := pushToArena(*context.pet_engine_state.per_frame_arena, VkQueueFamilyProperties2, queue_family_properties_count);

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
    for * queue_it : device.queues {
        queue_type := cast(QueueTypes) it_index;

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

            if queue_it.family_index == 0xFFFF_FFFF && queue_type == .COPY {
                // According to vulkan spec, declaring transfer queue capability is optional.
                FLAGS :: VkQueueFlags.VK_QUEUE_GRAPHICS_BIT | .VK_QUEUE_COMPUTE_BIT;
                findQueueFamily(#code queue_family_flags & `FLAGS);
            }
        }

        assert(queue_it.family_index != 0xFFFF_FFFF, "% queue family was not found", queue_type);
    }

    graphics_queue := *device.queues[QueueTypes.GRAPHICS];
    compute_queue  := *device.queues[QueueTypes.COMPUTE];
    copy_queue     := *device.queues[QueueTypes.COPY];

    // Detect queue index in queue family
    {
        if compute_queue.family_index == graphics_queue.family_index {
            compute_queue.index_in_family = graphics_queue.index_in_family + 1;
        } else if copy_queue.family_index == graphics_queue.family_index {
            copy_queue.index_in_family = graphics_queue.index_in_family + 1;
        }

        if copy_queue.family_index == compute_queue.family_index {
            copy_queue.index_in_family = compute_queue.index_in_family + 1;
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
            Copy:
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
                    queue_family_properties[copy_queue.family_index].queueFamilyProperties.queueFlags,
                    copy_queue.family_index,
                    copy_queue.index_in_family,
                    new_line = false);
    }
}

scanVulkanDeviceForDeviceExtensions :: () -> (required : [] string, optional : [] string) {
    required_extensions : [..] string;
    required_extensions.allocator = Basic.temporary_allocator;

    for * type_info(type_of(VulkanDevice.device_extensions.required)).members {
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

    optional_extensions : [..] string;
    optional_extensions.allocator = Basic.temporary_allocator;

    for * type_info(type_of(VulkanDevice.device_extensions.optional)).members {
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

    return required_extensions, optional_extensions;
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
        result := vkEnumerateDeviceExtensionProperties(device.physical_device, null, *extensions_count, null);
        assert(result == .VK_SUCCESS);

        extensions := pushToArena(*context.pet_engine_state.per_frame_arena, VkExtensionProperties, extensions_count);
        result = vkEnumerateDeviceExtensionProperties(device.physical_device, null, *extensions_count, extensions);
        assert(result == .VK_SUCCESS);

        Basic.print_to_builder(*builder, "Available device extensions (%):\n", extensions_count);
        extensions_it := extensions;
        for 0 .. extensions_count - 1 {
            Basic.print_to_builder(*builder, "            %\n", to_string(cast(*u8) extensions_it.extensionName.data));
            extensions_it += 1;
        }

        infoMessage("%", Basic.builder_to_string(*builder), new_line = false);

        REQUIRED_EXTENSIONS, OPTIONAL_EXTENSIONS :: #run scanVulkanDeviceForDeviceExtensions();

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
            for 0 .. extensions_count - 1 {
                if String.equal(to_string(cast(*u8) extensions_it.extensionName.data), optional_extensions_it) {
                    Basic.array_add(enabled_device_extensions, optional_extensions_it);
                    break;
                }
                extensions_it += 1;
            }
        }

        Basic.print_to_builder(*builder, "Applying device extensions (%):\n", enabled_device_extensions.count);
        for <<enabled_device_extensions {
            Basic.array_add(*extensions_to_apply, cast(*s8) it.data);
            Basic.print_to_builder(*builder, "            %\n", it);
        }
        infoMessage("%", Basic.builder_to_string(*builder), new_line = false);
    }

    device_create_info := VkDeviceCreateInfo.{
        sType                   = .VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        pNext                   = null,
        flags                   = 0,
        queueCreateInfoCount    = queue_create_infos_count,
        pQueueCreateInfos       = queue_create_infos.data,
        enabledLayerCount       = 0,    // Deprecated and ignored.
        ppEnabledLayerNames     = null, // Deprecated and ignored.
        enabledExtensionCount   = cast(u32)  extensions_to_apply.count,
        ppEnabledExtensionNames = cast(**s8) extensions_to_apply.data,
        pEnabledFeatures        = null, // @TODO
    };

    // @TODO: VkAllocationCallbacks
    result := vkCreateDevice(device.physical_device, *device_create_info, null, *device.device);
    assert(result == .VK_SUCCESS && device.device != VK_NULL_HANDLE);
}

loadDeviceExtensionsFunctions :: (device : *VulkanDevice, enabled_device_extensions : *[..] string) {
    base_address := cast(*void) *device.device_extensions.required;

    for * type_info(type_of(device.device_extensions.required)).members {
        if it.type.type == .VOID {
            continue;
        }

        function := vkGetDeviceProcAddr(device.device, cast(*s8) it.name.data);
        if function == null {
            assertMessage("Function \"%\" was not found, but \"%\" device extension was enabled", it.name, it.notes[0]);
        }

        member_address   := cast(**void) (base_address + it.offset_in_bytes);
        <<member_address  = cast(*void) function;
    }

    base_address = cast(*void) *device.device_extensions.optional;

    for *members_it : type_info(type_of(device.device_extensions.optional)).members {
        if members_it.type.type == .VOID {
            continue;
        }

        memeber_extension_name := members_it.notes[0];
        function               := vkGetDeviceProcAddr(device.device, cast(*s8) members_it.name.data);

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

        setObjectName(device, .VK_OBJECT_TYPE_QUEUE, it.handle, "% queue", cast(QueueTypes) it_index);
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
        result := device.instance_extensions.required.vkCreateWin32SurfaceKHR(device.instance, *create_info, null, *device.surface);
        assert(result == .VK_SUCCESS);
    } else {
        notImplemented();
    }
}

createSwapchain :: (device : *VulkanDevice, window : *Window) {
    surface_capabilities : VkSurfaceCapabilitiesKHR = ---;
    result := device.instance_extensions.required.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device.physical_device,
                                                                                            device.surface,
                                                                                            *surface_capabilities);
    assert(result == .VK_SUCCESS);

    surface_formats_count : u32;
    result = device.instance_extensions.required.vkGetPhysicalDeviceSurfaceFormatsKHR(device.physical_device,
                                                                                      device.surface,
                                                                                      *surface_formats_count,
                                                                                      null);
    assert(result == .VK_SUCCESS);

    surface_formats := pushToArena(*context.pet_engine_state.per_frame_arena, VkSurfaceFormatKHR, surface_formats_count);
    result = device.instance_extensions.required.vkGetPhysicalDeviceSurfaceFormatsKHR(device.physical_device,
                                                                                      device.surface,
                                                                                      *surface_formats_count,
                                                                                      surface_formats);
    assert(result == .VK_SUCCESS);

    // @TODO: #Settings. Number of buffers in a swapchain
    num_images : u32 = 2;
    if num_images < surface_capabilities.minImageCount {
        warningMessage("Requested number of images in a swapchain is %, but surface supports at least % of them. % will be created",
                       num_images,
                       surface_capabilities.minImageCount,
                       surface_capabilities.minImageCount);
        num_images = surface_capabilities.minImageCount;
    } else if num_images > surface_capabilities.maxImageCount {
        warningMessage("Requested number of images in a swapchain is %, but surface supports maximum % of them. % will be created",
                       num_images,
                       surface_capabilities.maxImageCount,
                       surface_capabilities.maxImageCount);
        num_images = surface_capabilities.maxImageCount;
    }

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

    REQUESTED_USAGE_FLAGS :: VkImageUsageFlags.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | .VK_IMAGE_USAGE_SAMPLED_BIT;
    allowed_usage_flags   := REQUESTED_USAGE_FLAGS & surface_capabilities.supportedUsageFlags;

    if allowed_usage_flags != REQUESTED_USAGE_FLAGS {
        assertMessage("Requested surface image usage flags are %, but surface supports only % flags. % flags can not be used",
                      REQUESTED_USAGE_FLAGS,
                      surface_capabilities.supportedUsageFlags,
                      ~allowed_usage_flags & REQUESTED_USAGE_FLAGS);
    }

    queue_families_having_access_to_swapchain_images : [1] u32;
    queue_families_having_access_to_swapchain_images[0] = device.queues[QueueTypes.GRAPHICS].family_index;

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
        minImageCount         = num_images,
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
        oldSwapchain          = VK_NULL_HANDLE
    };

    // @TODO: VkAllocationCallbacks
    result = device.device_extensions.required.vkCreateSwapchainKHR(device.device, *create_info, null, *device.swapchain);
    assert(result == .VK_SUCCESS);
}

vendorIdToString :: inline (vendor_id : u32) -> string {
    info := type_info(VkVendorId);

    lowest_value, highest_value := Basic.enum_range_given_info(info);

    if lowest_value <= vendor_id && vendor_id <= highest_value {
        return info.names[vendor_id];
    }

    info = type_info(PCIVendorID);
    for info.values {
        if vendor_id == it {
            return info.names[it_index];
        }
    }

    return "Unknown";
}

s8_array_to_string :: inline (array : [] s8) -> string #no_context {
    str : string = ---;
    str.data  = cast(*u8) array.data;
    str.count = array.count;

    return str;
}
