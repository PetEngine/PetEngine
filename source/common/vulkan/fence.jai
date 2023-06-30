#scope_export

// Provided by VK_VERSION_1_0
VkFence :: VK_NON_DISPATCHABLE_HANDLE;

// Provided by VK_VERSION_1_0
VkFenceCreateFlags :: enum_flags VkFlags #specified {
    VK_FENCE_CREATE_SIGNALED_BIT :: 0x00000001;
}

// Provided by VK_VERSION_1_0
VkFenceCreateInfo :: struct {
    sType : VkStructureType;
    pNext : *void;
    flags : VkFenceCreateFlags;
}

// Provided by VK_VERSION_1_0
vkCreateFence :: (
    device      : VkDevice,
    pCreateInfo : *VkFenceCreateInfo,
    pAllocator  : *VkAllocationCallbacks,
    pFence      : *VkFence
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkDestroyFence :: (
    device     : VkDevice,
    fence      : VkFence,
    pAllocator : *VkAllocationCallbacks
) #foreign vulkan;

// Provided by VK_VERSION_1_0
vkGetFenceStatus :: (
    device : VkDevice,
    fence  : VkFence
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkResetFences :: (
    device     : VkDevice,
    fenceCount : u32,
    pFences    : *VkFence
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkWaitForFences :: (
    device     : VkDevice,
    fenceCount : u32,
    pFences    : *VkFence,
    waitAll    : VkBool32,
    timeout    : u64
) -> VkResult #foreign vulkan;
