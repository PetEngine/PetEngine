#scope_export

size_t   :: u64; // We target only 64-bit systems, so... whatever.
VkBool32 :: u32;

VK_TRUE  : VkBool32 : 1;
VK_FALSE : VkBool32 : 0;

VK_NULL_HANDLE :: null;

VK_HANDLE                  :: *void;
VK_NON_DISPATCHABLE_HANDLE :: *void;

VkEnum  :: s32;
VkFlags :: u32;

// Provided by VK_VERSION_1_0
VK_API_VERSION_VARIANT :: inline (version : u32) -> u32 #no_context {
    return version >> 29;
}

// Provided by VK_VERSION_1_0
VK_API_VERSION_MAJOR :: inline (version : u32) -> u32 #no_context {
    return (version >> 22) & 0x7F;
}

// Provided by VK_VERSION_1_0
VK_API_VERSION_MINOR :: inline (version : u32) -> u32 #no_context {
    return (version >> 12) & 0x3FF;
}

// Provided by VK_VERSION_1_0
VK_API_VERSION_PATCH :: inline (version : u32) -> u32 #no_context {
    return version & 0xFFF;
}

// Provided by VK_VERSION_1_0
VK_MAKE_API_VERSION :: inline (variant : u32, major : u32, minor : u32, patch : u32) -> u32 #no_context {
    return variant << 29 | major << 22 | minor << 12 | patch;
}

// Provided by VK_VERSION_1_0
// Vulkan 1.0 version number
VK_API_VERSION_1_0 :: #run VK_MAKE_API_VERSION(0, 1, 0, 0); // Patch version should always be set to 0

// Provided by VK_VERSION_1_1
// Vulkan 1.1 version number
VK_API_VERSION_1_1 :: #run VK_MAKE_API_VERSION(0, 1, 1, 0); // Patch version should always be set to 0

// Provided by VK_VERSION_1_2
// Vulkan 1.2 version number
VK_API_VERSION_1_2 :: #run VK_MAKE_API_VERSION(0, 1, 2, 0); // Patch version should always be set to 0

// Provided by VK_VERSION_1_3
// Vulkan 1.3 version number
VK_API_VERSION_1_3 :: #run VK_MAKE_API_VERSION(0, 1, 3, 0); // Patch version should always be set to 0

// Provided by VK_VERSION_1_0
VkResult :: enum VkEnum {
    VK_SUCCESS                                            :: 0;
    VK_NOT_READY                                          :: 1;
    VK_TIMEOUT                                            :: 2;
    VK_EVENT_SET                                          :: 3;
    VK_EVENT_RESET                                        :: 4;
    VK_INCOMPLETE                                         :: 5;
    VK_ERROR_OUT_OF_HOST_MEMORY                           :: -1;
    VK_ERROR_OUT_OF_DEVICE_MEMORY                         :: -2;
    VK_ERROR_INITIALIZATION_FAILED                        :: -3;
    VK_ERROR_DEVICE_LOST                                  :: -4;
    VK_ERROR_MEMORY_MAP_FAILED                            :: -5;
    VK_ERROR_LAYER_NOT_PRESENT                            :: -6;
    VK_ERROR_EXTENSION_NOT_PRESENT                        :: -7;
    VK_ERROR_FEATURE_NOT_PRESENT                          :: -8;
    VK_ERROR_INCOMPATIBLE_DRIVER                          :: -9;
    VK_ERROR_TOO_MANY_OBJECTS                             :: -10;
    VK_ERROR_FORMAT_NOT_SUPPORTED                         :: -11;
    VK_ERROR_FRAGMENTED_POOL                              :: -12;
    VK_ERROR_UNKNOWN                                      :: -13;
    // Provided by VK_VERSION_1_1
    VK_ERROR_OUT_OF_POOL_MEMORY                           :: -1000069000;
    // Provided by VK_VERSION_1_1
    VK_ERROR_INVALID_EXTERNAL_HANDLE                      :: -1000072003;
    // Provided by VK_VERSION_1_2
    VK_ERROR_FRAGMENTATION                                :: -1000161000;
    // Provided by VK_VERSION_1_2
    VK_ERROR_INVALID_OPAQUE_CAPTURE_ADDRESS               :: -1000257000;
    // Provided by VK_VERSION_1_3
    VK_PIPELINE_COMPILE_REQUIRED                          :: 1000297000;
    // Provided by VK_KHR_surface
    VK_ERROR_SURFACE_LOST_KHR                             :: -1000000000;
    // Provided by VK_KHR_surface
    VK_ERROR_NATIVE_WINDOW_IN_USE_KHR                     :: -1000000001;
    // Provided by VK_KHR_swapchain
    VK_SUBOPTIMAL_KHR                                     :: 1000001003;
    // Provided by VK_KHR_swapchain
    VK_ERROR_OUT_OF_DATE_KHR                              :: -1000001004;
    // Provided by VK_KHR_display_swapchain
    VK_ERROR_INCOMPATIBLE_DISPLAY_KHR                     :: -1000003001;
    // Provided by VK_EXT_debug_report
    VK_ERROR_VALIDATION_FAILED_EXT                        :: -1000011001;
    // Provided by VK_NV_glsl_shader
    VK_ERROR_INVALID_SHADER_NV                            :: -1000012000;
    // Provided by VK_EXT_image_drm_format_modifier
    VK_ERROR_INVALID_DRM_FORMAT_MODIFIER_PLANE_LAYOUT_EXT :: -1000158000;
    // Provided by VK_KHR_global_priority
    VK_ERROR_NOT_PERMITTED_KHR                            :: -1000174001;
    // Provided by VK_EXT_full_screen_exclusive
    VK_ERROR_FULL_SCREEN_EXCLUSIVE_MODE_LOST_EXT          :: -1000255000;
    // Provided by VK_KHR_deferred_host_operations
    VK_THREAD_IDLE_KHR                                    :: 1000268000;
    // Provided by VK_KHR_deferred_host_operations
    VK_THREAD_DONE_KHR                                    :: 1000268001;
    // Provided by VK_KHR_deferred_host_operations
    VK_OPERATION_DEFERRED_KHR                             :: 1000268002;
    // Provided by VK_KHR_deferred_host_operations
    VK_OPERATION_NOT_DEFERRED_KHR                         :: 1000268003;
    // Provided by VK_EXT_image_compression_control
    VK_ERROR_COMPRESSION_EXHAUSTED_EXT                    :: -1000338000;
    // Provided by VK_EXT_shader_object
    VK_ERROR_INCOMPATIBLE_SHADER_BINARY_EXT               :: 1000482000;
    // Provided by VK_KHR_maintenance1
    VK_ERROR_OUT_OF_POOL_MEMORY_KHR                       :: VK_ERROR_OUT_OF_POOL_MEMORY;
    // Provided by VK_KHR_external_memory
    VK_ERROR_INVALID_EXTERNAL_HANDLE_KHR                  :: VK_ERROR_INVALID_EXTERNAL_HANDLE;
    // Provided by VK_EXT_descriptor_indexing
    VK_ERROR_FRAGMENTATION_EXT                            :: VK_ERROR_FRAGMENTATION;
    // Provided by VK_EXT_global_priority
    VK_ERROR_NOT_PERMITTED_EXT                            :: VK_ERROR_NOT_PERMITTED_KHR;
    // Provided by VK_EXT_buffer_device_address
    VK_ERROR_INVALID_DEVICE_ADDRESS_EXT                   :: VK_ERROR_INVALID_OPAQUE_CAPTURE_ADDRESS;
    // Provided by VK_KHR_buffer_device_address
    VK_ERROR_INVALID_OPAQUE_CAPTURE_ADDRESS_KHR           :: VK_ERROR_INVALID_OPAQUE_CAPTURE_ADDRESS;
    // Provided by VK_EXT_pipeline_creation_cache_control
    VK_PIPELINE_COMPILE_REQUIRED_EXT                      :: VK_PIPELINE_COMPILE_REQUIRED;
    // Provided by VK_EXT_pipeline_creation_cache_control
    VK_ERROR_PIPELINE_COMPILE_REQUIRED_EXT                :: VK_PIPELINE_COMPILE_REQUIRED;
}

// Provided by VK_VERSION_1_0
VkStructureType :: enum VkEnum {
    VK_STRUCTURE_TYPE_APPLICATION_INFO                        :: 0;
    VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO                    :: 1;
    VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO                :: 2;
    VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO                      :: 3;
    VK_STRUCTURE_TYPE_SUBMIT_INFO                             :: 4;
    VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO                   :: 9;
    VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO                :: 39;
    VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO            :: 40;
    VK_STRUCTURE_TYPE_COMMAND_BUFFER_INHERITANCE_INFO         :: 41;
    VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO               :: 42;
    // Provided by VK_VERSION_1_1
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2            :: 1000059001;
    // Provided by VK_VERSION_1_1
    VK_STRUCTURE_TYPE_QUEUE_FAMILY_PROPERTIES_2               :: 1000059005;
    // Provided by VK_VERSION_1_1
    VK_STRUCTURE_TYPE_DEVICE_QUEUE_INFO_2                     :: 1000145003;
    // Provided by VK_VERSION_1_2
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DRIVER_PROPERTIES       :: 1000196000;
    // Provided by VK_VERSION_1_2
    VK_STRUCTURE_TYPE_SEMAPHORE_WAIT_INFO                     :: 1000207004;

    // Provided by VK_EXT_debug_utils
    VK_STRUCTURE_TYPE_DEBUG_UTILS_OBJECT_NAME_INFO_EXT        :: 1000128000;
    VK_STRUCTURE_TYPE_DEBUG_UTILS_OBJECT_TAG_INFO_EXT         :: 1000128001;
    VK_STRUCTURE_TYPE_DEBUG_UTILS_LABEL_EXT                   :: 1000128002;
    VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CALLBACK_DATA_EXT :: 1000128003;
    VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT   :: 1000128004;

#if OS == .WINDOWS {
    // Provided by VK_KHR_win32_surface
    VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR           :: 1000009000;
}

    // Provided by VK_KHR_swapchain
    VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR               :: 1000001000;
    VK_STRUCTURE_TYPE_PRESENT_INFO_KHR                        :: 1000001001;
    VK_STRUCTURE_TYPE_ACQUIRE_NEXT_IMAGE_INFO_KHR             :: 1000060010;
}

// Provided by VK_VERSION_1_0
VkObjectType :: enum VkEnum {
    VK_OBJECT_TYPE_UNKNOWN                         :: 0;
    VK_OBJECT_TYPE_INSTANCE                        :: 1;
    VK_OBJECT_TYPE_PHYSICAL_DEVICE                 :: 2;
    VK_OBJECT_TYPE_DEVICE                          :: 3;
    VK_OBJECT_TYPE_QUEUE                           :: 4;
    VK_OBJECT_TYPE_SEMAPHORE                       :: 5;
    VK_OBJECT_TYPE_COMMAND_BUFFER                  :: 6;
    VK_OBJECT_TYPE_FENCE                           :: 7;
    VK_OBJECT_TYPE_DEVICE_MEMORY                   :: 8;
    VK_OBJECT_TYPE_BUFFER                          :: 9;
    VK_OBJECT_TYPE_IMAGE                           :: 10;
    VK_OBJECT_TYPE_EVENT                           :: 11;
    VK_OBJECT_TYPE_QUERY_POOL                      :: 12;
    VK_OBJECT_TYPE_BUFFER_VIEW                     :: 13;
    VK_OBJECT_TYPE_IMAGE_VIEW                      :: 14;
    VK_OBJECT_TYPE_SHADER_MODULE                   :: 15;
    VK_OBJECT_TYPE_PIPELINE_CACHE                  :: 16;
    VK_OBJECT_TYPE_PIPELINE_LAYOUT                 :: 17;
    VK_OBJECT_TYPE_RENDER_PASS                     :: 18;
    VK_OBJECT_TYPE_PIPELINE                        :: 19;
    VK_OBJECT_TYPE_DESCRIPTOR_SET_LAYOUT           :: 20;
    VK_OBJECT_TYPE_SAMPLER                         :: 21;
    VK_OBJECT_TYPE_DESCRIPTOR_POOL                 :: 22;
    VK_OBJECT_TYPE_DESCRIPTOR_SET                  :: 23;
    VK_OBJECT_TYPE_FRAMEBUFFER                     :: 24;
    VK_OBJECT_TYPE_COMMAND_POOL                    :: 25;
    // Provided by VK_VERSION_1_1
    VK_OBJECT_TYPE_SAMPLER_YCBCR_CONVERSION        :: 1000156000;
    // Provided by VK_VERSION_1_1
    VK_OBJECT_TYPE_DESCRIPTOR_UPDATE_TEMPLATE      :: 1000085000;
    // Provided by VK_VERSION_1_3
    VK_OBJECT_TYPE_PRIVATE_DATA_SLOT               :: 1000295000;
    // Provided by VK_KHR_surface
    VK_OBJECT_TYPE_SURFACE_KHR                     :: 1000000000;
    // Provided by VK_KHR_swapchain
    VK_OBJECT_TYPE_SWAPCHAIN_KHR                   :: 1000001000;
    // Provided by VK_KHR_display
    VK_OBJECT_TYPE_DISPLAY_KHR                     :: 1000002000;
    // Provided by VK_KHR_display
    VK_OBJECT_TYPE_DISPLAY_MODE_KHR                :: 1000002001;
    // Provided by VK_EXT_debug_report
    VK_OBJECT_TYPE_DEBUG_REPORT_CALLBACK_EXT       :: 1000011000;
    // Provided by VK_KHR_video_queue
    VK_OBJECT_TYPE_VIDEO_SESSION_KHR               :: 1000023000;
    // Provided by VK_KHR_video_queue
    VK_OBJECT_TYPE_VIDEO_SESSION_PARAMETERS_KHR    :: 1000023001;
    // Provided by VK_NVX_binary_import
    VK_OBJECT_TYPE_CU_MODULE_NVX                   :: 1000029000;
    // Provided by VK_NVX_binary_import
    VK_OBJECT_TYPE_CU_FUNCTION_NVX                 :: 1000029001;
    // Provided by VK_EXT_debug_utils
    VK_OBJECT_TYPE_DEBUG_UTILS_MESSENGER_EXT       :: 1000128000;
    // Provided by VK_KHR_acceleration_structure
    VK_OBJECT_TYPE_ACCELERATION_STRUCTURE_KHR      :: 1000150000;
    // Provided by VK_EXT_validation_cache
    VK_OBJECT_TYPE_VALIDATION_CACHE_EXT            :: 1000160000;
    // Provided by VK_NV_ray_tracing
    VK_OBJECT_TYPE_ACCELERATION_STRUCTURE_NV       :: 1000165000;
    // Provided by VK_INTEL_performance_query
    VK_OBJECT_TYPE_PERFORMANCE_CONFIGURATION_INTEL :: 1000210000;
    // Provided by VK_KHR_deferred_host_operations
    VK_OBJECT_TYPE_DEFERRED_OPERATION_KHR          :: 1000268000;
    // Provided by VK_NV_device_generated_commands
    VK_OBJECT_TYPE_INDIRECT_COMMANDS_LAYOUT_NV     :: 1000277000;
    // Provided by VK_FUCHSIA_buffer_collection
    VK_OBJECT_TYPE_BUFFER_COLLECTION_FUCHSIA       :: 1000366000;
    // Provided by VK_EXT_opacity_micromap
    VK_OBJECT_TYPE_MICROMAP_EXT                    :: 1000396000;
    // Provided by VK_NV_optical_flow
    VK_OBJECT_TYPE_OPTICAL_FLOW_SESSION_NV         :: 1000464000;
    // Provided by VK_EXT_shader_object
    VK_OBJECT_TYPE_SHADER_EXT                      :: 1000482000;
    // Provided by VK_KHR_descriptor_update_template
    VK_OBJECT_TYPE_DESCRIPTOR_UPDATE_TEMPLATE_KHR  :: VK_OBJECT_TYPE_DESCRIPTOR_UPDATE_TEMPLATE;
    // Provided by VK_KHR_sampler_ycbcr_conversion
    VK_OBJECT_TYPE_SAMPLER_YCBCR_CONVERSION_KHR    :: VK_OBJECT_TYPE_SAMPLER_YCBCR_CONVERSION;
    // Provided by VK_EXT_private_data
    VK_OBJECT_TYPE_PRIVATE_DATA_SLOT_EXT           :: VK_OBJECT_TYPE_PRIVATE_DATA_SLOT;
}

// Provided by VK_VERSION_1_0
VkExtent2D :: struct {
    width  : u32;
    height : u32;
}

// Provided by VK_VERSION_1_0
VkExtent3D :: struct {
    width  : u32;
    height : u32;
    depth  : u32;
}

// @Cleanup: Move to their own files
VK_ATTACHMENT_UNUSED              : u32 : 0xFFFF_FFFF;
VK_LOD_CLAMP_NONE                 : f32 : 1000.0;
VK_REMAINING_ARRAY_LAYERS         : u32 : 0xFFFF_FFFF;
VK_REMAINING_MIP_LEVELS           : u32 : 0xFFFF_FFFF;
VK_SUBPASS_EXTERNAL               : u32 : 0xFFFF_FFFF;
VK_WHOLE_SIZE                     : u64 : 0xFFFF_FFFF_FFFF_FFFF;
VK_MAX_MEMORY_TYPES               : u32 : 32;
VK_MAX_MEMORY_HEAPS               : u32 : 16;

// @Cleanup: Move to their own files
VkFence       :: VK_NON_DISPATCHABLE_HANDLE;
VkImage       :: VK_NON_DISPATCHABLE_HANDLE;
VkRenderPass  :: VK_NON_DISPATCHABLE_HANDLE;
VkFramebuffer :: VK_NON_DISPATCHABLE_HANDLE;

// Provided by VK_VERSION_1_0
VkImageUsageFlags :: enum_flags VkFlags { // @Cleanup: move to image file
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

// Provided by VK_VERSION_1_0
VkFormat :: enum VkEnum { // @Cleanup: move to image file
    VK_FORMAT_UNDEFINED                :: 0;
    VK_FORMAT_R8G8B8A8_UNORM           :: 37;
    VK_FORMAT_B8G8R8A8_UNORM           :: 44;
    VK_FORMAT_B8G8R8A8_SRGB            :: 50;
    VK_FORMAT_A2B10G10R10_UNORM_PACK32 :: 64;
}

#scope_module

#load "instance.jai";
#load "physcial_device.jai";
#load "device.jai";
#load "queue.jai";
#load "semaphore.jai";
#load "command_pool.jai";
#load "command_buffer.jai";

#if OS == .WINDOWS {
    vulkan :: #system_library "vulkan-1";
} else {
    notImplemented();
}
