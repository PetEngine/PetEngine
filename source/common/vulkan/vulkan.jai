#scope_export

size_t   :: u64; // We target only 64-bit systems, so... whatever.
VkBool32 :: u32;

VK_TRUE  : VkBool32 : 1;
VK_FALSE : VkBool32 : 0;

VK_NULL_HANDLE :: null;

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
VkResult :: enum VkEnum #specified {
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
VkStructureType :: enum VkEnum #specified {
    VK_STRUCTURE_TYPE_APPLICATION_INFO                           :: 0;
    VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO                       :: 1;
    VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO                   :: 2;
    VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO                         :: 3;
    VK_STRUCTURE_TYPE_SUBMIT_INFO                                :: 4;
    VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO                       :: 5;
    VK_STRUCTURE_TYPE_FENCE_CREATE_INFO                          :: 8;
    VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO                      :: 9;
    VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO                         :: 12;
    VK_STRUCTURE_TYPE_BUFFER_VIEW_CREATE_INFO                    :: 13;
    VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO                          :: 14;
    VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO                     :: 15;
    VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO                  :: 16;
    VK_STRUCTURE_TYPE_PIPELINE_CACHE_CREATE_INFO                 :: 17;
    VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO          :: 18;
    VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO    :: 19;
    VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO  :: 20;
    VK_STRUCTURE_TYPE_PIPELINE_TESSELLATION_STATE_CREATE_INFO    :: 21;
    VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO        :: 22;
    VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO   :: 23;
    VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO     :: 24;
    VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO   :: 25;
    VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO     :: 26;
    VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO         :: 27;
    VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO              :: 28;
    VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO                :: 30;
    VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO          :: 32;
    VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO                :: 33;
    VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO               :: 34;
    VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET                       :: 35;
    VK_STRUCTURE_TYPE_COPY_DESCRIPTOR_SET                        :: 36;
    VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO                   :: 39;
    VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO               :: 40;
    VK_STRUCTURE_TYPE_COMMAND_BUFFER_INHERITANCE_INFO            :: 41;
    VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO                  :: 42;
    VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER                      :: 44;
    VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER                       :: 45;
    VK_STRUCTURE_TYPE_MEMORY_BARRIER                             :: 46;
    // Provided by VK_VERSION_1_2
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES        :: 49;
    // Provided by VK_VERSION_1_2
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_PROPERTIES      :: 50;
    // Provided by VK_VERSION_1_2
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES        :: 51;
    // Provided by VK_VERSION_1_2
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_PROPERTIES      :: 52;
    // Provided by VK_VERSION_1_3
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES        :: 53;
    // Provided by VK_VERSION_1_3
    VK_STRUCTURE_TYPE_RENDERING_INFO                             :: 1000044000;
    // Provided by VK_VERSION_1_3
    VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO                  :: 1000044001;
    // Provided by VK_VERSION_1_3
    VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO             :: 1000044002;
    // Provided by VK_VERSION_1_3
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DYNAMIC_RENDERING_FEATURES :: 1000044003;
    // Provided by VK_VERSION_1_1
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2                 :: 1000059000;
    // Provided by VK_VERSION_1_1
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2               :: 1000059001;
    // Provided by VK_VERSION_1_1
    VK_STRUCTURE_TYPE_IMAGE_FORMAT_PROPERTIES_2                  :: 1000059003;
    // Provided by VK_VERSION_1_1
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_FORMAT_INFO_2        :: 1000059004;
    // Provided by VK_VERSION_1_1
    VK_STRUCTURE_TYPE_QUEUE_FAMILY_PROPERTIES_2                  :: 1000059005;
    // Provided by VK_VERSION_1_1
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MEMORY_PROPERTIES_2        :: 1000059006;
    // Provided by VK_VERSION_1_1
    VK_STRUCTURE_TYPE_DEVICE_QUEUE_INFO_2                        :: 1000145003;
    // Provided by VK_VERSION_1_1
    VK_STRUCTURE_TYPE_BUFFER_MEMORY_REQUIREMENTS_INFO_2          :: 1000146000;
    // Provided by VK_VERSION_1_1
    VK_STRUCTURE_TYPE_IMAGE_MEMORY_REQUIREMENTS_INFO_2           :: 1000146001;
    // Provided by VK_VERSION_1_1
    VK_STRUCTURE_TYPE_MEMORY_REQUIREMENTS_2                      :: 1000146003;
    // Provided by VK_VERSION_1_1
    VK_STRUCTURE_TYPE_BIND_BUFFER_MEMORY_INFO                    :: 1000157000;
    // Provided by VK_VERSION_1_1
    VK_STRUCTURE_TYPE_BIND_IMAGE_MEMORY_INFO                     :: 1000157001;
    // Provided by VK_VERSION_1_1
    VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_SUPPORT              :: 1000168001;
    // Provided by VK_VERSION_1_2
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DRIVER_PROPERTIES          :: 1000196000;
    // Provided by VK_VERSION_1_2
    VK_STRUCTURE_TYPE_SEMAPHORE_TYPE_CREATE_INFO                 :: 1000207002;
    // Provided by VK_VERSION_1_2
    VK_STRUCTURE_TYPE_SEMAPHORE_WAIT_INFO                        :: 1000207004;
    // Provided by VK_VERSION_1_3
    VK_STRUCTURE_TYPE_COPY_BUFFER_INFO_2                         :: 1000337000;
    // Provided by VK_VERSION_1_3
    VK_STRUCTURE_TYPE_BUFFER_COPY_2                              :: 1000337006;

    // Provided by VK_EXT_debug_utils
    VK_STRUCTURE_TYPE_DEBUG_UTILS_OBJECT_NAME_INFO_EXT           :: 1000128000;
    VK_STRUCTURE_TYPE_DEBUG_UTILS_OBJECT_TAG_INFO_EXT            :: 1000128001;
    VK_STRUCTURE_TYPE_DEBUG_UTILS_LABEL_EXT                      :: 1000128002;
    VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CALLBACK_DATA_EXT    :: 1000128003;
    VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT      :: 1000128004;

#if OS == .WINDOWS {
    // Provided by VK_KHR_win32_surface
    VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR              :: 1000009000;
}

    // Provided by VK_KHR_swapchain
    VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR                  :: 1000001000;
    VK_STRUCTURE_TYPE_PRESENT_INFO_KHR                           :: 1000001001;
    VK_STRUCTURE_TYPE_ACQUIRE_NEXT_IMAGE_INFO_KHR                :: 1000060010;

    // Provided by VK_EXT_validation_features
    VK_STRUCTURE_TYPE_VALIDATION_FEATURES_EXT                    :: 1000247000;
}

// Provided by VK_VERSION_1_0
VkObjectType :: enum VkEnum #specified {
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
VkOffset2D :: struct {
    x : s32;
    y : s32;
}

// Provided by VK_VERSION_1_0
VkOffset3D :: struct {
    x : s32;
    y : s32;
    z : s32;
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

// Provided by VK_VERSION_1_0
VkRect2D :: struct {
    offset : VkOffset2D;
    extent : VkExtent2D;
}

// Provided by VK_VERSION_1_0
VkMemoryRequirements :: struct {
    size           : VkDeviceSize;
    alignment      : VkDeviceSize;
    memoryTypeBits : u32;
}

// Provided by VK_VERSION_1_1
VkMemoryRequirements2 :: struct {
    sType              : VkStructureType = .VK_STRUCTURE_TYPE_MEMORY_REQUIREMENTS_2;
    pNext              : *void;
    memoryRequirements : VkMemoryRequirements;
}

// @Cleanup: Move to their own files
VK_ATTACHMENT_UNUSED : u32          : 0xFFFF_FFFF;
VK_SUBPASS_EXTERNAL  : u32          : 0xFFFF_FFFF;
VK_WHOLE_SIZE        : VkDeviceSize : 0xFFFF_FFFF_FFFF_FFFF;

// @Cleanup: Move to their own files
VkRenderPass  :: *VkRenderPass_T;  VkRenderPass_T  :: struct {}
VkFramebuffer :: *VkFramebuffer_T; VkFramebuffer_T :: struct {}
VkSampler     :: *VkSampler_T;     VkSampler_T     :: struct {}

#scope_module

#load "instance.jai";
#load "physcial_device.jai";
#load "device.jai";
#load "queue.jai";
#load "semaphore.jai";
#load "fence.jai";
#load "command_pool.jai";
#load "command_buffer.jai";
#load "device_memory.jai";
#load "image.jai";
#load "barriers.jai";
#load "pipeline.jai";
#load "buffer.jai";
#load "descriptor_set_layout.jai";
#load "descriptor_pool.jai";
#load "descriptor_set.jai";

#if OS == .WINDOWS {
    vulkan :: #library,system "vulkan-1";
} else {
    notImplemented();
}
