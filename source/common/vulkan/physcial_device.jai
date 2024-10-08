#scope_export

// Provided by VK_VERSION_1_0
VkPhysicalDevice :: *VkPhysicalDevice_T; VkPhysicalDevice_T :: struct {}

// Provided by VK_VERSION_1_0
VK_MAX_PHYSICAL_DEVICE_NAME_SIZE : u32 : 256;

// Provided by VK_VERSION_1_0
VK_UUID_SIZE : u32 : 16;

// Provided by VK_VERSION_1_1
VK_LUID_SIZE : u32 : 8;

// Provided by VK_VERSION_1_0
VkDeviceSize :: #type,distinct u64;

// Provided by VK_VERSION_1_2
VK_MAX_DRIVER_NAME_SIZE : u32 : 256;

// Provided by VK_VERSION_1_2
VK_MAX_DRIVER_INFO_SIZE : u32 : 256;

// Provided by VK_VERSION_1_0
VkPhysicalDeviceType :: enum VkEnum #specified {
    VK_PHYSICAL_DEVICE_TYPE_OTHER          :: 0;
    VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU :: 1;
    VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU   :: 2;
    VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU    :: 3;
    VK_PHYSICAL_DEVICE_TYPE_CPU            :: 4;
}

// Provided by VK_VERSION_1_0
VkVendorId :: enum VkEnum #specified {
    VK_VENDOR_ID_VIV      :: 0x10001;
    VK_VENDOR_ID_VSI      :: 0x10002;
    VK_VENDOR_ID_KAZAN    :: 0x10003;
    VK_VENDOR_ID_CODEPLAY :: 0x10004;
    VK_VENDOR_ID_MESA     :: 0x10005;
    VK_VENDOR_ID_POCL     :: 0x10006;
    VK_VENDOR_ID_MOBILEYE :: 0x10007;
}

// Provided by VK_VERSION_1_1
VkPointClippingBehavior :: enum VkEnum #specified {
    VK_POINT_CLIPPING_BEHAVIOR_ALL_CLIP_PLANES           :: 0;
    VK_POINT_CLIPPING_BEHAVIOR_USER_CLIP_PLANES_ONLY     :: 1;
    // Provided by VK_KHR_maintenance2
    VK_POINT_CLIPPING_BEHAVIOR_ALL_CLIP_PLANES_KHR       :: VK_POINT_CLIPPING_BEHAVIOR_ALL_CLIP_PLANES;
    // Provided by VK_KHR_maintenance2
    VK_POINT_CLIPPING_BEHAVIOR_USER_CLIP_PLANES_ONLY_KHR :: VK_POINT_CLIPPING_BEHAVIOR_USER_CLIP_PLANES_ONLY;
}

// Provided by VK_VERSION_1_2
VkDriverId :: enum VkEnum #specified {
    VK_DRIVER_ID_AMD_PROPRIETARY               :: 1;
    VK_DRIVER_ID_AMD_OPEN_SOURCE               :: 2;
    VK_DRIVER_ID_MESA_RADV                     :: 3;
    VK_DRIVER_ID_NVIDIA_PROPRIETARY            :: 4;
    VK_DRIVER_ID_INTEL_PROPRIETARY_WINDOWS     :: 5;
    VK_DRIVER_ID_INTEL_OPEN_SOURCE_MESA        :: 6;
    VK_DRIVER_ID_IMAGINATION_PROPRIETARY       :: 7;
    VK_DRIVER_ID_QUALCOMM_PROPRIETARY          :: 8;
    VK_DRIVER_ID_ARM_PROPRIETARY               :: 9;
    VK_DRIVER_ID_GOOGLE_SWIFTSHADER            :: 10;
    VK_DRIVER_ID_GGP_PROPRIETARY               :: 11;
    VK_DRIVER_ID_BROADCOM_PROPRIETARY          :: 12;
    VK_DRIVER_ID_MESA_LLVMPIPE                 :: 13;
    VK_DRIVER_ID_MOLTENVK                      :: 14;
    VK_DRIVER_ID_COREAVI_PROPRIETARY           :: 15;
    VK_DRIVER_ID_JUICE_PROPRIETARY             :: 16;
    VK_DRIVER_ID_VERISILICON_PROPRIETARY       :: 17;
    VK_DRIVER_ID_MESA_TURNIP                   :: 18;
    VK_DRIVER_ID_MESA_V3DV                     :: 19;
    VK_DRIVER_ID_MESA_PANVK                    :: 20;
    VK_DRIVER_ID_SAMSUNG_PROPRIETARY           :: 21;
    VK_DRIVER_ID_MESA_VENUS                    :: 22;
    VK_DRIVER_ID_MESA_DOZEN                    :: 23;
    VK_DRIVER_ID_MESA_NVK                      :: 24;
    VK_DRIVER_ID_IMAGINATION_OPEN_SOURCE_MESA  :: 25;
    // Provided by VK_KHR_driver_properties
    VK_DRIVER_ID_AMD_PROPRIETARY_KHR           :: VK_DRIVER_ID_AMD_PROPRIETARY;
    // Provided by VK_KHR_driver_properties
    VK_DRIVER_ID_AMD_OPEN_SOURCE_KHR           :: VK_DRIVER_ID_AMD_OPEN_SOURCE;
    // Provided by VK_KHR_driver_properties
    VK_DRIVER_ID_MESA_RADV_KHR                 :: VK_DRIVER_ID_MESA_RADV;
    // Provided by VK_KHR_driver_properties
    VK_DRIVER_ID_NVIDIA_PROPRIETARY_KHR        :: VK_DRIVER_ID_NVIDIA_PROPRIETARY;
    // Provided by VK_KHR_driver_properties
    VK_DRIVER_ID_INTEL_PROPRIETARY_WINDOWS_KHR :: VK_DRIVER_ID_INTEL_PROPRIETARY_WINDOWS;
    // Provided by VK_KHR_driver_properties
    VK_DRIVER_ID_INTEL_OPEN_SOURCE_MESA_KHR    :: VK_DRIVER_ID_INTEL_OPEN_SOURCE_MESA;
    // Provided by VK_KHR_driver_properties
    VK_DRIVER_ID_IMAGINATION_PROPRIETARY_KHR   :: VK_DRIVER_ID_IMAGINATION_PROPRIETARY;
    // Provided by VK_KHR_driver_properties
    VK_DRIVER_ID_QUALCOMM_PROPRIETARY_KHR      :: VK_DRIVER_ID_QUALCOMM_PROPRIETARY;
    // Provided by VK_KHR_driver_properties
    VK_DRIVER_ID_ARM_PROPRIETARY_KHR           :: VK_DRIVER_ID_ARM_PROPRIETARY;
    // Provided by VK_KHR_driver_properties
    VK_DRIVER_ID_GOOGLE_SWIFTSHADER_KHR        :: VK_DRIVER_ID_GOOGLE_SWIFTSHADER;
    // Provided by VK_KHR_driver_properties
    VK_DRIVER_ID_GGP_PROPRIETARY_KHR           :: VK_DRIVER_ID_GGP_PROPRIETARY;
    // Provided by VK_KHR_driver_properties
    VK_DRIVER_ID_BROADCOM_PROPRIETARY_KHR      :: VK_DRIVER_ID_BROADCOM_PROPRIETARY;
}

// Provided by VK_VERSION_1_2
VkShaderFloatControlsIndependence :: enum VkEnum #specified {
    VK_SHADER_FLOAT_CONTROLS_INDEPENDENCE_32_BIT_ONLY     :: 0;
    VK_SHADER_FLOAT_CONTROLS_INDEPENDENCE_ALL             :: 1;
    VK_SHADER_FLOAT_CONTROLS_INDEPENDENCE_NONE            :: 2;
    // Provided by VK_KHR_shader_float_controls
    VK_SHADER_FLOAT_CONTROLS_INDEPENDENCE_32_BIT_ONLY_KHR :: VK_SHADER_FLOAT_CONTROLS_INDEPENDENCE_32_BIT_ONLY;
    // Provided by VK_KHR_shader_float_controls
    VK_SHADER_FLOAT_CONTROLS_INDEPENDENCE_ALL_KHR         :: VK_SHADER_FLOAT_CONTROLS_INDEPENDENCE_ALL;
    // Provided by VK_KHR_shader_float_controls
    VK_SHADER_FLOAT_CONTROLS_INDEPENDENCE_NONE_KHR        :: VK_SHADER_FLOAT_CONTROLS_INDEPENDENCE_NONE;
}

// Provided by VK_VERSION_1_0
VkSampleCountFlags :: enum_flags VkFlags #specified {
    VK_SAMPLE_COUNT_1_BIT  :: 0x00000001;
    VK_SAMPLE_COUNT_2_BIT  :: 0x00000002;
    VK_SAMPLE_COUNT_4_BIT  :: 0x00000004;
    VK_SAMPLE_COUNT_8_BIT  :: 0x00000008;
    VK_SAMPLE_COUNT_16_BIT :: 0x00000010;
    VK_SAMPLE_COUNT_32_BIT :: 0x00000020;
    VK_SAMPLE_COUNT_64_BIT :: 0x00000040;
}

// Provided by VK_VERSION_1_0
VkQueueFlags :: enum_flags VkFlags #specified {
    VK_QUEUE_GRAPHICS_BIT         :: 0x00000001;
    VK_QUEUE_COMPUTE_BIT          :: 0x00000002;
    VK_QUEUE_TRANSFER_BIT         :: 0x00000004;
    VK_QUEUE_SPARSE_BINDING_BIT   :: 0x00000008;
    // Provided by VK_VERSION_1_1
    VK_QUEUE_PROTECTED_BIT        :: 0x00000010;
    // Provided by VK_KHR_video_decode_queue
    VK_QUEUE_VIDEO_DECODE_BIT_KHR :: 0x00000020;
#if VK_ENABLE_BETA_EXTENSIONS {
    // Provided by VK_KHR_video_encode_queue
    VK_QUEUE_VIDEO_ENCODE_BIT_KHR :: 0x00000040;
}
    // Provided by VK_NV_optical_flow
    VK_QUEUE_OPTICAL_FLOW_BIT_NV  :: 0x00000100;
}

// Provided by VK_VERSION_1_1
VkSubgroupFeatureFlags :: enum_flags VkFlags #specified {
    VK_SUBGROUP_FEATURE_BASIC_BIT                :: 0x00000001;
    VK_SUBGROUP_FEATURE_VOTE_BIT                 :: 0x00000002;
    VK_SUBGROUP_FEATURE_ARITHMETIC_BIT           :: 0x00000004;
    VK_SUBGROUP_FEATURE_BALLOT_BIT               :: 0x00000008;
    VK_SUBGROUP_FEATURE_SHUFFLE_BIT              :: 0x00000010;
    VK_SUBGROUP_FEATURE_SHUFFLE_RELATIVE_BIT     :: 0x00000020;
    VK_SUBGROUP_FEATURE_CLUSTERED_BIT            :: 0x00000040;
    VK_SUBGROUP_FEATURE_QUAD_BIT                 :: 0x00000080;
    // Provided by VK_NV_shader_subgroup_partitioned
    VK_SUBGROUP_FEATURE_PARTITIONED_BIT_NV       :: 0x00000100;
    // Provided by VK_KHR_shader_subgroup_rotate
    VK_SUBGROUP_FEATURE_ROTATE_BIT_KHR           :: 0x00000200;
    // Provided by VK_KHR_shader_subgroup_rotate
    VK_SUBGROUP_FEATURE_ROTATE_CLUSTERED_BIT_KHR :: 0x00000400;
}

// Provided by VK_VERSION_1_0
VkPhysicalDeviceLimits :: struct {
    maxImageDimension1D                             : u32;
    maxImageDimension2D                             : u32;
    maxImageDimension3D                             : u32;
    maxImageDimensionCube                           : u32;
    maxImageArrayLayers                             : u32;
    maxTexelBufferElements                          : u32;
    maxUniformBufferRange                           : u32;
    maxStorageBufferRange                           : u32;
    maxPushConstantsSize                            : u32;
    maxMemoryAllocationCount                        : u32;
    maxSamplerAllocationCount                       : u32;
    bufferImageGranularity                          : VkDeviceSize;
    sparseAddressSpaceSize                          : VkDeviceSize;
    maxBoundDescriptorSets                          : u32;
    maxPerStageDescriptorSamplers                   : u32;
    maxPerStageDescriptorUniformBuffers             : u32;
    maxPerStageDescriptorStorageBuffers             : u32;
    maxPerStageDescriptorSampledImages              : u32;
    maxPerStageDescriptorStorageImages              : u32;
    maxPerStageDescriptorInputAttachments           : u32;
    maxPerStageResources                            : u32;
    maxDescriptorSetSamplers                        : u32;
    maxDescriptorSetUniformBuffers                  : u32;
    maxDescriptorSetUniformBuffersDynamic           : u32;
    maxDescriptorSetStorageBuffers                  : u32;
    maxDescriptorSetStorageBuffersDynamic           : u32;
    maxDescriptorSetSampledImages                   : u32;
    maxDescriptorSetStorageImages                   : u32;
    maxDescriptorSetInputAttachments                : u32;
    maxVertexInputAttributes                        : u32;
    maxVertexInputBindings                          : u32;
    maxVertexInputAttributeOffset                   : u32;
    maxVertexInputBindingStride                     : u32;
    maxVertexOutputComponents                       : u32;
    maxTessellationGenerationLevel                  : u32;
    maxTessellationPatchSize                        : u32;
    maxTessellationControlPerVertexInputComponents  : u32;
    maxTessellationControlPerVertexOutputComponents : u32;
    maxTessellationControlPerPatchOutputComponents  : u32;
    maxTessellationControlTotalOutputComponents     : u32;
    maxTessellationEvaluationInputComponents        : u32;
    maxTessellationEvaluationOutputComponents       : u32;
    maxGeometryShaderInvocations                    : u32;
    maxGeometryInputComponents                      : u32;
    maxGeometryOutputComponents                     : u32;
    maxGeometryOutputVertices                       : u32;
    maxGeometryTotalOutputComponents                : u32;
    maxFragmentInputComponents                      : u32;
    maxFragmentOutputAttachments                    : u32;
    maxFragmentDualSrcAttachments                   : u32;
    maxFragmentCombinedOutputResources              : u32;
    maxComputeSharedMemorySize                      : u32;
    maxComputeWorkGroupCount                        : [3] u32;
    maxComputeWorkGroupInvocations                  : u32;
    maxComputeWorkGroupSize                         : [3] u32;
    subPixelPrecisionBits                           : u32;
    subTexelPrecisionBits                           : u32;
    mipmapPrecisionBits                             : u32;
    maxDrawIndexedIndexValue                        : u32;
    maxDrawIndirectCount                            : u32;
    maxSamplerLodBias                               : f32;
    maxSamplerAnisotropy                            : f32;
    maxViewports                                    : u32;
    maxViewportDimensions                           : [2] u32;
    viewportBoundsRange                             : [2] f32;
    viewportSubPixelBits                            : u32;
    minMemoryMapAlignment                           : size_t;
    minTexelBufferOffsetAlignment                   : VkDeviceSize;
    minUniformBufferOffsetAlignment                 : VkDeviceSize;
    minStorageBufferOffsetAlignment                 : VkDeviceSize;
    minTexelOffset                                  : s32;
    maxTexelOffset                                  : u32;
    minTexelGatherOffset                            : s32;
    maxTexelGatherOffset                            : u32;
    minInterpolationOffset                          : f32;
    maxInterpolationOffset                          : f32;
    subPixelInterpolationOffsetBits                 : u32;
    maxFramebufferWidth                             : u32;
    maxFramebufferHeight                            : u32;
    maxFramebufferLayers                            : u32;
    framebufferColorSampleCounts                    : VkSampleCountFlags;
    framebufferDepthSampleCounts                    : VkSampleCountFlags;
    framebufferStencilSampleCounts                  : VkSampleCountFlags;
    framebufferNoAttachmentsSampleCounts            : VkSampleCountFlags;
    maxColorAttachments                             : u32;
    sampledImageColorSampleCounts                   : VkSampleCountFlags;
    sampledImageIntegerSampleCounts                 : VkSampleCountFlags;
    sampledImageDepthSampleCounts                   : VkSampleCountFlags;
    sampledImageStencilSampleCounts                 : VkSampleCountFlags;
    storageImageSampleCounts                        : VkSampleCountFlags;
    maxSampleMaskWords                              : u32;
    timestampComputeAndGraphics                     : VkBool32;
    timestampPeriod                                 : f32;
    maxClipDistances                                : u32;
    maxCullDistances                                : u32;
    maxCombinedClipAndCullDistances                 : u32;
    discreteQueuePriorities                         : u32;
    pointSizeRange                                  : [2] f32;
    lineWidthRange                                  : [2] f32;
    pointSizeGranularity                            : f32;
    lineWidthGranularity                            : f32;
    strictLines                                     : VkBool32;
    standardSampleLocations                         : VkBool32;
    optimalBufferCopyOffsetAlignment                : VkDeviceSize;
    optimalBufferCopyRowPitchAlignment              : VkDeviceSize;
    nonCoherentAtomSize                             : VkDeviceSize;
}

// Provided by VK_VERSION_1_0
VkPhysicalDeviceSparseProperties :: struct {
    residencyStandard2DBlockShape            : VkBool32;
    residencyStandard2DMultisampleBlockShape : VkBool32;
    residencyStandard3DBlockShape            : VkBool32;
    residencyAlignedMipSize                  : VkBool32;
    residencyNonResidentStrict               : VkBool32;
}

// Provided by VK_VERSION_1_0
VkPhysicalDeviceProperties :: struct {
    apiVersion        : u32;
    driverVersion     : u32;
    vendorID          : u32;
    deviceID          : u32;
    deviceType        : VkPhysicalDeviceType;
    deviceName        : [VK_MAX_PHYSICAL_DEVICE_NAME_SIZE] u8;
    pipelineCacheUUID : [VK_UUID_SIZE] u8;
    limits            : VkPhysicalDeviceLimits;
    sparseProperties  : VkPhysicalDeviceSparseProperties;
}

// Provided by VK_VERSION_1_1
VkPhysicalDeviceProperties2 :: struct {
    sType      : VkStructureType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
    pNext      : *void;
    properties : VkPhysicalDeviceProperties;
}

// Provided by VK_VERSION_1_2
VkConformanceVersion :: struct {
    major    : u8;
    minor    : u8;
    subminor : u8;
    patch    : u8;
}

// Provided by VK_VERSION_1_2
VkPhysicalDeviceDriverProperties :: struct {
    sType              : VkStructureType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DRIVER_PROPERTIES;
    pNext              : *void;
    driverID           : VkDriverId;
    driverName         : [VK_MAX_DRIVER_NAME_SIZE] u8;
    driverInfo         : [VK_MAX_DRIVER_INFO_SIZE] u8;
    conformanceVersion : VkConformanceVersion;
}

// Provided by VK_VERSION_1_0
VkQueueFamilyProperties :: struct {
    queueFlags                  : VkQueueFlags;
    queueCount                  : u32;
    timestampValidBits          : u32;
    minImageTransferGranularity : VkExtent3D;
}

// Provided by VK_VERSION_1_2
VkPhysicalDeviceVulkan11Properties :: struct {
    sType                             : VkStructureType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_PROPERTIES;
    pNext                             : *void;
    deviceUUID                        : [VK_UUID_SIZE] u8;
    driverUUID                        : [VK_UUID_SIZE] u8;
    deviceLUID                        : [VK_LUID_SIZE] u8;
    deviceNodeMask                    : u32;
    deviceLUIDValid                   : VkBool32;
    subgroupSize                      : u32;
    subgroupSupportedStages           : VkShaderStageFlags;
    subgroupSupportedOperations       : VkSubgroupFeatureFlags;
    subgroupQuadOperationsInAllStages : VkBool32;
    pointClippingBehavior             : VkPointClippingBehavior;
    maxMultiviewViewCount             : u32;
    maxMultiviewInstanceIndex         : u32;
    protectedNoFault                  : VkBool32;
    maxPerSetDescriptors              : u32;
    maxMemoryAllocationSize           : VkDeviceSize;
}

// Provided by VK_VERSION_1_2
VkPhysicalDeviceVulkan12Properties :: struct {
    sType                                                : VkStructureType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_PROPERTIES;
    pNext                                                : *void;
    driverID                                             : VkDriverId;
    driverName                                           : [VK_MAX_DRIVER_NAME_SIZE] u8;
    driverInfo                                           : [VK_MAX_DRIVER_INFO_SIZE] u8;
    conformanceVersion                                   : VkConformanceVersion;
    denormBehaviorIndependence                           : VkShaderFloatControlsIndependence;
    roundingModeIndependence                             : VkShaderFloatControlsIndependence;
    shaderSignedZeroInfNanPreserveFloat16                : VkBool32;
    shaderSignedZeroInfNanPreserveFloat32                : VkBool32;
    shaderSignedZeroInfNanPreserveFloat64                : VkBool32;
    shaderDenormPreserveFloat16                          : VkBool32;
    shaderDenormPreserveFloat32                          : VkBool32;
    shaderDenormPreserveFloat64                          : VkBool32;
    shaderDenormFlushToZeroFloat16                       : VkBool32;
    shaderDenormFlushToZeroFloat32                       : VkBool32;
    shaderDenormFlushToZeroFloat64                       : VkBool32;
    shaderRoundingModeRTEFloat16                         : VkBool32;
    shaderRoundingModeRTEFloat32                         : VkBool32;
    shaderRoundingModeRTEFloat64                         : VkBool32;
    shaderRoundingModeRTZFloat16                         : VkBool32;
    shaderRoundingModeRTZFloat32                         : VkBool32;
    shaderRoundingModeRTZFloat64                         : VkBool32;
    maxUpdateAfterBindDescriptorsInAllPools              : u32;
    shaderUniformBufferArrayNonUniformIndexingNative     : VkBool32;
    shaderSampledImageArrayNonUniformIndexingNative      : VkBool32;
    shaderStorageBufferArrayNonUniformIndexingNative     : VkBool32;
    shaderStorageImageArrayNonUniformIndexingNative      : VkBool32;
    shaderInputAttachmentArrayNonUniformIndexingNative   : VkBool32;
    robustBufferAccessUpdateAfterBind                    : VkBool32;
    quadDivergentImplicitLod                             : VkBool32;
    maxPerStageDescriptorUpdateAfterBindSamplers         : u32;
    maxPerStageDescriptorUpdateAfterBindUniformBuffers   : u32;
    maxPerStageDescriptorUpdateAfterBindStorageBuffers   : u32;
    maxPerStageDescriptorUpdateAfterBindSampledImages    : u32;
    maxPerStageDescriptorUpdateAfterBindStorageImages    : u32;
    maxPerStageDescriptorUpdateAfterBindInputAttachments : u32;
    maxPerStageUpdateAfterBindResources                  : u32;
    maxDescriptorSetUpdateAfterBindSamplers              : u32;
    maxDescriptorSetUpdateAfterBindUniformBuffers        : u32;
    maxDescriptorSetUpdateAfterBindUniformBuffersDynamic : u32;
    maxDescriptorSetUpdateAfterBindStorageBuffers        : u32;
    maxDescriptorSetUpdateAfterBindStorageBuffersDynamic : u32;
    maxDescriptorSetUpdateAfterBindSampledImages         : u32;
    maxDescriptorSetUpdateAfterBindStorageImages         : u32;
    maxDescriptorSetUpdateAfterBindInputAttachments      : u32;
    supportedDepthResolveModes                           : VkResolveModeFlags;
    supportedStencilResolveModes                         : VkResolveModeFlags;
    independentResolveNone                               : VkBool32;
    independentResolve                                   : VkBool32;
    filterMinmaxSingleComponentFormats                   : VkBool32;
    filterMinmaxImageComponentMapping                    : VkBool32;
    maxTimelineSemaphoreValueDifference                  : u64;
    framebufferIntegerColorSampleCounts                  : VkSampleCountFlags;
}

// Provided by VK_VERSION_1_1
VkQueueFamilyProperties2 :: struct {
    sType                 : VkStructureType = .VK_STRUCTURE_TYPE_QUEUE_FAMILY_PROPERTIES_2;
    pNext                 : *void;
    queueFamilyProperties : VkQueueFamilyProperties;
}

// Provided by VK_VERSION_1_0
VkPhysicalDeviceFeatures :: struct {
    robustBufferAccess                      : VkBool32;
    fullDrawIndexUint32                     : VkBool32;
    imageCubeArray                          : VkBool32;
    independentBlend                        : VkBool32;
    geometryShader                          : VkBool32;
    tessellationShader                      : VkBool32;
    sampleRateShading                       : VkBool32;
    dualSrcBlend                            : VkBool32;
    logicOp                                 : VkBool32;
    multiDrawIndirect                       : VkBool32;
    drawIndirectFirstInstance               : VkBool32;
    depthClamp                              : VkBool32;
    depthBiasClamp                          : VkBool32;
    fillModeNonSolid                        : VkBool32;
    depthBounds                             : VkBool32;
    wideLines                               : VkBool32;
    largePoints                             : VkBool32;
    alphaToOne                              : VkBool32;
    multiViewport                           : VkBool32;
    samplerAnisotropy                       : VkBool32;
    textureCompressionETC2                  : VkBool32;
    textureCompressionASTC_LDR              : VkBool32;
    textureCompressionBC                    : VkBool32;
    occlusionQueryPrecise                   : VkBool32;
    pipelineStatisticsQuery                 : VkBool32;
    vertexPipelineStoresAndAtomics          : VkBool32;
    fragmentStoresAndAtomics                : VkBool32;
    shaderTessellationAndGeometryPointSize  : VkBool32;
    shaderImageGatherExtended               : VkBool32;
    shaderStorageImageExtendedFormats       : VkBool32;
    shaderStorageImageMultisample           : VkBool32;
    shaderStorageImageReadWithoutFormat     : VkBool32;
    shaderStorageImageWriteWithoutFormat    : VkBool32;
    shaderUniformBufferArrayDynamicIndexing : VkBool32;
    shaderSampledImageArrayDynamicIndexing  : VkBool32;
    shaderStorageBufferArrayDynamicIndexing : VkBool32;
    shaderStorageImageArrayDynamicIndexing  : VkBool32;
    shaderClipDistance                      : VkBool32;
    shaderCullDistance                      : VkBool32;
    shaderFloat64                           : VkBool32;
    shaderInt64                             : VkBool32;
    shaderInt16                             : VkBool32;
    shaderResourceResidency                 : VkBool32;
    shaderResourceMinLod                    : VkBool32;
    sparseBinding                           : VkBool32;
    sparseResidencyBuffer                   : VkBool32;
    sparseResidencyImage2D                  : VkBool32;
    sparseResidencyImage3D                  : VkBool32;
    sparseResidency2Samples                 : VkBool32;
    sparseResidency4Samples                 : VkBool32;
    sparseResidency8Samples                 : VkBool32;
    sparseResidency16Samples                : VkBool32;
    sparseResidencyAliased                  : VkBool32;
    variableMultisampleRate                 : VkBool32;
    inheritedQueries                        : VkBool32;
}

// Provided by VK_VERSION_1_1
VkPhysicalDeviceFeatures2 :: struct {
    sType    : VkStructureType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2;
    pNext    : *void;
    features : VkPhysicalDeviceFeatures;
}

// Provided by VK_VERSION_1_2
VkPhysicalDeviceVulkan11Features :: struct {
    sType                              : VkStructureType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES;
    pNext                              : *void;
    storageBuffer16BitAccess           : VkBool32;
    uniformAndStorageBuffer16BitAccess : VkBool32;
    storagePushConstant16              : VkBool32;
    storageInputOutput16               : VkBool32;
    multiview                          : VkBool32;
    multiviewGeometryShader            : VkBool32;
    multiviewTessellationShader        : VkBool32;
    variablePointersStorageBuffer      : VkBool32;
    variablePointers                   : VkBool32;
    protectedMemory                    : VkBool32;
    samplerYcbcrConversion             : VkBool32;
    shaderDrawParameters               : VkBool32;
}

// Provided by VK_VERSION_1_2
VkPhysicalDeviceVulkan12Features :: struct {
    sType                                              : VkStructureType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES;
    pNext                                              : *void;
    samplerMirrorClampToEdge                           : VkBool32;
    drawIndirectCount                                  : VkBool32;
    storageBuffer8BitAccess                            : VkBool32;
    uniformAndStorageBuffer8BitAccess                  : VkBool32;
    storagePushConstant8                               : VkBool32;
    shaderBufferInt64Atomics                           : VkBool32;
    shaderSharedInt64Atomics                           : VkBool32;
    shaderFloat16                                      : VkBool32;
    shaderInt8                                         : VkBool32;
    descriptorIndexing                                 : VkBool32;
    shaderInputAttachmentArrayDynamicIndexing          : VkBool32;
    shaderUniformTexelBufferArrayDynamicIndexing       : VkBool32;
    shaderStorageTexelBufferArrayDynamicIndexing       : VkBool32;
    shaderUniformBufferArrayNonUniformIndexing         : VkBool32;
    shaderSampledImageArrayNonUniformIndexing          : VkBool32;
    shaderStorageBufferArrayNonUniformIndexing         : VkBool32;
    shaderStorageImageArrayNonUniformIndexing          : VkBool32;
    shaderInputAttachmentArrayNonUniformIndexing       : VkBool32;
    shaderUniformTexelBufferArrayNonUniformIndexing    : VkBool32;
    shaderStorageTexelBufferArrayNonUniformIndexing    : VkBool32;
    descriptorBindingUniformBufferUpdateAfterBind      : VkBool32;
    descriptorBindingSampledImageUpdateAfterBind       : VkBool32;
    descriptorBindingStorageImageUpdateAfterBind       : VkBool32;
    descriptorBindingStorageBufferUpdateAfterBind      : VkBool32;
    descriptorBindingUniformTexelBufferUpdateAfterBind : VkBool32;
    descriptorBindingStorageTexelBufferUpdateAfterBind : VkBool32;
    descriptorBindingUpdateUnusedWhilePending          : VkBool32;
    descriptorBindingPartiallyBound                    : VkBool32;
    descriptorBindingVariableDescriptorCount           : VkBool32;
    runtimeDescriptorArray                             : VkBool32;
    samplerFilterMinmax                                : VkBool32;
    scalarBlockLayout                                  : VkBool32;
    imagelessFramebuffer                               : VkBool32;
    uniformBufferStandardLayout                        : VkBool32;
    shaderSubgroupExtendedTypes                        : VkBool32;
    separateDepthStencilLayouts                        : VkBool32;
    hostQueryReset                                     : VkBool32;
    timelineSemaphore                                  : VkBool32;
    bufferDeviceAddress                                : VkBool32;
    bufferDeviceAddressCaptureReplay                   : VkBool32;
    bufferDeviceAddressMultiDevice                     : VkBool32;
    vulkanMemoryModel                                  : VkBool32;
    vulkanMemoryModelDeviceScope                       : VkBool32;
    vulkanMemoryModelAvailabilityVisibilityChains      : VkBool32;
    shaderOutputViewportIndex                          : VkBool32;
    shaderOutputLayer                                  : VkBool32;
    subgroupBroadcastDynamicId                         : VkBool32;
}

// Provided by VK_VERSION_1_3
VkPhysicalDeviceVulkan13Features :: struct {
    sType                                              : VkStructureType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES;
    pNext                                              : *void;
    robustImageAccess                                  : VkBool32;
    inlineUniformBlock                                 : VkBool32;
    descriptorBindingInlineUniformBlockUpdateAfterBind : VkBool32;
    pipelineCreationCacheControl                       : VkBool32;
    privateData                                        : VkBool32;
    shaderDemoteToHelperInvocation                     : VkBool32;
    shaderTerminateInvocation                          : VkBool32;
    subgroupSizeControl                                : VkBool32;
    computeFullSubgroups                               : VkBool32;
    synchronization2                                   : VkBool32;
    textureCompressionASTC_HDR                         : VkBool32;
    shaderZeroInitializeWorkgroupMemory                : VkBool32;
    dynamicRendering                                   : VkBool32;
    shaderIntegerDotProduct                            : VkBool32;
    maintenance4                                       : VkBool32;
}

// Provided by VK_VERSION_1_3
VkPhysicalDeviceDynamicRenderingFeatures :: struct {
    sType            : VkStructureType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DYNAMIC_RENDERING_FEATURES;
    pNext            : *void;
    dynamicRendering : VkBool32;
}

// Provided by VK_VERSION_1_0
vkEnumeratePhysicalDevices :: (
    instance             : VkInstance,
    pPhysicalDeviceCount : *u32,
    pPhysicalDevices     : *VkPhysicalDevice
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_1
vkGetPhysicalDeviceProperties2 :: (
    physicalDevice : VkPhysicalDevice,
    pProperties    : *VkPhysicalDeviceProperties2
) #foreign vulkan;

// Provided by VK_VERSION_1_0
vkGetPhysicalDeviceQueueFamilyProperties :: (
    physicalDevice            : VkPhysicalDevice,
    pQueueFamilyPropertyCount : *u32,
    pQueueFamilyProperties    : *VkQueueFamilyProperties
) #foreign vulkan;

// Provided by VK_VERSION_1_1
vkGetPhysicalDeviceQueueFamilyProperties2 :: (
    physicalDevice            : VkPhysicalDevice,
    pQueueFamilyPropertyCount : *u32,
    pQueueFamilyProperties    : *VkQueueFamilyProperties2
) #foreign vulkan;

// Provided by VK_VERSION_1_1
vkGetPhysicalDeviceFeatures2 :: (
    physicalDevice : VkPhysicalDevice,
    pFeatures      : *VkPhysicalDeviceFeatures2
) #foreign vulkan;

//
// Provided by VK_EXT_descriptor_buffer
//

VkPhysicalDeviceDescriptorBufferFeaturesEXT :: struct {
    sType                              : VkStructureType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DESCRIPTOR_BUFFER_FEATURES_EXT;
    pNext                              : *void;
    descriptorBuffer                   : VkBool32;
    descriptorBufferCaptureReplay      : VkBool32;
    descriptorBufferImageLayoutIgnored : VkBool32;
    descriptorBufferPushDescriptors    : VkBool32;
}

VkPhysicalDeviceDescriptorBufferPropertiesEXT :: struct {
    sType                                                : VkStructureType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DESCRIPTOR_BUFFER_PROPERTIES_EXT;
    pNext                                                : *void;
    combinedImageSamplerDescriptorSingleArray            : VkBool32;
    bufferlessPushDescriptors                            : VkBool32;
    allowSamplerImageViewPostSubmitCreation              : VkBool32;
    descriptorBufferOffsetAlignment                      : VkDeviceSize;
    maxDescriptorBufferBindings                          : u32;
    maxResourceDescriptorBufferBindings                  : u32;
    maxSamplerDescriptorBufferBindings                   : u32;
    maxEmbeddedImmutableSamplerBindings                  : u32;
    maxEmbeddedImmutableSamplers                         : u32;
    bufferCaptureReplayDescriptorDataSize                : size_t;
    imageCaptureReplayDescriptorDataSize                 : size_t;
    imageViewCaptureReplayDescriptorDataSize             : size_t;
    samplerCaptureReplayDescriptorDataSize               : size_t;
    accelerationStructureCaptureReplayDescriptorDataSize : size_t;
    samplerDescriptorSize                                : size_t;
    combinedImageSamplerDescriptorSize                   : size_t;
    sampledImageDescriptorSize                           : size_t;
    storageImageDescriptorSize                           : size_t;
    uniformTexelBufferDescriptorSize                     : size_t;
    robustUniformTexelBufferDescriptorSize               : size_t;
    storageTexelBufferDescriptorSize                     : size_t;
    robustStorageTexelBufferDescriptorSize               : size_t;
    uniformBufferDescriptorSize                          : size_t;
    robustUniformBufferDescriptorSize                    : size_t;
    storageBufferDescriptorSize                          : size_t;
    robustStorageBufferDescriptorSize                    : size_t;
    inputAttachmentDescriptorSize                        : size_t;
    accelerationStructureDescriptorSize                  : size_t;
    maxSamplerDescriptorBufferRange                      : VkDeviceSize;
    maxResourceDescriptorBufferRange                     : VkDeviceSize;
    samplerDescriptorBufferAddressSpaceSize              : VkDeviceSize;
    resourceDescriptorBufferAddressSpaceSize             : VkDeviceSize;
    descriptorBufferAddressSpaceSize                     : VkDeviceSize;
}