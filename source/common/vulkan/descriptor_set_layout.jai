#scope_export

// Provided by VK_VERSION_1_0
VkDescriptorSetLayout :: *VkDescriptorSetLayout_T; VkDescriptorSetLayout_T :: struct {}

// Provided by VK_VERSION_1_0
VkDescriptorSetLayoutCreateFlags :: enum_flags VkFlags #specified {
    // Provided by VK_VERSION_1_2
    VK_DESCRIPTOR_SET_LAYOUT_CREATE_UPDATE_AFTER_BIND_POOL_BIT          :: 0x00000002;
    // Provided by VK_KHR_push_descriptor
    VK_DESCRIPTOR_SET_LAYOUT_CREATE_PUSH_DESCRIPTOR_BIT_KHR             :: 0x00000001;
    // Provided by VK_EXT_descriptor_buffer
    VK_DESCRIPTOR_SET_LAYOUT_CREATE_DESCRIPTOR_BUFFER_BIT_EXT           :: 0x00000010;
    // Provided by VK_EXT_descriptor_buffer
    VK_DESCRIPTOR_SET_LAYOUT_CREATE_EMBEDDED_IMMUTABLE_SAMPLERS_BIT_EXT :: 0x00000020;
    // Provided by VK_NV_device_generated_commands_compute
    VK_DESCRIPTOR_SET_LAYOUT_CREATE_INDIRECT_BINDABLE_BIT_NV            :: 0x00000080;
    // Provided by VK_EXT_mutable_descriptor_type
    VK_DESCRIPTOR_SET_LAYOUT_CREATE_HOST_ONLY_POOL_BIT_EXT              :: 0x00000004;
    // Provided by VK_NV_per_stage_descriptor_set
    VK_DESCRIPTOR_SET_LAYOUT_CREATE_PER_STAGE_BIT_NV                    :: 0x00000040;
    // Provided by VK_EXT_descriptor_indexing
    VK_DESCRIPTOR_SET_LAYOUT_CREATE_UPDATE_AFTER_BIND_POOL_BIT_EXT      :: VK_DESCRIPTOR_SET_LAYOUT_CREATE_UPDATE_AFTER_BIND_POOL_BIT;
    // Provided by VK_VALVE_mutable_descriptor_type
    VK_DESCRIPTOR_SET_LAYOUT_CREATE_HOST_ONLY_POOL_BIT_VALVE            :: VK_DESCRIPTOR_SET_LAYOUT_CREATE_HOST_ONLY_POOL_BIT_EXT;
}

// Provided by VK_VERSION_1_0
VkDescriptorSetLayoutBinding :: struct {
    binding            : u32;
    descriptorType     : VkDescriptorType;
    descriptorCount    : u32;
    stageFlags         : VkShaderStageFlags;
    pImmutableSamplers : *VkSampler;
}

// Provided by VK_VERSION_1_0
VkDescriptorSetLayoutCreateInfo :: struct {
    sType        : VkStructureType = .VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
    pNext        : *void;
    flags        : VkDescriptorSetLayoutCreateFlags;
    bindingCount : u32;
    pBindings    : *VkDescriptorSetLayoutBinding;
}

// Provided by VK_VERSION_1_1
VkDescriptorSetLayoutSupport :: struct {
    sType     : VkStructureType = .VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_SUPPORT;
    pNext     : *void;
    supported : VkBool32;
}

// Provided by VK_VERSION_1_0
vkCreateDescriptorSetLayout :: (
    device      : VkDevice,
    pCreateInfo : *VkDescriptorSetLayoutCreateInfo,
    pAllocator  : *VkAllocationCallbacks,
    pSetLayout  : *VkDescriptorSetLayout
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkDestroyDescriptorSetLayout :: (
    device              : VkDevice,
    descriptorSetLayout : VkDescriptorSetLayout,
    pAllocator          : *VkAllocationCallbacks
) #foreign vulkan;

// Provided by VK_VERSION_1_1
vkGetDescriptorSetLayoutSupport :: (
    device      : VkDevice,
    pCreateInfo : *VkDescriptorSetLayoutCreateInfo,
    pSupport    : *VkDescriptorSetLayoutSupport
) #foreign vulkan;
