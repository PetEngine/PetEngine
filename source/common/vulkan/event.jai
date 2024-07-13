#scope_export

// Provided by VK_VERSION_1_0
VkEvent :: *VkEvent_T; VkEvent_T :: struct {}

// Provided by VK_VERSION_1_0
VkEventCreateFlags :: enum VkEnum #specified {
    // Provided by VK_VERSION_1_3
    VK_EVENT_CREATE_DEVICE_ONLY_BIT     :: 0x00000001;
    // Provided by VK_KHR_synchronization2
    VK_EVENT_CREATE_DEVICE_ONLY_BIT_KHR :: VK_EVENT_CREATE_DEVICE_ONLY_BIT;
}

// Provided by VK_VERSION_1_0
VkEventCreateInfo :: struct {
    sType : VkStructureType = .VK_STRUCTURE_TYPE_EVENT_CREATE_INFO;
    pNext : *void;
    flags : VkEventCreateFlags;
}

// Provided by VK_VERSION_1_0
vkCreateEvent :: (
    device      : VkDevice,
    pCreateInfo : *VkEventCreateInfo,
    pAllocator  : *VkAllocationCallbacks,
    pEvent      : *VkEvent
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkDestroyEvent :: (
    device     : VkDevice,
    event      : VkEvent,
    pAllocator : *VkAllocationCallbacks
) #foreign vulkan;

// Provided by VK_VERSION_1_0
vkGetEventStatus :: (
    device : VkDevice,
    event  : VkEvent
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkCmdSetEvent :: (
    commandBuffer : VkCommandBuffer,
    event         : VkEvent,
    stageMask     : VkPipelineStageFlags
) #foreign vulkan;
