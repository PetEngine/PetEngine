#scope_export

// Provided by VK_VERSION_1_0
VkQueue :: VK_HANDLE;

// Provided by VK_VERSION_1_1
VkDeviceQueueInfo2 :: struct {
    sType            : VkStructureType;
    pNext            : *void;
    flags            : VkDeviceQueueCreateFlags;
    queueFamilyIndex : u32;
    queueIndex       : u32;
}

// Provided by VK_VERSION_1_0
vkGetDeviceQueue :: (
    device           : VkDevice,
    queueFamilyIndex : u32,
    queueIndex       : u32,
    pQueue           : *VkQueue
) #foreign vulkan;

// Provided by VK_VERSION_1_1
vkGetDeviceQueue2 :: (
    device     : VkDevice,
    pQueueInfo : *VkDeviceQueueInfo2,
    pQueue     : *VkQueue
) #foreign vulkan;
