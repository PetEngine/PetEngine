#scope_export

// Provided by VK_VERSION_1_0
VkQueue :: VK_HANDLE;

// Provided by VK_VERSION_1_0
VK_QUEUE_FAMILY_IGNORED : u32 : 0xFFFF_FFFF;

// Provided by VK_VERSION_1_1
VkDeviceQueueInfo2 :: struct {
    sType            : VkStructureType;
    pNext            : *void;
    flags            : VkDeviceQueueCreateFlags;
    queueFamilyIndex : u32;
    queueIndex       : u32;
}

// Provided by VK_VERSION_1_0
VkSubmitInfo :: struct {
    sType                : VkStructureType;
    pNext                : *void;
    waitSemaphoreCount   : u32;
    pWaitSemaphores      : *VkSemaphore;
    pWaitDstStageMask    : *VkPipelineStageFlags;
    commandBufferCount   : u32;
    pCommandBuffers      : *VkCommandBuffer;
    signalSemaphoreCount : u32;
    pSignalSemaphores    : *VkSemaphore;
}

// Provided by VK_VERSION_1_1
vkGetDeviceQueue2 :: (
    device     : VkDevice,
    pQueueInfo : *VkDeviceQueueInfo2,
    pQueue     : *VkQueue
) #foreign vulkan;

// Provided by VK_VERSION_1_0
vkQueueSubmit :: (
    queue       : VkQueue,
    submitCount : u32,
    pSubmits    : *VkSubmitInfo,
    fence       : VkFence
) -> VkResult #foreign vulkan;
