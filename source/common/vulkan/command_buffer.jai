#scope_export

// Provided by VK_VERSION_1_0
VkCommandBuffer :: VK_HANDLE;

// Provided by VK_VERSION_1_0
VkCommandBufferLevel :: enum VkEnum {
    VK_COMMAND_BUFFER_LEVEL_PRIMARY   :: 0;
    VK_COMMAND_BUFFER_LEVEL_SECONDARY :: 1;
}

// Provided by VK_VERSION_1_0
VkCommandBufferResetFlags :: enum_flags VkFlags {
    VK_COMMAND_BUFFER_RESET_RELEASE_RESOURCES_BIT :: 0x00000001;
}

// Provided by VK_VERSION_1_0
VkCommandBufferUsageFlags :: enum_flags VkFlags {
    VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT      :: 0x00000001;
    VK_COMMAND_BUFFER_USAGE_RENDER_PASS_CONTINUE_BIT :: 0x00000002;
    VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT     :: 0x00000004;
}

// Provided by VK_VERSION_1_0
VkQueryPipelineStatisticFlags :: enum_flags VkFlags {
    VK_QUERY_PIPELINE_STATISTIC_INPUT_ASSEMBLY_VERTICES_BIT                    :: 0x00000001;
    VK_QUERY_PIPELINE_STATISTIC_INPUT_ASSEMBLY_PRIMITIVES_BIT                  :: 0x00000002;
    VK_QUERY_PIPELINE_STATISTIC_VERTEX_SHADER_INVOCATIONS_BIT                  :: 0x00000004;
    VK_QUERY_PIPELINE_STATISTIC_GEOMETRY_SHADER_INVOCATIONS_BIT                :: 0x00000008;
    VK_QUERY_PIPELINE_STATISTIC_GEOMETRY_SHADER_PRIMITIVES_BIT                 :: 0x00000010;
    VK_QUERY_PIPELINE_STATISTIC_CLIPPING_INVOCATIONS_BIT                       :: 0x00000020;
    VK_QUERY_PIPELINE_STATISTIC_CLIPPING_PRIMITIVES_BIT                        :: 0x00000040;
    VK_QUERY_PIPELINE_STATISTIC_FRAGMENT_SHADER_INVOCATIONS_BIT                :: 0x00000080;
    VK_QUERY_PIPELINE_STATISTIC_TESSELLATION_CONTROL_SHADER_PATCHES_BIT        :: 0x00000100;
    VK_QUERY_PIPELINE_STATISTIC_TESSELLATION_EVALUATION_SHADER_INVOCATIONS_BIT :: 0x00000200;
    VK_QUERY_PIPELINE_STATISTIC_COMPUTE_SHADER_INVOCATIONS_BIT                 :: 0x00000400;
    // Provided by VK_EXT_mesh_shader
    VK_QUERY_PIPELINE_STATISTIC_TASK_SHADER_INVOCATIONS_BIT_EXT                :: 0x00000800;
    // Provided by VK_EXT_mesh_shader
    VK_QUERY_PIPELINE_STATISTIC_MESH_SHADER_INVOCATIONS_BIT_EXT                :: 0x00001000;
    // Provided by VK_HUAWEI_cluster_culling_shader
    VK_QUERY_PIPELINE_STATISTIC_CLUSTER_CULLING_SHADER_INVOCATIONS_BIT_HUAWEI  :: 0x00002000;
}

// Provided by VK_VERSION_1_0
VkPipelineStageFlags :: enum_flags VkFlags {
    VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT                          :: 0x00000001;
    VK_PIPELINE_STAGE_DRAW_INDIRECT_BIT                        :: 0x00000002;
    VK_PIPELINE_STAGE_VERTEX_INPUT_BIT                         :: 0x00000004;
    VK_PIPELINE_STAGE_VERTEX_SHADER_BIT                        :: 0x00000008;
    VK_PIPELINE_STAGE_TESSELLATION_CONTROL_SHADER_BIT          :: 0x00000010;
    VK_PIPELINE_STAGE_TESSELLATION_EVALUATION_SHADER_BIT       :: 0x00000020;
    VK_PIPELINE_STAGE_GEOMETRY_SHADER_BIT                      :: 0x00000040;
    VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT                      :: 0x00000080;
    VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT                 :: 0x00000100;
    VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT                  :: 0x00000200;
    VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT              :: 0x00000400;
    VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT                       :: 0x00000800;
    VK_PIPELINE_STAGE_TRANSFER_BIT                             :: 0x00001000;
    VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT                       :: 0x00002000;
    VK_PIPELINE_STAGE_HOST_BIT                                 :: 0x00004000;
    VK_PIPELINE_STAGE_ALL_GRAPHICS_BIT                         :: 0x00008000;
    VK_PIPELINE_STAGE_ALL_COMMANDS_BIT                         :: 0x00010000;
    // Provided by VK_VERSION_1_3
    VK_PIPELINE_STAGE_NONE                                     :: 0;
    // Provided by VK_EXT_transform_feedback
    VK_PIPELINE_STAGE_TRANSFORM_FEEDBACK_BIT_EXT               :: 0x01000000;
    // Provided by VK_EXT_conditional_rendering
    VK_PIPELINE_STAGE_CONDITIONAL_RENDERING_BIT_EXT            :: 0x00040000;
    // Provided by VK_KHR_acceleration_structure
    VK_PIPELINE_STAGE_ACCELERATION_STRUCTURE_BUILD_BIT_KHR     :: 0x02000000;
    // Provided by VK_KHR_ray_tracing_pipeline
    VK_PIPELINE_STAGE_RAY_TRACING_SHADER_BIT_KHR               :: 0x00200000;
    // Provided by VK_EXT_fragment_density_map
    VK_PIPELINE_STAGE_FRAGMENT_DENSITY_PROCESS_BIT_EXT         :: 0x00800000;
    // Provided by VK_KHR_fragment_shading_rate
    VK_PIPELINE_STAGE_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR :: 0x00400000;
    // Provided by VK_NV_device_generated_commands
    VK_PIPELINE_STAGE_COMMAND_PREPROCESS_BIT_NV                :: 0x00020000;
    // Provided by VK_EXT_mesh_shader
    VK_PIPELINE_STAGE_TASK_SHADER_BIT_EXT                      :: 0x00080000;
    // Provided by VK_EXT_mesh_shader
    VK_PIPELINE_STAGE_MESH_SHADER_BIT_EXT                      :: 0x00100000;
    // Provided by VK_NV_shading_rate_image
    VK_PIPELINE_STAGE_SHADING_RATE_IMAGE_BIT_NV                :: VK_PIPELINE_STAGE_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR;
    // Provided by VK_NV_ray_tracing
    VK_PIPELINE_STAGE_RAY_TRACING_SHADER_BIT_NV                :: VK_PIPELINE_STAGE_RAY_TRACING_SHADER_BIT_KHR;
    // Provided by VK_NV_ray_tracing
    VK_PIPELINE_STAGE_ACCELERATION_STRUCTURE_BUILD_BIT_NV      :: VK_PIPELINE_STAGE_ACCELERATION_STRUCTURE_BUILD_BIT_KHR;
    // Provided by VK_NV_mesh_shader
    VK_PIPELINE_STAGE_TASK_SHADER_BIT_NV                       :: VK_PIPELINE_STAGE_TASK_SHADER_BIT_EXT;
    // Provided by VK_NV_mesh_shader
    VK_PIPELINE_STAGE_MESH_SHADER_BIT_NV                       :: VK_PIPELINE_STAGE_MESH_SHADER_BIT_EXT;
    // Provided by VK_KHR_synchronization2
    VK_PIPELINE_STAGE_NONE_KHR                                 :: VK_PIPELINE_STAGE_NONE;
}

// Provided by VK_VERSION_1_0
VkQueryControlFlags :: enum_flags VkFlags {
    VK_QUERY_CONTROL_PRECISE_BIT :: 0x00000001;
}

// Provided by VK_VERSION_1_0
VkCommandBufferAllocateInfo :: struct {
    sType              : VkStructureType;
    pNext              : *void;
    commandPool        : VkCommandPool;
    level              : VkCommandBufferLevel;
    commandBufferCount : u32;
}

// Provided by VK_VERSION_1_0
VkCommandBufferInheritanceInfo :: struct {
    sType                : VkStructureType;
    pNext                : *void;
    renderPass           : VkRenderPass;
    subpass              : u32;
    framebuffer          : VkFramebuffer;
    occlusionQueryEnable : VkBool32;
    queryFlags           : VkQueryControlFlags;
    pipelineStatistics   : VkQueryPipelineStatisticFlags;
}

// Provided by VK_VERSION_1_0
VkCommandBufferBeginInfo :: struct {
    sType            : VkStructureType;
    pNext            : *void;
    flags            : VkCommandBufferUsageFlags;
    pInheritanceInfo : *VkCommandBufferInheritanceInfo;
}

// Provided by VK_VERSION_1_0
vkAllocateCommandBuffers :: (
    device          : VkDevice,
    pAllocateInfo   : *VkCommandBufferAllocateInfo,
    pCommandBuffers : *VkCommandBuffer
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkFreeCommandBuffers :: (
    device             : VkDevice,
    commandPool        : VkCommandPool,
    commandBufferCount : u32,
    pCommandBuffers    : *VkCommandBuffer
) #foreign vulkan;

// Provided by VK_VERSION_1_0
vkResetCommandBuffer :: (
    commandBuffer : VkCommandBuffer,
    flags         : VkCommandBufferResetFlags
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkBeginCommandBuffer :: (
    commandBuffer : VkCommandBuffer,
    pBeginInfo    : *VkCommandBufferBeginInfo
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkEndCommandBuffer :: (
    commandBuffer : VkCommandBuffer
) -> VkResult #foreign vulkan;
