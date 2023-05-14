#scope_export

// Provided by VK_VERSION_1_0
VkCommandPool :: VK_NON_DISPATCHABLE_HANDLE;

// Provided by VK_VERSION_1_0
VkCommandPoolCreateFlags :: enum_flags VkFlags {
    VK_COMMAND_POOL_CREATE_TRANSIENT_BIT            :: 0x00000001;
    VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT :: 0x00000002;
    // Provided by VK_VERSION_1_1
    VK_COMMAND_POOL_CREATE_PROTECTED_BIT            :: 0x00000004;
}

// Provided by VK_VERSION_1_0
VkCommandPoolResetFlags :: enum_flags VkFlags {
    VK_COMMAND_POOL_RESET_RELEASE_RESOURCES_BIT :: 0x00000001;
}

// Provided by VK_VERSION_1_0
VkCommandPoolCreateInfo :: struct {
    sType            : VkStructureType;
    pNext            : *void;
    flags            : VkCommandPoolCreateFlags;
    queueFamilyIndex : u32;
}

// Provided by VK_VERSION_1_0
vkCreateCommandPool :: (
    device       : VkDevice,
    pCreateInfo  : *VkCommandPoolCreateInfo,
    pAllocator   : *VkAllocationCallbacks,
    pCommandPool : *VkCommandPool
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkDestroyCommandPool :: (
    device      : VkDevice,
    commandPool : VkCommandPool,
    pAllocator  : *VkAllocationCallbacks
) #foreign vulkan;

// Provided by VK_VERSION_1_0
vkResetCommandPool :: (
    device      : VkDevice,
    commandPool : VkCommandPool,
    flags       : VkCommandPoolResetFlags
) -> VkResult #foreign vulkan;
