#scope_export

// Provided by VK_VERSION_1_0
VkDeviceAddress :: #type,distinct u64;

// Provided by VK_VERSION_1_0
VkDescriptorImageInfo :: struct {
    sampler     : VkSampler;
    imageView   : VkImageView;
    imageLayout : VkImageLayout;
}

//
// Provided by VK_EXT_descriptor_buffer
//

VkDescriptorAddressInfoEXT :: struct {
    sType   : VkStructureType = .VK_STRUCTURE_TYPE_DESCRIPTOR_ADDRESS_INFO_EXT;
    pNext   : *void;
    address : VkDeviceAddress;
    range   : VkDeviceSize;
    format  : VkFormat;
}

VkDescriptorDataEXT :: union {
    pSampler              : *VkSampler;
    pCombinedImageSampler : *VkDescriptorImageInfo;
    pInputAttachmentImage : *VkDescriptorImageInfo;
    pSampledImage         : *VkDescriptorImageInfo;
    pStorageImage         : *VkDescriptorImageInfo;
    pUniformTexelBuffer   : *VkDescriptorAddressInfoEXT;
    pStorageTexelBuffer   : *VkDescriptorAddressInfoEXT;
    pUniformBuffer        : *VkDescriptorAddressInfoEXT;
    pStorageBuffer        : *VkDescriptorAddressInfoEXT;
    accelerationStructure : VkDeviceAddress;
}

VkDescriptorGetInfoEXT :: struct {
    sType : VkStructureType = .VK_STRUCTURE_TYPE_DESCRIPTOR_GET_INFO_EXT;
    pNext : *void;
    type  : VkDescriptorType;
    data  : VkDescriptorDataEXT;
}

VkDescriptorBufferBindingInfoEXT :: struct {
    sType   : VkStructureType = .VK_STRUCTURE_TYPE_DESCRIPTOR_BUFFER_BINDING_INFO_EXT;
    pNext   : *void;
    address : VkDeviceAddress;
    usage   : VkBufferUsageFlags;
}

PFN_vkGetDescriptorSetLayoutSizeEXT :: #type (
    device             : VkDevice,
    layout             : VkDescriptorSetLayout,
    pLayoutSizeInBytes : *VkDeviceSize
) #c_call;

PFN_vkGetDescriptorSetLayoutBindingOffsetEXT :: #type (
    device  : VkDevice,
    layout  : VkDescriptorSetLayout,
    binding : u32,
    pOffset : *VkDeviceSize
) #c_call;

PFN_vkGetDescriptorEXT :: #type (
    device          : VkDevice,
    pDescriptorInfo : *VkDescriptorGetInfoEXT,
    dataSize        : size_t,
    pDescriptor     : *void
) #c_call;

PFN_vkCmdBindDescriptorBuffersEXT :: #type (
    commandBuffer : VkCommandBuffer,
    bufferCount   : u32,
    pBindingInfos : *VkDescriptorBufferBindingInfoEXT
) #c_call;

PFN_vkCmdSetDescriptorBufferOffsetsEXT :: #type (
    commandBuffer     : VkCommandBuffer,
    pipelineBindPoint : VkPipelineBindPoint,
    layout            : VkPipelineLayout,
    firstSet          : u32,
    setCount          : u32,
    pBufferIndices    : *u32,
    pOffsets          : *VkDeviceSize
) #c_call;
