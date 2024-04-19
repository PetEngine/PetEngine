#scope_export

// Provided by VK_VERSION_1_0
VkSampler :: *VkSampler_T; VkSampler_T :: struct {}

// Provided by VK_VERSION_1_0
VkFilter :: enum VkEnum #specified {
    VK_FILTER_NEAREST   :: 0;
    VK_FILTER_LINEAR    :: 1;
    // Provided by VK_EXT_filter_cubic
    VK_FILTER_CUBIC_EXT :: 1000015000;
    // Provided by VK_IMG_filter_cubic
    VK_FILTER_CUBIC_IMG :: VK_FILTER_CUBIC_EXT;
}

// Provided by VK_VERSION_1_0
VkSamplerMipmapMode :: enum VkEnum #specified {
    VK_SAMPLER_MIPMAP_MODE_NEAREST :: 0;
    VK_SAMPLER_MIPMAP_MODE_LINEAR  :: 1;
}

// Provided by VK_VERSION_1_0
VkSamplerAddressMode :: enum VkEnum #specified {
    VK_SAMPLER_ADDRESS_MODE_REPEAT                   :: 0;
    VK_SAMPLER_ADDRESS_MODE_MIRRORED_REPEAT          :: 1;
    VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE            :: 2;
    VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER          :: 3;
    // Provided by VK_VERSION_1_2, VK_KHR_sampler_mirror_clamp_to_edge
    VK_SAMPLER_ADDRESS_MODE_MIRROR_CLAMP_TO_EDGE     :: 4;
    // Provided by VK_KHR_sampler_mirror_clamp_to_edge
    VK_SAMPLER_ADDRESS_MODE_MIRROR_CLAMP_TO_EDGE_KHR :: VK_SAMPLER_ADDRESS_MODE_MIRROR_CLAMP_TO_EDGE;
}

// Provided by VK_VERSION_1_0
VkBorderColor :: enum VkEnum #specified {
    VK_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK :: 0;
    VK_BORDER_COLOR_INT_TRANSPARENT_BLACK   :: 1;
    VK_BORDER_COLOR_FLOAT_OPAQUE_BLACK      :: 2;
    VK_BORDER_COLOR_INT_OPAQUE_BLACK        :: 3;
    VK_BORDER_COLOR_FLOAT_OPAQUE_WHITE      :: 4;
    VK_BORDER_COLOR_INT_OPAQUE_WHITE        :: 5;
    // Provided by VK_EXT_custom_border_color
    VK_BORDER_COLOR_FLOAT_CUSTOM_EXT        :: 1000287003;
    // Provided by VK_EXT_custom_border_color
    VK_BORDER_COLOR_INT_CUSTOM_EXT          :: 1000287004;
}

// Provided by VK_VERSION_1_0
VkSamplerCreateFlags :: enum_flags VkFlags #specified {
    // Provided by VK_EXT_fragment_density_map
    VK_SAMPLER_CREATE_SUBSAMPLED_BIT_EXT                       :: 0x00000001;
    // Provided by VK_EXT_fragment_density_map
    VK_SAMPLER_CREATE_SUBSAMPLED_COARSE_RECONSTRUCTION_BIT_EXT :: 0x00000002;
    // Provided by VK_EXT_descriptor_buffer
    VK_SAMPLER_CREATE_DESCRIPTOR_BUFFER_CAPTURE_REPLAY_BIT_EXT :: 0x00000008;
    // Provided by VK_EXT_non_seamless_cube_map
    VK_SAMPLER_CREATE_NON_SEAMLESS_CUBE_MAP_BIT_EXT            :: 0x00000004;
    // Provided by VK_QCOM_image_processing
    VK_SAMPLER_CREATE_IMAGE_PROCESSING_BIT_QCOM                :: 0x00000010;
}

// Provided by VK_VERSION_1_0
VkSamplerCreateInfo :: struct {
    sType                   : VkStructureType = .VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
    pNext                   : *void;
    flags                   : VkSamplerCreateFlags;
    magFilter               : VkFilter;
    minFilter               : VkFilter;
    mipmapMode              : VkSamplerMipmapMode;
    addressModeU            : VkSamplerAddressMode;
    addressModeV            : VkSamplerAddressMode;
    addressModeW            : VkSamplerAddressMode;
    mipLodBias              : f32;
    anisotropyEnable        : VkBool32;
    maxAnisotropy           : f32;
    compareEnable           : VkBool32;
    compareOp               : VkCompareOp;
    minLod                  : f32;
    maxLod                  : f32;
    borderColor             : VkBorderColor;
    unnormalizedCoordinates : VkBool32;
}

// Provided by VK_VERSION_1_0
vkCreateSampler :: (
    device      : VkDevice,
    pCreateInfo : *VkSamplerCreateInfo,
    pAllocator  : *VkAllocationCallbacks,
    pSampler    : *VkSampler
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkDestroySampler :: (
    device     : VkDevice,
    sampler    : VkSampler,
    pAllocator : *VkAllocationCallbacks
) #foreign vulkan;
