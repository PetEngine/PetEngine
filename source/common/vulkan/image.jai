// Provided by VK_VERSION_1_0
VkImage :: VK_NON_DISPATCHABLE_HANDLE;

// Provided by VK_VERSION_1_0
VK_REMAINING_ARRAY_LAYERS : u32 : 0xFFFF_FFFF;

// Provided by VK_VERSION_1_0
VK_REMAINING_MIP_LEVELS : u32 : 0xFFFF_FFFF;

// Provided by VK_VERSION_1_0
VkFormat :: enum VkEnum {
    VK_FORMAT_UNDEFINED                :: 0;
    VK_FORMAT_R8G8B8A8_UNORM           :: 37;
    VK_FORMAT_B8G8R8A8_UNORM           :: 44;
    VK_FORMAT_B8G8R8A8_SRGB            :: 50;
    VK_FORMAT_A2B10G10R10_UNORM_PACK32 :: 64;
}

// Provided by VK_VERSION_1_0
VkImageLayout :: enum VkEnum {
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
VkImageUsageFlags :: enum_flags VkFlags {
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

VkImageAspectFlags :: enum_flags VkFlags {
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
VkImageSubresourceRange :: struct {
    aspectMask     : VkImageAspectFlags;
    baseMipLevel   : u32;
    levelCount     : u32;
    baseArrayLayer : u32;
    layerCount     : u32;
}
