#scope_export

// Provided by VK_VERSION_1_0
VkDevice :: *VkDevice_T; VkDevice_T :: struct {}

// Provided by VK_VERSION_1_0
VkSharingMode :: enum VkEnum #specified {
    VK_SHARING_MODE_EXCLUSIVE  :: 0;
    VK_SHARING_MODE_CONCURRENT :: 1;
}

// Provided by VK_VERSION_1_0
VkDeviceCreateFlags :: enum_flags VkFlags #specified {
}

// Provided by VK_VERSION_1_1
VkDeviceQueueCreateFlags :: enum_flags VkFlags #specified {
    // Provided by VK_VERSION_1_1
    VK_DEVICE_QUEUE_CREATE_PROTECTED_BIT :: 0x00000001;
}

// Provided by VK_VERSION_1_0
VkDeviceQueueCreateInfo :: struct {
    sType            : VkStructureType = .VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    pNext            : *void;
    flags            : VkDeviceQueueCreateFlags;
    queueFamilyIndex : u32;
    queueCount       : u32;
    pQueuePriorities : *f32;
}

// Provided by VK_VERSION_1_0
VkDeviceCreateInfo :: struct {
    sType                   : VkStructureType = .VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    pNext                   : *void;
    flags                   : VkDeviceCreateFlags;
    queueCreateInfoCount    : u32;
    pQueueCreateInfos       : *VkDeviceQueueCreateInfo;
    enabledLayerCount       : u32;
    ppEnabledLayerNames     : **u8;
    enabledExtensionCount   : u32;
    ppEnabledExtensionNames : **u8;
    pEnabledFeatures        : *VkPhysicalDeviceFeatures;
}

// Provided by VK_VERSION_1_0
vkCreateDevice :: (
    physicalDevice : VkPhysicalDevice,
    pCreateInfo    : *VkDeviceCreateInfo,
    pAllocator     : *VkAllocationCallbacks,
    pDevice        : *VkDevice
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkDestroyDevice :: (
    device     : VkDevice,
    pAllocator : *VkAllocationCallbacks
) #foreign vulkan;

// Provided by VK_VERSION_1_0
vkEnumerateDeviceLayerProperties :: (
    physicalDevice : VkPhysicalDevice,
    pPropertyCount : *u32,
    pProperties    : *VkLayerProperties
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkEnumerateDeviceExtensionProperties :: (
    physicalDevice : VkPhysicalDevice,
    pLayerName     : *u8,
    pPropertyCount : *u32,
    pProperties    : *VkExtensionProperties
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkGetDeviceProcAddr :: (
    device : VkDevice,
    pName  : *u8
) -> PFN_vkVoidFunction #foreign vulkan;

// Provided by VK_VERSION_1_0
vkDeviceWaitIdle :: (
    device : VkDevice
) -> VkResult #foreign vulkan;

//
// Provided by VK_KHR_swapchain
//

VkSwapchainKHR :: *VkSwapchainKHR_T; VkSwapchainKHR_T :: struct {}

VkSwapchainCreateFlagsKHR :: enum_flags VkFlags #specified {
    // Provided by VK_VERSION_1_1 with VK_KHR_swapchain, VK_KHR_device_group with VK_KHR_swapchain
    VK_SWAPCHAIN_CREATE_SPLIT_INSTANCE_BIND_REGIONS_BIT_KHR :: 0x00000001;
    // Provided by VK_VERSION_1_1 with VK_KHR_swapchain
    VK_SWAPCHAIN_CREATE_PROTECTED_BIT_KHR                   :: 0x00000002;
    // Provided by VK_KHR_swapchain_mutable_format
    VK_SWAPCHAIN_CREATE_MUTABLE_FORMAT_BIT_KHR              :: 0x00000004;
    // Provided by VK_EXT_swapchain_maintenance1
    VK_SWAPCHAIN_CREATE_DEFERRED_MEMORY_ALLOCATION_BIT_EXT  :: 0x00000008;
}

VkSwapchainCreateInfoKHR :: struct {
    sType                 : VkStructureType = .VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
    pNext                 : *void;
    flags                 : VkSwapchainCreateFlagsKHR;
    surface               : VkSurfaceKHR;
    minImageCount         : u32;
    imageFormat           : VkFormat;
    imageColorSpace       : VkColorSpaceKHR;
    imageExtent           : VkExtent2D;
    imageArrayLayers      : u32;
    imageUsage            : VkImageUsageFlags;
    imageSharingMode      : VkSharingMode;
    queueFamilyIndexCount : u32;
    pQueueFamilyIndices   : *u32;
    preTransform          : VkSurfaceTransformFlagsKHR;
    compositeAlpha        : VkCompositeAlphaFlagsKHR;
    presentMode           : VkPresentModeKHR;
    clipped               : VkBool32;
    oldSwapchain          : VkSwapchainKHR;
}

VkAcquireNextImageInfoKHR :: struct {
    sType       : VkStructureType = .VK_STRUCTURE_TYPE_ACQUIRE_NEXT_IMAGE_INFO_KHR;
    pNext       : *void;
    swapchain   : VkSwapchainKHR;
    timeout     : u64;
    semaphore   : VkSemaphore;
    fence       : VkFence;
    deviceMask  : u32;
}

VkPresentInfoKHR :: struct {
    sType              : VkStructureType = .VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
    pNext              : *void;
    waitSemaphoreCount : u32;
    pWaitSemaphores    : *VkSemaphore;
    swapchainCount     : u32;
    pSwapchains        : *VkSwapchainKHR;
    pImageIndices      : *u32;
    pResults           : *VkResult;
}

PFN_vkCreateSwapchainKHR :: #type (
    device      : VkDevice,
    pCreateInfo : *VkSwapchainCreateInfoKHR,
    pAllocator  : *VkAllocationCallbacks,
    pSwapchain  : *VkSwapchainKHR
) -> VkResult #c_call;

PFN_vkDestroySwapchainKHR :: #type (
    device     : VkDevice,
    swapchain  : VkSwapchainKHR,
    pAllocator : *VkAllocationCallbacks
) #c_call;

PFN_vkGetSwapchainImagesKHR :: #type (
    device               : VkDevice,
    swapchain            : VkSwapchainKHR,
    pSwapchainImageCount : *u32,
    pSwapchainImages     : *VkImage
) #c_call;

PFN_vkAcquireNextImage2KHR :: #type (
    device       : VkDevice,
    pAcquireInfo : *VkAcquireNextImageInfoKHR,
    pImageIndex  : *u32
) -> VkResult #c_call;

PFN_vkQueuePresentKHR :: #type (
    queue        : VkQueue,
    pPresentInfo : *VkPresentInfoKHR
) -> VkResult #c_call;