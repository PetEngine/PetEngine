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
