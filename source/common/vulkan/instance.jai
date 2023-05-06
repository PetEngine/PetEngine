#scope_export

// Provided by VK_VERSION_1_0
VkInstance :: VK_HANDLE;

// Provided by VK_VERSION_1_0
VK_MAX_EXTENSION_NAME_SIZE : u32 : 256;

// Provided by VK_VERSION_1_0
VK_MAX_DESCRIPTION_SIZE : u32 : 256;

// Provided by VK_VERSION_1_0
VkInternalAllocationType :: enum VkEnum {
    VK_INTERNAL_ALLOCATION_TYPE_EXECUTABLE :: 0;
}

// Provided by VK_VERSION_1_0
VkSystemAllocationScope :: enum VkEnum {
    VK_SYSTEM_ALLOCATION_SCOPE_COMMAND  :: 0;
    VK_SYSTEM_ALLOCATION_SCOPE_OBJECT   :: 1;
    VK_SYSTEM_ALLOCATION_SCOPE_CACHE    :: 2;
    VK_SYSTEM_ALLOCATION_SCOPE_DEVICE   :: 3;
    VK_SYSTEM_ALLOCATION_SCOPE_INSTANCE :: 4;
}

// Provided by VK_VERSION_1_0
VkInstanceCreateFlags :: enum_flags VkFlags {
    // Provided by VK_KHR_portability_enumeration
    VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR :: 0x00000001;
}

// Provided by VK_VERSION_1_0
VkApplicationInfo :: struct {
    sType              : VkStructureType;
    pNext              : *void;
    pApplicationName   : *s8;
    applicationVersion : u32;
    pEngineName        : *s8;
    engineVersion      : u32;
    apiVersion         : u32;
}

// Provided by VK_VERSION_1_0
VkInstanceCreateInfo :: struct {
    sType                   : VkStructureType;
    pNext                   : *void;
    flags                   : VkInstanceCreateFlags;
    pApplicationInfo        : *VkApplicationInfo;
    enabledLayerCount       : u32;
    ppEnabledLayerNames     : **s8;
    enabledExtensionCount   : u32;
    ppEnabledExtensionNames : **s8;
}

// Provided by VK_VERSION_1_0
VkAllocationCallbacks :: struct {
    pUserData             : *void;
    pfnAllocation         : PFN_vkAllocationFunction;
    pfnReallocation       : PFN_vkReallocationFunction;
    pfnFree               : PFN_vkFreeFunction;
    pfnInternalAllocation : PFN_vkInternalAllocationNotification;
    pfnInternalFree       : PFN_vkInternalFreeNotification;
}

// Provided by VK_VERSION_1_0
VkLayerProperties :: struct {
    layerName             : [VK_MAX_EXTENSION_NAME_SIZE] s8;
    specVersion           : u32;
    implementationVersion : u32;
    description           : [VK_MAX_DESCRIPTION_SIZE] s8;
}

// Provided by VK_VERSION_1_0
VkExtensionProperties :: struct {
    extensionName : [VK_MAX_EXTENSION_NAME_SIZE] s8;
    specVersion   : u32;
}

// Provided by VK_VERSION_1_0
PFN_vkAllocationFunction :: #type (
    pUserData       : *void,
    size            : size_t,
    alignment       : size_t,
    allocationScope : VkSystemAllocationScope
) -> *void #c_call;

// Provided by VK_VERSION_1_0
PFN_vkReallocationFunction :: #type (
    pUserData       : *void,
    pOriginal       : *void,
    size            : size_t,
    alignment       : size_t,
    allocationScope : VkSystemAllocationScope
) -> *void #c_call;

// Provided by VK_VERSION_1_0
PFN_vkFreeFunction :: #type (
    pUserData : *void,
    pMemory   : *void
) #c_call;

// Provided by VK_VERSION_1_0
PFN_vkInternalAllocationNotification :: #type (
    pUserData       : *void,
    size            : size_t,
    allocationType  : VkInternalAllocationType,
    allocationScope : VkSystemAllocationScope
) #c_call;

// Provided by VK_VERSION_1_0
PFN_vkInternalFreeNotification :: #type (
    pUserData       : *void,
    size            : size_t,
    allocationType  : VkInternalAllocationType,
    allocationScope : VkSystemAllocationScope
) #c_call;

// Provided by VK_VERSION_1_0
PFN_vkVoidFunction :: #type () #c_call;

// Provided by VK_VERSION_1_0
vkCreateInstance :: (
    pCreateInfo : *VkInstanceCreateInfo,
    pAllocator  : *VkAllocationCallbacks,
    pInstance   : *VkInstance
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkDestroyInstance :: (
    instance   : VkInstance,
    pAllocator : *VkAllocationCallbacks
) #foreign vulkan;

// Provided by VK_VERSION_1_1
vkEnumerateInstanceVersion :: (
    pApiVersion : *u32
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkEnumerateInstanceLayerProperties :: (
    pPropertyCount : *u32,
    pProperties    : *VkLayerProperties
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkEnumerateInstanceExtensionProperties :: (
    pLayerName     : *s8,
    pPropertyCount : *u32,
    pProperties    : *VkExtensionProperties
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkGetInstanceProcAddr :: (
    instance : VkInstance,
    pName    : *s8
) -> PFN_vkVoidFunction #foreign vulkan;

//
// VK_EXT_debug_utils
//

VkDebugUtilsMessengerEXT :: VK_NON_DISPATCHABLE_HANDLE;

VkDebugUtilsMessageSeverityFlagsEXT :: enum_flags VkFlags {
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT :: 0x00000001;
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT    :: 0x00000010;
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT :: 0x00000100;
    VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT   :: 0x00001000;
}

VkDebugUtilsMessageTypeFlagsEXT :: enum_flags VkFlags {
    VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT                :: 0x00000001;
    VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT             :: 0x00000002;
    VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT            :: 0x00000004;
    // Provided by VK_EXT_device_address_binding_report
    VK_DEBUG_UTILS_MESSAGE_TYPE_DEVICE_ADDRESS_BINDING_BIT_EXT :: 0x00000008;
}

VkDebugUtilsMessengerCallbackDataFlagsEXT :: enum_flags VkFlags {
}

VkDebugUtilsMessengerCreateFlagsEXT :: enum_flags VkFlags {
}

VkDebugUtilsLabelEXT :: struct {
    sType      : VkStructureType;
    pNext      : *void;
    pLabelName : *s8;
    color      : [4] f32;
}

VkDebugUtilsObjectNameInfoEXT :: struct {
    sType        : VkStructureType;
    pNext        : *void;
    objectType   : VkObjectType;
    objectHandle : u64;
    pObjectName  : *s8;
}

VkDebugUtilsMessengerCallbackDataEXT :: struct {
    sType            : VkStructureType;
    pNext            : *void;
    flags            : VkDebugUtilsMessengerCallbackDataFlagsEXT;
    pMessageIdName   : *s8;
    messageIdNumber  : s32;
    pMessage         : *s8;
    queueLabelCount  : u32;
    pQueueLabels     : *VkDebugUtilsLabelEXT;
    cmdBufLabelCount : u32;
    pCmdBufLabels    : *VkDebugUtilsLabelEXT;
    objectCount      : u32;
    pObjects         : *VkDebugUtilsObjectNameInfoEXT;
}

VkDebugUtilsMessengerCreateInfoEXT :: struct {
    sType           : VkStructureType;
    pNext           : *void;
    flags           : VkDebugUtilsMessengerCreateFlagsEXT;
    messageSeverity : VkDebugUtilsMessageSeverityFlagsEXT;
    messageType     : VkDebugUtilsMessageTypeFlagsEXT;
    pfnUserCallback : PFN_vkDebugUtilsMessengerCallbackEXT;
    pUserData       : *void;
}

PFN_vkDebugUtilsMessengerCallbackEXT :: #type (
    messageSeverity : VkDebugUtilsMessageSeverityFlagsEXT,
    messageTypes    : VkDebugUtilsMessageTypeFlagsEXT,
    pCallbackData   : *VkDebugUtilsMessengerCallbackDataEXT,
    pUserData       : *void
) -> VkBool32 #c_call;

PFN_vkSetDebugUtilsObjectNameEXT :: #type (
    device    : VkDevice,
    pNameInfo : *VkDebugUtilsObjectNameInfoEXT
) -> VkResult #c_call;

PFN_vkQueueBeginDebugUtilsLabelEXT :: #type (
    queue      : VkQueue,
    pLabelInfo : *VkDebugUtilsLabelEXT
) #c_call;

PFN_vkQueueEndDebugUtilsLabelEXT :: #type (
    queue : VkQueue
) #c_call;

PFN_vkCmdBeginDebugUtilsLabelEXT :: #type (
    commandBuffer : VkCommandBuffer,
    pLabelInfo    : *VkDebugUtilsLabelEXT
) #c_call;

PFN_vkCmdEndDebugUtilsLabelEXT :: #type (
    commandBuffer : VkCommandBuffer
) #c_call;

PFN_vkCreateDebugUtilsMessengerEXT :: #type (
    instance    : VkInstance,
    pCreateInfo : *VkDebugUtilsMessengerCreateInfoEXT,
    pAllocator  : *VkAllocationCallbacks,
    pMessenger  : *VkDebugUtilsMessengerEXT
) -> VkResult #c_call;

PFN_vkDestroyDebugUtilsMessengerEXT :: #type (
    instance   : VkInstance,
    messenger  : VkDebugUtilsMessengerEXT,
    pAllocator : *VkAllocationCallbacks
) #c_call;

//
// VK_KHR_surface
//

VkSurfaceKHR :: VK_NON_DISPATCHABLE_HANDLE;

VkPresentModeKHR :: enum VkEnum {
    VK_PRESENT_MODE_IMMEDIATE_KHR                 :: 0;
    VK_PRESENT_MODE_MAILBOX_KHR                   :: 1;
    VK_PRESENT_MODE_FIFO_KHR                      :: 2;
    VK_PRESENT_MODE_FIFO_RELAXED_KHR              :: 3;
    // Provided by VK_KHR_shared_presentable_image
    VK_PRESENT_MODE_SHARED_DEMAND_REFRESH_KHR     :: 1000111000;
    // Provided by VK_KHR_shared_presentable_image
    VK_PRESENT_MODE_SHARED_CONTINUOUS_REFRESH_KHR :: 1000111001;
}

VkColorSpaceKHR :: enum VkEnum {
    VK_COLOR_SPACE_SRGB_NONLINEAR_KHR          :: 0;
    // Provided by VK_EXT_swapchain_colorspace
    VK_COLOR_SPACE_DISPLAY_P3_NONLINEAR_EXT    :: 1000104001;
    // Provided by VK_EXT_swapchain_colorspace
    VK_COLOR_SPACE_EXTENDED_SRGB_LINEAR_EXT    :: 1000104002;
    // Provided by VK_EXT_swapchain_colorspace
    VK_COLOR_SPACE_DISPLAY_P3_LINEAR_EXT       :: 1000104003;
    // Provided by VK_EXT_swapchain_colorspace
    VK_COLOR_SPACE_DCI_P3_NONLINEAR_EXT        :: 1000104004;
    // Provided by VK_EXT_swapchain_colorspace
    VK_COLOR_SPACE_BT709_LINEAR_EXT            :: 1000104005;
    // Provided by VK_EXT_swapchain_colorspace
    VK_COLOR_SPACE_BT709_NONLINEAR_EXT         :: 1000104006;
    // Provided by VK_EXT_swapchain_colorspace
    VK_COLOR_SPACE_BT2020_LINEAR_EXT           :: 1000104007;
    // Provided by VK_EXT_swapchain_colorspace
    VK_COLOR_SPACE_HDR10_ST2084_EXT            :: 1000104008;
    // Provided by VK_EXT_swapchain_colorspace
    VK_COLOR_SPACE_DOLBYVISION_EXT             :: 1000104009;
    // Provided by VK_EXT_swapchain_colorspace
    VK_COLOR_SPACE_HDR10_HLG_EXT               :: 1000104010;
    // Provided by VK_EXT_swapchain_colorspace
    VK_COLOR_SPACE_ADOBERGB_LINEAR_EXT         :: 1000104011;
    // Provided by VK_EXT_swapchain_colorspace
    VK_COLOR_SPACE_ADOBERGB_NONLINEAR_EXT      :: 1000104012;
    // Provided by VK_EXT_swapchain_colorspace
    VK_COLOR_SPACE_PASS_THROUGH_EXT            :: 1000104013;
    // Provided by VK_EXT_swapchain_colorspace
    VK_COLOR_SPACE_EXTENDED_SRGB_NONLINEAR_EXT :: 1000104014;
    // Provided by VK_AMD_display_native_hdr
    VK_COLOR_SPACE_DISPLAY_NATIVE_AMD          :: 1000213000;
    VK_COLORSPACE_SRGB_NONLINEAR_KHR           :: VK_COLOR_SPACE_SRGB_NONLINEAR_KHR;
    // Provided by VK_EXT_swapchain_colorspace
    VK_COLOR_SPACE_DCI_P3_LINEAR_EXT           :: VK_COLOR_SPACE_DISPLAY_P3_LINEAR_EXT;
}

VkCompositeAlphaFlagsKHR :: enum_flags VkFlags {
    VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR          :: 0x00000001;
    VK_COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR  :: 0x00000002;
    VK_COMPOSITE_ALPHA_POST_MULTIPLIED_BIT_KHR :: 0x00000004;
    VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR         :: 0x00000008;
}

VkSurfaceTransformFlagsKHR :: enum_flags VkFlags {
    VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR                     :: 0x00000001;
    VK_SURFACE_TRANSFORM_ROTATE_90_BIT_KHR                    :: 0x00000002;
    VK_SURFACE_TRANSFORM_ROTATE_180_BIT_KHR                   :: 0x00000004;
    VK_SURFACE_TRANSFORM_ROTATE_270_BIT_KHR                   :: 0x00000008;
    VK_SURFACE_TRANSFORM_HORIZONTAL_MIRROR_BIT_KHR            :: 0x00000010;
    VK_SURFACE_TRANSFORM_HORIZONTAL_MIRROR_ROTATE_90_BIT_KHR  :: 0x00000020;
    VK_SURFACE_TRANSFORM_HORIZONTAL_MIRROR_ROTATE_180_BIT_KHR :: 0x00000040;
    VK_SURFACE_TRANSFORM_HORIZONTAL_MIRROR_ROTATE_270_BIT_KHR :: 0x00000080;
    VK_SURFACE_TRANSFORM_INHERIT_BIT_KHR                      :: 0x00000100;
}

PFN_vkDestroySurfaceKHR :: #type (
    instance   : VkInstance,
    surface    : VkSurfaceKHR,
    pAllocator : *VkAllocationCallbacks
);

//
// VK_KHR_win32_surface
//

#if OS == .WINDOWS {

VkWin32SurfaceCreateFlagsKHR :: enum_flags VkFlags {
};

VkWin32SurfaceCreateInfoKHR :: struct {
    sType     : VkStructureType;
    pNext     : *void;
    flags     : VkWin32SurfaceCreateFlagsKHR;
    hinstance : HINSTANCE;
    hwnd      : HWND;
};

PFN_vkCreateWin32SurfaceKHR :: #type (
    instance    : VkInstance,
    pCreateInfo : *VkWin32SurfaceCreateInfoKHR,
    pAllocator  : *VkAllocationCallbacks,
    pSurface    : *VkSurfaceKHR
) -> VkResult #c_call;

}
