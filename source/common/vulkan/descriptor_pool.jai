#scope_export

// Provided by VK_VERSION_1_0
VkDescriptorPool :: *VkDescriptorPool_T; VkDescriptorPool_T :: struct {}

// Provided by VK_VERSION_1_0
VkDescriptorSet :: *VkDescriptorSet_T; VkDescriptorSet_T :: struct {}

// Provided by VK_VERSION_1_0
VkDescriptorPoolCreateFlags :: enum_flags VkFlags #specified {
    VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT           :: 0x00000001;
    // Provided by VK_VERSION_1_2
    VK_DESCRIPTOR_POOL_CREATE_UPDATE_AFTER_BIND_BIT             :: 0x00000002;
    // Provided by VK_EXT_mutable_descriptor_type
    VK_DESCRIPTOR_POOL_CREATE_HOST_ONLY_BIT_EXT                 :: 0x00000004;
    // Provided by VK_NV_descriptor_pool_overallocation
    VK_DESCRIPTOR_POOL_CREATE_ALLOW_OVERALLOCATION_SETS_BIT_NV  :: 0x00000008;
    // Provided by VK_NV_descriptor_pool_overallocation
    VK_DESCRIPTOR_POOL_CREATE_ALLOW_OVERALLOCATION_POOLS_BIT_NV :: 0x00000010;
    // Provided by VK_EXT_descriptor_indexing
    VK_DESCRIPTOR_POOL_CREATE_UPDATE_AFTER_BIND_BIT_EXT         :: VK_DESCRIPTOR_POOL_CREATE_UPDATE_AFTER_BIND_BIT;
    // Provided by VK_VALVE_mutable_descriptor_type
    VK_DESCRIPTOR_POOL_CREATE_HOST_ONLY_BIT_VALVE               :: VK_DESCRIPTOR_POOL_CREATE_HOST_ONLY_BIT_EXT;
}

// Provided by VK_VERSION_1_0
VkDescriptorPoolSize :: struct {
    type            : VkDescriptorType;
    descriptorCount : u32;
}

// Provided by VK_VERSION_1_0
VkDescriptorPoolCreateInfo :: struct {
    sType         : VkStructureType = .VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
    pNext         : *void;
    flags         : VkDescriptorPoolCreateFlags;
    maxSets       : u32;
    poolSizeCount : u32;
    pPoolSizes    : *VkDescriptorPoolSize;
}

// Provided by VK_VERSION_1_0
VkDescriptorSetAllocateInfo :: struct {
    sType              : VkStructureType = .VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
    pNext              : *void;
    descriptorPool     : VkDescriptorPool;
    descriptorSetCount : u32;
    pSetLayouts        : *VkDescriptorSetLayout;
}

// Provided by VK_VERSION_1_0
VkDescriptorBufferInfo :: struct {
    buffer : VkBuffer;
    offset : VkDeviceSize;
    range  : VkDeviceSize;
}

// Provided by VK_VERSION_1_0
VkWriteDescriptorSet :: struct {
    sType            : VkStructureType = .VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    pNext            : *void;
    dstSet           : VkDescriptorSet;
    dstBinding       : u32;
    dstArrayElement  : u32;
    descriptorCount  : u32;
    descriptorType   : VkDescriptorType;
    pImageInfo       : *VkDescriptorImageInfo;
    pBufferInfo      : *VkDescriptorBufferInfo;
    pTexelBufferView : *VkBufferView;
}

// Provided by VK_VERSION_1_0
VkCopyDescriptorSet :: struct {
    sType           : VkStructureType = .VK_STRUCTURE_TYPE_COPY_DESCRIPTOR_SET;
    pNext           : *void;
    srcSet          : VkDescriptorSet;
    srcBinding      : u32;
    srcArrayElement : u32;
    dstSet          : VkDescriptorSet;
    dstBinding      : u32;
    dstArrayElement : u32;
    descriptorCount : u32;
}

// Provided by VK_VERSION_1_0
vkCreateDescriptorPool :: (
    device          : VkDevice,
    pCreateInfo     : *VkDescriptorPoolCreateInfo,
    pAllocator      : *VkAllocationCallbacks,
    pDescriptorPool : *VkDescriptorPool
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkDestroyDescriptorPool :: (
    device         : VkDevice,
    descriptorPool : VkDescriptorPool,
    pAllocator     : *VkAllocationCallbacks
) #foreign vulkan;

// Provided by VK_VERSION_1_0
vkAllocateDescriptorSets :: (
    device          : VkDevice,
    pAllocateInfo   : *VkDescriptorSetAllocateInfo,
    pDescriptorSets : *VkDescriptorSet
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkUpdateDescriptorSets :: (
    device               : VkDevice,
    descriptorWriteCount : u32,
    pDescriptorWrites    : *VkWriteDescriptorSet,
    descriptorCopyCount  : u32,
    pDescriptorCopies    : *VkCopyDescriptorSet
) #foreign vulkan;

// Provided by VK_VERSION_1_0
vkCmdBindDescriptorSets :: (
    commandBuffer      : VkCommandBuffer,
    pipelineBindPoint  : VkPipelineBindPoint,
    layout             : VkPipelineLayout,
    firstSet           : u32,
    descriptorSetCount : u32,
    pDescriptorSets    : *VkDescriptorSet,
    dynamicOffsetCount : u32,
    pDynamicOffsets    : *u32
) #foreign vulkan;
