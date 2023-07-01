#scope_export

// Provided by VK_VERSION_1_0
VkCommandBuffer :: *VkCommandBuffer_T; VkCommandBuffer_T :: struct {}

// Provided by VK_VERSION_1_0
VkCommandBufferLevel :: enum VkEnum #specified {
    VK_COMMAND_BUFFER_LEVEL_PRIMARY   :: 0;
    VK_COMMAND_BUFFER_LEVEL_SECONDARY :: 1;
}

// Provided by VK_VERSION_1_0
VkAttachmentLoadOp :: enum VkEnum #specified {
    VK_ATTACHMENT_LOAD_OP_LOAD      :: 0;
    VK_ATTACHMENT_LOAD_OP_CLEAR     :: 1;
    VK_ATTACHMENT_LOAD_OP_DONT_CARE :: 2;
    // Provided by VK_EXT_load_store_op_none
    VK_ATTACHMENT_LOAD_OP_NONE_EXT  :: 1000400000;
}

// Provided by VK_VERSION_1_0
VkAttachmentStoreOp :: enum VkEnum #specified {
    VK_ATTACHMENT_STORE_OP_STORE     :: 0;
    VK_ATTACHMENT_STORE_OP_DONT_CARE :: 1;
    // Provided by VK_VERSION_1_3
    VK_ATTACHMENT_STORE_OP_NONE      :: 1000301000;
    // Provided by VK_KHR_dynamic_rendering
    VK_ATTACHMENT_STORE_OP_NONE_KHR  :: VK_ATTACHMENT_STORE_OP_NONE;
    // Provided by VK_QCOM_render_pass_store_ops
    VK_ATTACHMENT_STORE_OP_NONE_QCOM :: VK_ATTACHMENT_STORE_OP_NONE;
    // Provided by VK_EXT_load_store_op_none
    VK_ATTACHMENT_STORE_OP_NONE_EXT  :: VK_ATTACHMENT_STORE_OP_NONE;
}

// Provided by VK_VERSION_1_0
VkCommandBufferResetFlags :: enum_flags VkFlags #specified {
    VK_COMMAND_BUFFER_RESET_RELEASE_RESOURCES_BIT :: 0x00000001;
}

// Provided by VK_VERSION_1_0
VkCommandBufferUsageFlags :: enum_flags VkFlags #specified {
    VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT      :: 0x00000001;
    VK_COMMAND_BUFFER_USAGE_RENDER_PASS_CONTINUE_BIT :: 0x00000002;
    VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT     :: 0x00000004;
}

// Provided by VK_VERSION_1_0
VkQueryPipelineStatisticFlags :: enum_flags VkFlags #specified {
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
VkQueryControlFlags :: enum_flags VkFlags #specified {
    VK_QUERY_CONTROL_PRECISE_BIT :: 0x00000001;
}

// Provided by VK_VERSION_1_3
VkRenderingFlags :: enum_flags VkFlags #specified {
    VK_RENDERING_CONTENTS_SECONDARY_COMMAND_BUFFERS_BIT     :: 0x00000001;
    VK_RENDERING_SUSPENDING_BIT                             :: 0x00000002;
    VK_RENDERING_RESUMING_BIT                               :: 0x00000004;
    // Provided by VK_VERSION_1_3 with VK_EXT_legacy_dithering, VK_KHR_dynamic_rendering with VK_EXT_legacy_dithering
    VK_RENDERING_ENABLE_LEGACY_DITHERING_BIT_EXT            :: 0x00000008;
    VK_RENDERING_CONTENTS_SECONDARY_COMMAND_BUFFERS_BIT_KHR :: VK_RENDERING_CONTENTS_SECONDARY_COMMAND_BUFFERS_BIT;
    VK_RENDERING_SUSPENDING_BIT_KHR                         :: VK_RENDERING_SUSPENDING_BIT;
    VK_RENDERING_RESUMING_BIT_KHR                           :: VK_RENDERING_RESUMING_BIT;
}

// Provided by VK_VERSION_1_2
VkResolveModeFlags :: enum_flags VkFlags #specified {
    VK_RESOLVE_MODE_NONE                :: 0;
    VK_RESOLVE_MODE_SAMPLE_ZERO_BIT     :: 0x00000001;
    VK_RESOLVE_MODE_AVERAGE_BIT         :: 0x00000002;
    VK_RESOLVE_MODE_MIN_BIT             :: 0x00000004;
    VK_RESOLVE_MODE_MAX_BIT             :: 0x00000008;
    // Provided by VK_KHR_depth_stencil_resolve
    VK_RESOLVE_MODE_NONE_KHR            :: VK_RESOLVE_MODE_NONE;
    // Provided by VK_KHR_depth_stencil_resolve
    VK_RESOLVE_MODE_SAMPLE_ZERO_BIT_KHR :: VK_RESOLVE_MODE_SAMPLE_ZERO_BIT;
    // Provided by VK_KHR_depth_stencil_resolve
    VK_RESOLVE_MODE_AVERAGE_BIT_KHR     :: VK_RESOLVE_MODE_AVERAGE_BIT;
    // Provided by VK_KHR_depth_stencil_resolve
    VK_RESOLVE_MODE_MIN_BIT_KHR         :: VK_RESOLVE_MODE_MIN_BIT;
    // Provided by VK_KHR_depth_stencil_resolve
    VK_RESOLVE_MODE_MAX_BIT_KHR         :: VK_RESOLVE_MODE_MAX_BIT;
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
VkClearColorValue :: union {
    float32_ : [4] f32;
    int32    : [4] s32;
    uint32   : [4] u32;
}

// Provided by VK_VERSION_1_0
VkClearDepthStencilValue :: struct {
    depth   : f32;
    stencil : u32;
}

// Provided by VK_VERSION_1_0
VkClearValue :: union {
    color        : VkClearColorValue;
    depthStencil : VkClearDepthStencilValue;
}

// Provided by VK_VERSION_1_3
VkRenderingAttachmentInfo :: struct {
    sType              : VkStructureType;
    pNext              : *void;
    imageView          : VkImageView;
    imageLayout        : VkImageLayout;
    resolveMode        : VkResolveModeFlags;
    resolveImageView   : VkImageView;
    resolveImageLayout : VkImageLayout;
    loadOp             : VkAttachmentLoadOp;
    storeOp            : VkAttachmentStoreOp;
    clearValue         : VkClearValue;
}

// Provided by VK_VERSION_1_3
VkRenderingInfo :: struct {
    sType                : VkStructureType;
    pNext                : *void;
    flags                : VkRenderingFlags;
    renderArea           : VkRect2D;
    layerCount           : u32;
    viewMask             : u32;
    colorAttachmentCount : u32;
    pColorAttachments    : *VkRenderingAttachmentInfo;
    pDepthAttachment     : *VkRenderingAttachmentInfo;
    pStencilAttachment   : *VkRenderingAttachmentInfo;
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

// Provided by VK_VERSION_1_0
vkCmdClearColorImage :: (
    commandBuffer : VkCommandBuffer,
    image         : VkImage,
    imageLayout   : VkImageLayout,
    pColor        : *VkClearColorValue,
    rangeCount    : u32,
    pRanges       : *VkImageSubresourceRange
) #foreign vulkan;

// Provided by VK_VERSION_1_0
vkCmdClearDepthStencilImage :: (
    commandBuffer : VkCommandBuffer,
    image         : VkImage,
    imageLayout   : VkImageLayout,
    pDepthStencil : *VkClearDepthStencilValue,
    rangeCount    : u32,
    pRanges       : *VkImageSubresourceRange
) #foreign vulkan;

// Provided by VK_VERSION_1_0
vkCmdSetViewport :: (
    commandBuffer : VkCommandBuffer,
    firstViewport : u32,
    viewportCount : u32,
    pViewports    : *VkViewport
) #foreign vulkan;

// Provided by VK_VERSION_1_0
vkCmdSetScissor :: (
    commandBuffer : VkCommandBuffer,
    firstScissor  : u32,
    scissorCount  : u32,
    pScissors     : *VkRect2D
) #foreign vulkan;

// Provided by VK_VERSION_1_0
vkCmdBindPipeline :: (
    commandBuffer     : VkCommandBuffer,
    pipelineBindPoint : VkPipelineBindPoint,
    pipeline          : VkPipeline
) #foreign vulkan;

// Provided by VK_VERSION_1_3
vkCmdBeginRendering :: (
    commandBuffer  : VkCommandBuffer,
    pRenderingInfo : *VkRenderingInfo
) #foreign vulkan;

// Provided by VK_VERSION_1_3
vkCmdEndRendering :: (
    commandBuffer : VkCommandBuffer
) #foreign vulkan;

// Provided by VK_VERSION_1_0
vkCmdDraw :: (
    commandBuffer : VkCommandBuffer,
    vertexCount   : u32,
    instanceCount : u32,
    firstVertex   : u32,
    firstInstance : u32
) #foreign vulkan;