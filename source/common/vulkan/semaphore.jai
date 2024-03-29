#scope_export

// Provided by VK_VERSION_1_0
VkSemaphore :: *VkSemaphore_T; VkSemaphore_T :: struct {}

// Provided by VK_VERSION_1_2
VkSemaphoreWaitFlags :: enum VkEnum #specified {
    VK_SEMAPHORE_WAIT_ANY_BIT :: 0x00000001;
}

// Provided by VK_VERSION_1_2
VkSemaphoreType :: enum VkEnum #specified {
    VK_SEMAPHORE_TYPE_BINARY       :: 0;
    VK_SEMAPHORE_TYPE_TIMELINE     :: 1;
    // Provided by VK_KHR_timeline_semaphore
    VK_SEMAPHORE_TYPE_BINARY_KHR   :: VK_SEMAPHORE_TYPE_BINARY;
    // Provided by VK_KHR_timeline_semaphore
    VK_SEMAPHORE_TYPE_TIMELINE_KHR :: VK_SEMAPHORE_TYPE_TIMELINE;
}

// Provided by VK_VERSION_1_0
VkSemaphoreCreateFlags :: enum_flags VkFlags #specified {
}

// Provided by VK_VERSION_1_0
VkSemaphoreCreateInfo :: struct {
    sType : VkStructureType = .VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;
    pNext : *void;
    flags : VkSemaphoreCreateFlags;
}

// Provided by VK_VERSION_1_2
VkSemaphoreTypeCreateInfo :: struct {
    sType         : VkStructureType = .VK_STRUCTURE_TYPE_SEMAPHORE_TYPE_CREATE_INFO;
    pNext         : *void;
    semaphoreType : VkSemaphoreType;
    initialValue  : u64;
}

// Provided by VK_VERSION_1_2
VkSemaphoreWaitInfo :: struct {
    sType          : VkStructureType = .VK_STRUCTURE_TYPE_SEMAPHORE_WAIT_INFO;
    pNext          : *void;
    flags          : VkSemaphoreWaitFlags;
    semaphoreCount : u32;
    pSemaphores    : *VkSemaphore;
    pValues        : *u64;
}

// Provided by VK_VERSION_1_0
vkCreateSemaphore :: (
    device      : VkDevice,
    pCreateInfo : *VkSemaphoreCreateInfo,
    pAllocator  : *VkAllocationCallbacks,
    pSemaphore  : *VkSemaphore
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkDestroySemaphore :: (
    device     : VkDevice,
    semaphore  : VkSemaphore,
    pAllocator : *VkAllocationCallbacks
) #foreign vulkan;

// Provided by VK_VERSION_1_2
vkWaitSemaphores :: (
    device    : VkDevice,
    pWaitInfo : *VkSemaphoreWaitInfo,
    timeout   : u64
) -> VkResult #foreign vulkan;
