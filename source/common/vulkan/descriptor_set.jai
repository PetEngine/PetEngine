#scope_export

// Provided by VK_VERSION_1_0
VkDescriptorSet :: *VkDescriptorSet_T; VkDescriptorSet_T :: struct {}

// Provided by VK_VERSION_1_0
VkDescriptorType :: enum VkEnum #specified {
    VK_DESCRIPTOR_TYPE_SAMPLER                    :: 0;
    VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER     :: 1;
    VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE              :: 2;
    VK_DESCRIPTOR_TYPE_STORAGE_IMAGE              :: 3;
    VK_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER       :: 4;
    VK_DESCRIPTOR_TYPE_STORAGE_TEXEL_BUFFER       :: 5;
    VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER             :: 6;
    VK_DESCRIPTOR_TYPE_STORAGE_BUFFER             :: 7;
    VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC     :: 8;
    VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC     :: 9;
    VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT           :: 10;
    // Provided by VK_VERSION_1_3
    VK_DESCRIPTOR_TYPE_INLINE_UNIFORM_BLOCK       :: 1000138000;
    // Provided by VK_KHR_acceleration_structure
    VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR :: 1000150000;
    // Provided by VK_NV_ray_tracing
    VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_NV  :: 1000165000;
    // Provided by VK_QCOM_image_processing
    VK_DESCRIPTOR_TYPE_SAMPLE_WEIGHT_IMAGE_QCOM   :: 1000440000;
    // Provided by VK_QCOM_image_processing
    VK_DESCRIPTOR_TYPE_BLOCK_MATCH_IMAGE_QCOM     :: 1000440001;
    // Provided by VK_EXT_mutable_descriptor_type
    VK_DESCRIPTOR_TYPE_MUTABLE_EXT                :: 1000351000;
    // Provided by VK_EXT_inline_uniform_block
    VK_DESCRIPTOR_TYPE_INLINE_UNIFORM_BLOCK_EXT   :: VK_DESCRIPTOR_TYPE_INLINE_UNIFORM_BLOCK;
    // Provided by VK_VALVE_mutable_descriptor_type
    VK_DESCRIPTOR_TYPE_MUTABLE_VALVE              :: VK_DESCRIPTOR_TYPE_MUTABLE_EXT;
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
VkDescriptorImageInfo :: struct {
    sampler     : VkSampler;
    imageView   : VkImageView;
    imageLayout : VkImageLayout;
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
vkAllocateDescriptorSets :: (
    device          : VkDevice,
    pAllocateInfo   : *VkDescriptorSetAllocateInfo,
    pDescriptorSets : *VkDescriptorSet
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkFreeDescriptorSets :: (
    device             : VkDevice,
    descriptorPool     : VkDescriptorPool,
    descriptorSetCount : u32,
    pDescriptorSets    : *VkDescriptorSet
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkUpdateDescriptorSets :: (
    device               : VkDevice,
    descriptorWriteCount : u32,
    pDescriptorWrites    : *VkWriteDescriptorSet,
    descriptorCopyCount  : u32,
    pDescriptorCopies    : *VkCopyDescriptorSet
) #foreign vulkan;
