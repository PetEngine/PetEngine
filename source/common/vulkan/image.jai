#scope_export

// Provided by VK_VERSION_1_0
VkImage :: *VkImage_T; VkImage_T :: struct {}

// Provided by VK_VERSION_1_0
VkImageView :: *VkImageView_T; VkImageView_T :: struct {}

// Provided by VK_VERSION_1_0
VK_REMAINING_ARRAY_LAYERS : u32 : 0xFFFF_FFFF;

// Provided by VK_VERSION_1_0
VK_REMAINING_MIP_LEVELS : u32 : 0xFFFF_FFFF;

// Provided by VK_VERSION_1_0
VK_LOD_CLAMP_NONE : f32 : 1000.0;

// Provided by VK_VERSION_1_0
VkFormat :: enum VkEnum #specified {
    VK_FORMAT_UNDEFINED                :: 0;
    VK_FORMAT_R8G8B8A8_UNORM           :: 37;
    VK_FORMAT_R8G8B8A8_SRGB            :: 43;
    VK_FORMAT_B8G8R8A8_UNORM           :: 44;
    VK_FORMAT_B8G8R8A8_SNORM           :: 45;
    VK_FORMAT_B8G8R8A8_SRGB            :: 50;
    VK_FORMAT_A2B10G10R10_UNORM_PACK32 :: 64;
    VK_FORMAT_D32_SFLOAT               :: 126;
    VK_FORMAT_S8_UINT                  :: 127;
    VK_FORMAT_BC1_RGB_UNORM_BLOCK      :: 131;
    VK_FORMAT_BC1_RGB_SRGB_BLOCK       :: 132;
    VK_FORMAT_BC1_RGBA_UNORM_BLOCK     :: 133;
    VK_FORMAT_BC1_RGBA_SRGB_BLOCK      :: 134;
    VK_FORMAT_BC2_UNORM_BLOCK          :: 135;
    VK_FORMAT_BC2_SRGB_BLOCK           :: 136;
    VK_FORMAT_BC3_UNORM_BLOCK          :: 137;
    VK_FORMAT_BC3_SRGB_BLOCK           :: 138;
    VK_FORMAT_BC4_UNORM_BLOCK          :: 139;
    VK_FORMAT_BC4_SNORM_BLOCK          :: 140;
    VK_FORMAT_BC5_UNORM_BLOCK          :: 141;
    VK_FORMAT_BC5_SNORM_BLOCK          :: 142;
    VK_FORMAT_BC6H_UFLOAT_BLOCK        :: 143;
    VK_FORMAT_BC6H_SFLOAT_BLOCK        :: 144;
    VK_FORMAT_BC7_UNORM_BLOCK          :: 145;
    VK_FORMAT_BC7_SRGB_BLOCK           :: 146;
}

// Provided by VK_VERSION_1_0
VkImageLayout :: enum VkEnum #specified {
    VK_IMAGE_LAYOUT_UNDEFINED                                      :: 0;
    VK_IMAGE_LAYOUT_GENERAL                                        :: 1;
    VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL                       :: 2;
    VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL               :: 3;
    VK_IMAGE_LAYOUT_DEPTH_STENCIL_READ_ONLY_OPTIMAL                :: 4;
    VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL                       :: 5;
    VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL                           :: 6;
    VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL                           :: 7;
    VK_IMAGE_LAYOUT_PREINITIALIZED                                 :: 8;
    // Provided by VK_VERSION_1_1
    VK_IMAGE_LAYOUT_DEPTH_READ_ONLY_STENCIL_ATTACHMENT_OPTIMAL     :: 1000117000;
    // Provided by VK_VERSION_1_1
    VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_STENCIL_READ_ONLY_OPTIMAL     :: 1000117001;
    // Provided by VK_VERSION_1_2
    VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL                       :: 1000241000;
    // Provided by VK_VERSION_1_2
    VK_IMAGE_LAYOUT_DEPTH_READ_ONLY_OPTIMAL                        :: 1000241001;
    // Provided by VK_VERSION_1_2
    VK_IMAGE_LAYOUT_STENCIL_ATTACHMENT_OPTIMAL                     :: 1000241002;
    // Provided by VK_VERSION_1_2
    VK_IMAGE_LAYOUT_STENCIL_READ_ONLY_OPTIMAL                      :: 1000241003;
    // Provided by VK_VERSION_1_3
    VK_IMAGE_LAYOUT_READ_ONLY_OPTIMAL                              :: 1000314000;
    // Provided by VK_VERSION_1_3
    VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL                             :: 1000314001;
    // Provided by VK_KHR_swapchain
    VK_IMAGE_LAYOUT_PRESENT_SRC_KHR                                :: 1000001002;
    // Provided by VK_KHR_video_decode_queue
    VK_IMAGE_LAYOUT_VIDEO_DECODE_DST_KHR                           :: 1000024000;
    // Provided by VK_KHR_video_decode_queue
    VK_IMAGE_LAYOUT_VIDEO_DECODE_SRC_KHR                           :: 1000024001;
    // Provided by VK_KHR_video_decode_queue
    VK_IMAGE_LAYOUT_VIDEO_DECODE_DPB_KHR                           :: 1000024002;
    // Provided by VK_KHR_shared_presentable_image
    VK_IMAGE_LAYOUT_SHARED_PRESENT_KHR                             :: 1000111000;
    // Provided by VK_EXT_fragment_density_map
    VK_IMAGE_LAYOUT_FRAGMENT_DENSITY_MAP_OPTIMAL_EXT               :: 1000218000;
    // Provided by VK_KHR_fragment_shading_rate
    VK_IMAGE_LAYOUT_FRAGMENT_SHADING_RATE_ATTACHMENT_OPTIMAL_KHR   :: 1000164003;
    // Provided by VK_EXT_attachment_feedback_loop_layout
    VK_IMAGE_LAYOUT_ATTACHMENT_FEEDBACK_LOOP_OPTIMAL_EXT           :: 1000339000;
    // Provided by VK_KHR_maintenance2
    VK_IMAGE_LAYOUT_DEPTH_READ_ONLY_STENCIL_ATTACHMENT_OPTIMAL_KHR :: VK_IMAGE_LAYOUT_DEPTH_READ_ONLY_STENCIL_ATTACHMENT_OPTIMAL;
    // Provided by VK_KHR_maintenance2
    VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_STENCIL_READ_ONLY_OPTIMAL_KHR :: VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_STENCIL_READ_ONLY_OPTIMAL;
    // Provided by VK_NV_shading_rate_image
    VK_IMAGE_LAYOUT_SHADING_RATE_OPTIMAL_NV                        :: VK_IMAGE_LAYOUT_FRAGMENT_SHADING_RATE_ATTACHMENT_OPTIMAL_KHR;
    // Provided by VK_KHR_separate_depth_stencil_layouts
    VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL_KHR                   :: VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL;
    // Provided by VK_KHR_separate_depth_stencil_layouts
    VK_IMAGE_LAYOUT_DEPTH_READ_ONLY_OPTIMAL_KHR                    :: VK_IMAGE_LAYOUT_DEPTH_READ_ONLY_OPTIMAL;
    // Provided by VK_KHR_separate_depth_stencil_layouts
    VK_IMAGE_LAYOUT_STENCIL_ATTACHMENT_OPTIMAL_KHR                 :: VK_IMAGE_LAYOUT_STENCIL_ATTACHMENT_OPTIMAL;
    // Provided by VK_KHR_separate_depth_stencil_layouts
    VK_IMAGE_LAYOUT_STENCIL_READ_ONLY_OPTIMAL_KHR                  :: VK_IMAGE_LAYOUT_STENCIL_READ_ONLY_OPTIMAL;
    // Provided by VK_KHR_synchronization2
    VK_IMAGE_LAYOUT_READ_ONLY_OPTIMAL_KHR                          :: VK_IMAGE_LAYOUT_READ_ONLY_OPTIMAL;
    // Provided by VK_KHR_synchronization2
    VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL_KHR                         :: VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL;
}

// Provided by VK_VERSION_1_0
VkImageType :: enum VkEnum #specified {
    VK_IMAGE_TYPE_1D :: 0;
    VK_IMAGE_TYPE_2D :: 1;
    VK_IMAGE_TYPE_3D :: 2;
}

// Provided by VK_VERSION_1_0
VkImageTiling :: enum VkEnum #specified {
    VK_IMAGE_TILING_OPTIMAL                 :: 0;
    VK_IMAGE_TILING_LINEAR                  :: 1;
    // Provided by VK_EXT_image_drm_format_modifier
    VK_IMAGE_TILING_DRM_FORMAT_MODIFIER_EXT :: 1000158000;
}

// Provided by VK_VERSION_1_0
VkImageViewType :: enum VkEnum #specified {
    VK_IMAGE_VIEW_TYPE_1D         :: 0;
    VK_IMAGE_VIEW_TYPE_2D         :: 1;
    VK_IMAGE_VIEW_TYPE_3D         :: 2;
    VK_IMAGE_VIEW_TYPE_CUBE       :: 3;
    VK_IMAGE_VIEW_TYPE_1D_ARRAY   :: 4;
    VK_IMAGE_VIEW_TYPE_2D_ARRAY   :: 5;
    VK_IMAGE_VIEW_TYPE_CUBE_ARRAY :: 6;
}

// Provided by VK_VERSION_1_0
VkComponentSwizzle :: enum VkEnum #specified {
    VK_COMPONENT_SWIZZLE_IDENTITY :: 0;
    VK_COMPONENT_SWIZZLE_ZERO     :: 1;
    VK_COMPONENT_SWIZZLE_ONE      :: 2;
    VK_COMPONENT_SWIZZLE_R        :: 3;
    VK_COMPONENT_SWIZZLE_G        :: 4;
    VK_COMPONENT_SWIZZLE_B        :: 5;
    VK_COMPONENT_SWIZZLE_A        :: 6;
}

// Provided by VK_VERSION_1_0
VkImageUsageFlags :: enum_flags VkFlags #specified {
    VK_IMAGE_USAGE_TRANSFER_SRC_BIT                         :: 0x00000001;
    VK_IMAGE_USAGE_TRANSFER_DST_BIT                         :: 0x00000002;
    VK_IMAGE_USAGE_SAMPLED_BIT                              :: 0x00000004;
    VK_IMAGE_USAGE_STORAGE_BIT                              :: 0x00000008;
    VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT                     :: 0x00000010;
    VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT             :: 0x00000020;
    VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT                 :: 0x00000040;
    VK_IMAGE_USAGE_INPUT_ATTACHMENT_BIT                     :: 0x00000080;
    // Provided by VK_EXT_fragment_density_map
    VK_IMAGE_USAGE_FRAGMENT_DENSITY_MAP_BIT_EXT             :: 0x00000200;
    // Provided by VK_KHR_fragment_shading_rate
    VK_IMAGE_USAGE_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR :: 0x00000100;
    // Provided by VK_EXT_attachment_feedback_loop_layout
    VK_IMAGE_USAGE_ATTACHMENT_FEEDBACK_LOOP_BIT_EXT         :: 0x00080000;
    // Provided by VK_HUAWEI_invocation_mask
    VK_IMAGE_USAGE_INVOCATION_MASK_BIT_HUAWEI               :: 0x00040000;
    // Provided by VK_QCOM_image_processing
    VK_IMAGE_USAGE_SAMPLE_WEIGHT_BIT_QCOM                   :: 0x00100000;
    // Provided by VK_QCOM_image_processing
    VK_IMAGE_USAGE_SAMPLE_BLOCK_MATCH_BIT_QCOM              :: 0x00200000;
    // Provided by VK_NV_shading_rate_image
    VK_IMAGE_USAGE_SHADING_RATE_IMAGE_BIT_NV                :: VK_IMAGE_USAGE_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR;
}

VkImageAspectFlags :: enum_flags VkFlags #specified {
    VK_IMAGE_ASPECT_COLOR_BIT              :: 0x00000001;
    VK_IMAGE_ASPECT_DEPTH_BIT              :: 0x00000002;
    VK_IMAGE_ASPECT_STENCIL_BIT            :: 0x00000004;
    VK_IMAGE_ASPECT_METADATA_BIT           :: 0x00000008;
    // Provided by VK_VERSION_1_1
    VK_IMAGE_ASPECT_PLANE_0_BIT            :: 0x00000010;
    // Provided by VK_VERSION_1_1
    VK_IMAGE_ASPECT_PLANE_1_BIT            :: 0x00000020;
    // Provided by VK_VERSION_1_1
    VK_IMAGE_ASPECT_PLANE_2_BIT            :: 0x00000040;
    // Provided by VK_VERSION_1_3
    VK_IMAGE_ASPECT_NONE                   :: 0;
    // Provided by VK_EXT_image_drm_format_modifier
    VK_IMAGE_ASPECT_MEMORY_PLANE_0_BIT_EXT :: 0x00000080;
    // Provided by VK_EXT_image_drm_format_modifier
    VK_IMAGE_ASPECT_MEMORY_PLANE_1_BIT_EXT :: 0x00000100;
    // Provided by VK_EXT_image_drm_format_modifier
    VK_IMAGE_ASPECT_MEMORY_PLANE_2_BIT_EXT :: 0x00000200;
    // Provided by VK_EXT_image_drm_format_modifier
    VK_IMAGE_ASPECT_MEMORY_PLANE_3_BIT_EXT :: 0x00000400;
    // Provided by VK_KHR_sampler_ycbcr_conversion
    VK_IMAGE_ASPECT_PLANE_0_BIT_KHR        :: VK_IMAGE_ASPECT_PLANE_0_BIT;
    // Provided by VK_KHR_sampler_ycbcr_conversion
    VK_IMAGE_ASPECT_PLANE_1_BIT_KHR        :: VK_IMAGE_ASPECT_PLANE_1_BIT;
    // Provided by VK_KHR_sampler_ycbcr_conversion
    VK_IMAGE_ASPECT_PLANE_2_BIT_KHR        :: VK_IMAGE_ASPECT_PLANE_2_BIT;
    // Provided by VK_KHR_maintenance4
    VK_IMAGE_ASPECT_NONE_KHR               :: VK_IMAGE_ASPECT_NONE;
}

// Provided by VK_VERSION_1_0
VkImageCreateFlags :: enum_flags VkFlags #specified {
    VK_IMAGE_CREATE_SPARSE_BINDING_BIT                            :: 0x00000001;
    VK_IMAGE_CREATE_SPARSE_RESIDENCY_BIT                          :: 0x00000002;
    VK_IMAGE_CREATE_SPARSE_ALIASED_BIT                            :: 0x00000004;
    VK_IMAGE_CREATE_MUTABLE_FORMAT_BIT                            :: 0x00000008;
    VK_IMAGE_CREATE_CUBE_COMPATIBLE_BIT                           :: 0x00000010;
    // Provided by VK_VERSION_1_1
    VK_IMAGE_CREATE_ALIAS_BIT                                     :: 0x00000400;
    // Provided by VK_VERSION_1_1
    VK_IMAGE_CREATE_SPLIT_INSTANCE_BIND_REGIONS_BIT               :: 0x00000040;
    // Provided by VK_VERSION_1_1
    VK_IMAGE_CREATE_2D_ARRAY_COMPATIBLE_BIT                       :: 0x00000020;
    // Provided by VK_VERSION_1_1
    VK_IMAGE_CREATE_BLOCK_TEXEL_VIEW_COMPATIBLE_BIT               :: 0x00000080;
    // Provided by VK_VERSION_1_1
    VK_IMAGE_CREATE_EXTENDED_USAGE_BIT                            :: 0x00000100;
    // Provided by VK_VERSION_1_1
    VK_IMAGE_CREATE_PROTECTED_BIT                                 :: 0x00000800;
    // Provided by VK_VERSION_1_1
    VK_IMAGE_CREATE_DISJOINT_BIT                                  :: 0x00000200;
    // Provided by VK_NV_corner_sampled_image
    VK_IMAGE_CREATE_CORNER_SAMPLED_BIT_NV                         :: 0x00002000;
    // Provided by VK_EXT_sample_locations
    VK_IMAGE_CREATE_SAMPLE_LOCATIONS_COMPATIBLE_DEPTH_BIT_EXT     :: 0x00001000;
    // Provided by VK_EXT_fragment_density_map
    VK_IMAGE_CREATE_SUBSAMPLED_BIT_EXT                            :: 0x00004000;
    // Provided by VK_EXT_descriptor_buffer
    VK_IMAGE_CREATE_DESCRIPTOR_BUFFER_CAPTURE_REPLAY_BIT_EXT      :: 0x00010000;
    // Provided by VK_EXT_multisampled_render_to_single_sampled
    VK_IMAGE_CREATE_MULTISAMPLED_RENDER_TO_SINGLE_SAMPLED_BIT_EXT :: 0x00040000;
    // Provided by VK_EXT_image_2d_view_of_3d
    VK_IMAGE_CREATE_2D_VIEW_COMPATIBLE_BIT_EXT                    :: 0x00020000;
    // Provided by VK_QCOM_fragment_density_map_offset
    VK_IMAGE_CREATE_FRAGMENT_DENSITY_MAP_OFFSET_BIT_QCOM          :: 0x00008000;
    // Provided by VK_KHR_bind_memory2 with VK_KHR_device_group
    VK_IMAGE_CREATE_SPLIT_INSTANCE_BIND_REGIONS_BIT_KHR           :: VK_IMAGE_CREATE_SPLIT_INSTANCE_BIND_REGIONS_BIT;
    // Provided by VK_KHR_maintenance1
    VK_IMAGE_CREATE_2D_ARRAY_COMPATIBLE_BIT_KHR                   :: VK_IMAGE_CREATE_2D_ARRAY_COMPATIBLE_BIT;
    // Provided by VK_KHR_maintenance2
    VK_IMAGE_CREATE_BLOCK_TEXEL_VIEW_COMPATIBLE_BIT_KHR           :: VK_IMAGE_CREATE_BLOCK_TEXEL_VIEW_COMPATIBLE_BIT;
    // Provided by VK_KHR_maintenance2
    VK_IMAGE_CREATE_EXTENDED_USAGE_BIT_KHR                        :: VK_IMAGE_CREATE_EXTENDED_USAGE_BIT;
    // Provided by VK_KHR_sampler_ycbcr_conversion
    VK_IMAGE_CREATE_DISJOINT_BIT_KHR                              :: VK_IMAGE_CREATE_DISJOINT_BIT;
    // Provided by VK_KHR_bind_memory2
    VK_IMAGE_CREATE_ALIAS_BIT_KHR                                 :: VK_IMAGE_CREATE_ALIAS_BIT;
}

// Provided by VK_VERSION_1_0
VkImageViewCreateFlags :: enum_flags VkFlags #specified {
    // Provided by VK_EXT_fragment_density_map
    VK_IMAGE_VIEW_CREATE_FRAGMENT_DENSITY_MAP_DYNAMIC_BIT_EXT     :: 0x00000001;
    // Provided by VK_EXT_descriptor_buffer
    VK_IMAGE_VIEW_CREATE_DESCRIPTOR_BUFFER_CAPTURE_REPLAY_BIT_EXT :: 0x00000004;
    // Provided by VK_EXT_fragment_density_map2
    VK_IMAGE_VIEW_CREATE_FRAGMENT_DENSITY_MAP_DEFERRED_BIT_EXT    :: 0x00000002;
}

// Provided by VK_VERSION_1_0
VkImageSubresourceRange :: struct {
    aspectMask     : VkImageAspectFlags;
    baseMipLevel   : u32;
    levelCount     : u32;
    baseArrayLayer : u32;
    layerCount     : u32;
}

// Provided by VK_VERSION_1_0
VkImageCreateInfo :: struct {
    sType                 : VkStructureType = .VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
    pNext                 : *void;
    flags                 : VkImageCreateFlags;
    imageType             : VkImageType;
    format                : VkFormat;
    extent                : VkExtent3D;
    mipLevels             : u32;
    arrayLayers           : u32;
    samples               : VkSampleCountFlags;
    tiling                : VkImageTiling;
    usage                 : VkImageUsageFlags;
    sharingMode           : VkSharingMode;
    queueFamilyIndexCount : u32;
    pQueueFamilyIndices   : *u32;
    initialLayout         : VkImageLayout;
}

// Provided by VK_VERSION_1_0
VkImageSubresource :: struct {
    aspectMask : VkImageAspectFlags;
    mipLevel   : u32;
    arrayLayer : u32;
}

// Provided by VK_VERSION_1_0
VkSubresourceLayout :: struct {
    offset     : VkDeviceSize;
    size       : VkDeviceSize;
    rowPitch   : VkDeviceSize;
    arrayPitch : VkDeviceSize;
    depthPitch : VkDeviceSize;
}

// Provided by VK_VERSION_1_1
VkBindImageMemoryInfo :: struct {
    sType        : VkStructureType = .VK_STRUCTURE_TYPE_BIND_IMAGE_MEMORY_INFO;
    pNext        : *void;
    image        : VkImage;
    memory       : VkDeviceMemory;
    memoryOffset : VkDeviceSize;
}

// Provided by VK_VERSION_1_1
VkImageMemoryRequirementsInfo2 :: struct {
    sType : VkStructureType = .VK_STRUCTURE_TYPE_IMAGE_MEMORY_REQUIREMENTS_INFO_2;
    pNext : *void;
    image : VkImage;
}

// Provided by VK_VERSION_1_1
VkPhysicalDeviceImageFormatInfo2 :: struct {
    sType  : VkStructureType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_FORMAT_INFO_2;
    pNext  : *void;
    format : VkFormat;
    type   : VkImageType;
    tiling : VkImageTiling;
    usage  : VkImageUsageFlags;
    flags  : VkImageCreateFlags;
}

// Provided by VK_VERSION_1_0
VkImageFormatProperties :: struct {
    maxExtent       : VkExtent3D;
    maxMipLevels    : u32;
    maxArrayLayers  : u32;
    sampleCounts    : VkSampleCountFlags;
    maxResourceSize : VkDeviceSize;
}

// Provided by VK_VERSION_1_1
VkImageFormatProperties2 :: struct {
    sType                 : VkStructureType = .VK_STRUCTURE_TYPE_IMAGE_FORMAT_PROPERTIES_2;
    pNext                 : *void;
    imageFormatProperties : VkImageFormatProperties;
}

// Provided by VK_VERSION_1_0
VkComponentMapping :: struct {
    r : VkComponentSwizzle;
    g : VkComponentSwizzle;
    b : VkComponentSwizzle;
    a : VkComponentSwizzle;
}

// Provided by VK_VERSION_1_0
VkImageViewCreateInfo :: struct {
    sType            : VkStructureType = .VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
    pNext            : *void;
    flags            : VkImageViewCreateFlags;
    image            : VkImage;
    viewType         : VkImageViewType;
    format           : VkFormat;
    components       : VkComponentMapping;
    subresourceRange : VkImageSubresourceRange;
}

// Provided by VK_VERSION_1_1
VkImageViewUsageCreateInfo :: struct {
    sType : VkStructureType = .VK_STRUCTURE_TYPE_IMAGE_VIEW_USAGE_CREATE_INFO;
    pNext : *void;
    usage : VkImageUsageFlags;
}

// Provided by VK_VERSION_1_0
VkImageSubresourceLayers :: struct {
    aspectMask     : VkImageAspectFlags;
    mipLevel       : u32;
    baseArrayLayer : u32;
    layerCount     : u32;
}

// Provided by VK_VERSION_1_0
vkCreateImage :: (
    device      : VkDevice,
    pCreateInfo : *VkImageCreateInfo,
    pAllocator  : *VkAllocationCallbacks,
    pImage      : *VkImage
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkDestroyImage :: (
    device     : VkDevice,
    image      : VkImage,
    pAllocator : *VkAllocationCallbacks
) #foreign vulkan;

// Provided by VK_VERSION_1_0
vkGetImageSubresourceLayout :: (
    device       : VkDevice,
    image        : VkImage,
    pSubresource : *VkImageSubresource,
    pLayout      : *VkSubresourceLayout
) #foreign vulkan;

// Provided by VK_VERSION_1_1
vkBindImageMemory2 :: (
    device        : VkDevice,
    bindInfoCount : u32,
    pBindInfos    : *VkBindImageMemoryInfo
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_1
vkGetImageMemoryRequirements2 :: (
    device              : VkDevice,
    pInfo               : *VkImageMemoryRequirementsInfo2,
    pMemoryRequirements : *VkMemoryRequirements2
) #foreign vulkan;

// Provided by VK_VERSION_1_1
vkGetPhysicalDeviceImageFormatProperties2 :: (
    physicalDevice         : VkPhysicalDevice,
    pImageFormatInfo       : *VkPhysicalDeviceImageFormatInfo2,
    pImageFormatProperties : *VkImageFormatProperties2
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkCreateImageView :: (
    device      : VkDevice,
    pCreateInfo : *VkImageViewCreateInfo,
    pAllocator  : *VkAllocationCallbacks,
    pView       : *VkImageView
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkDestroyImageView :: (
    device     : VkDevice,
    imageView  : VkImageView,
    pAllocator : *VkAllocationCallbacks
) #foreign vulkan;
