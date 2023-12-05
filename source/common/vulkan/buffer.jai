#scope_export

// Provided by VK_VERSION_1_0
VkBuffer :: *VkBuffer_T; VkBuffer_T :: struct {}

// Provided by VK_VERSION_1_0
VkBufferCreateFlags :: enum_flags VkFlags #specified {
    VK_BUFFER_CREATE_SPARSE_BINDING_BIT                       :: 0x00000001;
    VK_BUFFER_CREATE_SPARSE_RESIDENCY_BIT                     :: 0x00000002;
    VK_BUFFER_CREATE_SPARSE_ALIASED_BIT                       :: 0x00000004;
    // Provided by VK_VERSION_1_1
    VK_BUFFER_CREATE_PROTECTED_BIT                            :: 0x00000008;
    // Provided by VK_VERSION_1_2
    VK_BUFFER_CREATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT        :: 0x00000010;
    // Provided by VK_EXT_descriptor_buffer
    VK_BUFFER_CREATE_DESCRIPTOR_BUFFER_CAPTURE_REPLAY_BIT_EXT :: 0x00000020;
    // Provided by VK_EXT_buffer_device_address
    VK_BUFFER_CREATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT_EXT    :: VK_BUFFER_CREATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT;
    // Provided by VK_KHR_buffer_device_address
    VK_BUFFER_CREATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT_KHR    :: VK_BUFFER_CREATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT;
}

// Provided by VK_VERSION_1_0
VkBufferUsageFlags :: enum_flags VkFlags #specified {
    VK_BUFFER_USAGE_TRANSFER_SRC_BIT                                     :: 0x00000001;
    VK_BUFFER_USAGE_TRANSFER_DST_BIT                                     :: 0x00000002;
    VK_BUFFER_USAGE_UNIFORM_TEXEL_BUFFER_BIT                             :: 0x00000004;
    VK_BUFFER_USAGE_STORAGE_TEXEL_BUFFER_BIT                             :: 0x00000008;
    VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT                                   :: 0x00000010;
    VK_BUFFER_USAGE_STORAGE_BUFFER_BIT                                   :: 0x00000020;
    VK_BUFFER_USAGE_INDEX_BUFFER_BIT                                     :: 0x00000040;
    VK_BUFFER_USAGE_VERTEX_BUFFER_BIT                                    :: 0x00000080;
    VK_BUFFER_USAGE_INDIRECT_BUFFER_BIT                                  :: 0x00000100;
    // Provided by VK_VERSION_1_2
    VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT                            :: 0x00020000;
    // Provided by VK_KHR_video_decode_queue
    VK_BUFFER_USAGE_VIDEO_DECODE_SRC_BIT_KHR                             :: 0x00002000;
    // Provided by VK_KHR_video_decode_queue
    VK_BUFFER_USAGE_VIDEO_DECODE_DST_BIT_KHR                             :: 0x00004000;
    // Provided by VK_EXT_transform_feedback
    VK_BUFFER_USAGE_TRANSFORM_FEEDBACK_BUFFER_BIT_EXT                    :: 0x00000800;
    // Provided by VK_EXT_transform_feedback
    VK_BUFFER_USAGE_TRANSFORM_FEEDBACK_COUNTER_BUFFER_BIT_EXT            :: 0x00001000;
    // Provided by VK_EXT_conditional_rendering
    VK_BUFFER_USAGE_CONDITIONAL_RENDERING_BIT_EXT                        :: 0x00000200;
#if VK_ENABLE_BETA_EXTENSIONS {
    // Provided by VK_AMDX_shader_enqueue
    VK_BUFFER_USAGE_EXECUTION_GRAPH_SCRATCH_BIT_AMDX                     :: 0x02000000;
}
    // Provided by VK_KHR_acceleration_structure
    VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_BIT_KHR :: 0x00080000;
    // Provided by VK_KHR_acceleration_structure
    VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_STORAGE_BIT_KHR               :: 0x00100000;
    // Provided by VK_KHR_ray_tracing_pipeline
    VK_BUFFER_USAGE_SHADER_BINDING_TABLE_BIT_KHR                         :: 0x00000400;
#if VK_ENABLE_BETA_EXTENSIONS {
    // Provided by VK_KHR_video_encode_queue
    VK_BUFFER_USAGE_VIDEO_ENCODE_DST_BIT_KHR                             :: 0x00008000;
    // Provided by VK_KHR_video_encode_queue
    VK_BUFFER_USAGE_VIDEO_ENCODE_SRC_BIT_KHR                             :: 0x00010000;
}
    // Provided by VK_EXT_descriptor_buffer
    VK_BUFFER_USAGE_SAMPLER_DESCRIPTOR_BUFFER_BIT_EXT                    :: 0x00200000;
    // Provided by VK_EXT_descriptor_buffer
    VK_BUFFER_USAGE_RESOURCE_DESCRIPTOR_BUFFER_BIT_EXT                   :: 0x00400000;
    // Provided by VK_EXT_descriptor_buffer
    VK_BUFFER_USAGE_PUSH_DESCRIPTORS_DESCRIPTOR_BUFFER_BIT_EXT           :: 0x04000000;
    // Provided by VK_EXT_opacity_micromap
    VK_BUFFER_USAGE_MICROMAP_BUILD_INPUT_READ_ONLY_BIT_EXT               :: 0x00800000;
    // Provided by VK_EXT_opacity_micromap
    VK_BUFFER_USAGE_MICROMAP_STORAGE_BIT_EXT                             :: 0x01000000;
    // Provided by VK_NV_ray_tracing
    VK_BUFFER_USAGE_RAY_TRACING_BIT_NV                                   :: VK_BUFFER_USAGE_SHADER_BINDING_TABLE_BIT_KHR;
    // Provided by VK_EXT_buffer_device_address
    VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT_EXT                        :: VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT;
    // Provided by VK_KHR_buffer_device_address
    VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT_KHR                        :: VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT;
}

// Provided by VK_VERSION_1_0
VkBufferCreateInfo :: struct {
    sType                 : VkStructureType = .VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
    pNext                 : *void;
    flags                 : VkBufferCreateFlags;
    size                  : VkDeviceSize;
    usage                 : VkBufferUsageFlags;
    sharingMode           : VkSharingMode;
    queueFamilyIndexCount : u32;
    pQueueFamilyIndices   : *u32;
}

// Provided by VK_VERSION_1_1
VkBufferMemoryRequirementsInfo2 :: struct {
    sType  : VkStructureType = .VK_STRUCTURE_TYPE_BUFFER_MEMORY_REQUIREMENTS_INFO_2;
    pNext  : *void;
    buffer : VkBuffer;
}

// Provided by VK_VERSION_1_1
VkBindBufferMemoryInfo :: struct {
    sType        : VkStructureType = .VK_STRUCTURE_TYPE_BIND_BUFFER_MEMORY_INFO;
    pNext        : *void;
    buffer       : VkBuffer;
    memory       : VkDeviceMemory;
    memoryOffset : VkDeviceSize;
}

// Provided by VK_VERSION_1_0
vkCreateBuffer :: (
    device      : VkDevice,
    pCreateInfo : *VkBufferCreateInfo,
    pAllocator  : *VkAllocationCallbacks,
    pBuffer     : *VkBuffer
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkDestroyBuffer :: (
    device     : VkDevice,
    buffer     : VkBuffer,
    pAllocator : *VkAllocationCallbacks
) #foreign vulkan;

// Provided by VK_VERSION_1_1
vkGetBufferMemoryRequirements2 :: (
    device              : VkDevice,
    pInfo               : *VkBufferMemoryRequirementsInfo2,
    pMemoryRequirements : *VkMemoryRequirements2
) #foreign vulkan;

// Provided by VK_VERSION_1_1
vkBindBufferMemory2 :: (
    device        : VkDevice,
    bindInfoCount : u32,
    pBindInfos    : *VkBindBufferMemoryInfo
) -> VkResult #foreign vulkan;
