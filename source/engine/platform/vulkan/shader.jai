#scope_export

VulkanShaderManager :: struct {
    #as using public_data : ShaderManager;

    pipeline_cache  : VkPipelineCache;
    shaders_storage : [MAX_SHADERS] VulkanShader;
}

createVulkanShaderManager :: (device : *VulkanDevice) -> *VulkanShaderManager #must {
    manager := pushToArena(*context.pet.persistent_arena, VulkanShaderManager);

    // @TODO: #PipelineCache. Initial data.
    create_info := VkPipelineCacheCreateInfo.{
        sType           = .VK_STRUCTURE_TYPE_PIPELINE_CACHE_CREATE_INFO,
        pNext           = null,
        flags           = 0,
        initialDataSize = 0,
        pInitialData    = null,
    };

    // @TODO: #VkAllocationCallbacks
    debugCheckVK(vkCreatePipelineCache(device.device, *create_info, null, *manager.pipeline_cache));

    return manager;
}

destroyVulkanShaderManager :: (device : *VulkanDevice, manager : *VulkanShaderManager) {
    // @TODO: #VkAllocationCallbacks
    vkDestroyPipelineCache(device.device, manager.pipeline_cache, null);

    shaders : [] VulkanShader;
    shaders.data  = manager.shaders_storage.data;
    shaders.count = manager.shaders_count;

    for shaders {
        // @TODO: #VkAllocationCallbacks
        vkDestroyPipeline(device.device, it.pipeline, null);

        // @TODO: #VkAllocationCallbacks
        vkDestroyPipelineLayout(device.device, it.pipeline_layout, null);
    }
}

VulkanShader :: struct {
    #as using public_data : Shader;

    pipeline_layout : VkPipelineLayout;
    pipeline        : VkPipeline;
}

pushVulkanShader :: (manager : *VulkanShaderManager) -> *VulkanShader #must {
    assert(manager.shaders_count < manager.shaders_storage.count,
           "Too many shaders were created. Consider increasing ShaderManager.MAX_SHADERS");

    shader := *manager.shaders_storage[manager.shaders_count];
    manager.shaders_count += 1;

    return shader;
}

createGraphicsVulkanShader :: (device : *VulkanDevice, manager : *VulkanShaderManager, shader : *VulkanShader) {
    shader_stages : [#run Basic.enum_highest_value(ShaderStage) + 1] VkShaderModule = ---;
    for * shader_stages {
        it.* = createShaderStage(device, shader.name, cast(ShaderStage) it_index);
    }
    defer for shader_stages {
        // @TODO: #VkAllocationCallbacks
        vkDestroyShaderModule(device.device, it, null);
    }

    // @TODO: #ShaderCompiler
    {
        create_info := VkPipelineLayoutCreateInfo.{
            sType                  = .VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
            pNext                  = null,
            flags                  = 0,
            setLayoutCount         = 0,
            pSetLayouts            = null,
            pushConstantRangeCount = 0,
            pPushConstantRanges    = null,
        };

        // @TODO: #VkAllocationCallbacks
        debugCheckVK(vkCreatePipelineLayout(device.device, *create_info, null, *shader.pipeline_layout));

        setVulkanObjectName(device, shader.pipeline_layout, "% pipeline layout", shader.name);
    }

    #if DEBUG_BUILD {
        CREATE_FLAGS : VkPipelineCreateFlags : .VK_PIPELINE_CREATE_DISABLE_OPTIMIZATION_BIT;
    } else {
        CREATE_FLAGS : VkPipelineCreateFlags : 0;
    }

    stage_create_infos : [shader_stages.count] VkPipelineShaderStageCreateInfo = ---;
    for * stage_create_infos {
        it.sType               = .VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        it.pNext               = null;
        it.flags               = 0;
        it.stage               = shaderStageToVulkanStage(cast(ShaderStage) it_index);
        it.module              = shader_stages[it_index];
        it.pName               = "main";
        it.pSpecializationInfo = null;
    }

    vertex_input_state : VkPipelineVertexInputStateCreateInfo = ---;
    initVertexInputState(*vertex_input_state);

    input_assembly_state : VkPipelineInputAssemblyStateCreateInfo = ---;
    initInputAssemblyState(*input_assembly_state);

    viewport_state : VkPipelineViewportStateCreateInfo = ---;
    initViewportState(*viewport_state);

    rasterization_state : VkPipelineRasterizationStateCreateInfo = ---;
    initRasterizationState(*rasterization_state);

    multisample_state : VkPipelineMultisampleStateCreateInfo = ---;
    initMultisampleState(*multisample_state);

    depth_stencil_state : VkPipelineDepthStencilStateCreateInfo = ---;
    initDepthStencilState(*depth_stencil_state);

    color_blend_state : VkPipelineColorBlendStateCreateInfo = ---;
    initColorBlendState(*color_blend_state);

    dynamic_state : VkPipelineDynamicStateCreateInfo = ---;
    initDynamicStates(*dynamic_state);

    pipeline_rendering_create_info := VkPipelineRenderingCreateInfo.{
        sType                   = .VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO,
        pNext                   = null,
        viewMask                = 0,
        colorAttachmentCount    = 1,
        pColorAttachmentFormats = VkFormat.[ .VK_FORMAT_B8G8R8A8_UNORM ].data,
        depthAttachmentFormat   = .VK_FORMAT_UNDEFINED,
        stencilAttachmentFormat = .VK_FORMAT_UNDEFINED,
    };

    create_info := VkGraphicsPipelineCreateInfo.{
        sType               = .VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        pNext               = *pipeline_rendering_create_info,
        flags               = CREATE_FLAGS,
        stageCount          = cast(u32) stage_create_infos.count,
        pStages             = stage_create_infos.data,
        pVertexInputState   = *vertex_input_state,
        pInputAssemblyState = *input_assembly_state,
        pTessellationState  = null,
        pViewportState      = *viewport_state,
        pRasterizationState = *rasterization_state,
        pMultisampleState   = *multisample_state,
        pDepthStencilState  = *depth_stencil_state,
        pColorBlendState    = *color_blend_state,
        pDynamicState       = *dynamic_state,
        layout              = shader.pipeline_layout,
        renderPass          = VK_NULL_HANDLE,
        subpass             = 0,
        basePipelineHandle  = VK_NULL_HANDLE,
        basePipelineIndex   = 0
    };

    // @TODO: #VkAllocationCallbacks
    debugCheckVK(vkCreateGraphicsPipelines(device.device, manager.pipeline_cache, 1, *create_info, null, *shader.pipeline));

    setVulkanObjectName(device, shader.pipeline, "% graphics pipeline", shader.name);
}

#scope_file

// @TODO: #ShaderCompiler. Single file shader.
createShaderStage :: (device : *VulkanDevice, name : string, stage : ShaderStage) -> VkShaderModule #must {
    SHADERS_FOLDER :: "shaders"; // @TODO: #FileSystem.

    file_extension : string = ---;
    if #complete stage == {
        case .VERTEX;
            file_extension = ".vert.spv";
        case .FRAGMENT;
            file_extension = ".frag.spv";
    }

    filename := String.join(SHADERS_FOLDER, "/", name, file_extension, allocator = Basic.temporary_allocator);

    spirv, success := File.read_entire_file(filename);
    assert(success);
    defer Basic.free(spirv);

    create_info := VkShaderModuleCreateInfo.{
        sType    = .VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        pNext    = null,
        flags    = 0,
        codeSize = cast(size_t) spirv.count,
        pCode    = cast(*u32)   spirv.data,
    };

    module : VkShaderModule;
    debugCheckVK(vkCreateShaderModule(device.device, *create_info, null, *module)); // @TODO: VkAllocationCallbacks

    setVulkanObjectName(device, module, "% % shader module", stage, name);

    return module;
}

shaderStageToVulkanStage :: inline (stage : ShaderStage) -> VkShaderStageFlags #no_context {
    if #complete stage == {
        case .VERTEX;   return .VK_SHADER_STAGE_VERTEX_BIT;
        case .FRAGMENT; return .VK_SHADER_STAGE_FRAGMENT_BIT;
    }
    return 0;
}

// @TODO: #ShaderCompiler. Get vertex shader input from shader.
initVertexInputState :: inline (state : *VkPipelineVertexInputStateCreateInfo) #no_context {
    state.sType                           = .VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
    state.pNext                           = null;
    state.flags                           = 0;
    state.vertexBindingDescriptionCount   = 0;
    state.pVertexBindingDescriptions      = null;
    state.vertexAttributeDescriptionCount = 0;
    state.pVertexAttributeDescriptions    = null;
}

// @TODO: #ShaderCompiler. Get primitive topology from shader.
initInputAssemblyState :: inline (state : *VkPipelineInputAssemblyStateCreateInfo) #no_context {
    state.sType                   = .VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
    state.pNext                   = null;
    state.flags                   = 0;
    state.topology                = .VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
    state.primitiveRestartEnable  = cast,no_check(u32) (   state.topology == .VK_PRIMITIVE_TOPOLOGY_LINE_STRIP
                                                        || state.topology == .VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP
                                                        || state.topology == .VK_PRIMITIVE_TOPOLOGY_TRIANGLE_FAN
                                                        || state.topology == .VK_PRIMITIVE_TOPOLOGY_LINE_STRIP_WITH_ADJACENCY
                                                        || state.topology == .VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP_WITH_ADJACENCY);
}

initViewportState :: inline (state : *VkPipelineViewportStateCreateInfo) #no_context {
    state.sType         = .VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
    state.pNext         = null;
    state.flags         = 0;
    state.viewportCount = 1;
    state.pViewports    = null;
    state.scissorCount  = 1;
    state.pScissors     = null;
}

// @TODO: #ShaderCompiler. Get from shader:
//          1. Polygon mode
//          2. Cull mode
//          3. Front face
//          4. Depth bias stuff (I'm not sure we really need it)
initRasterizationState :: inline (state : *VkPipelineRasterizationStateCreateInfo) #no_context {
    state.sType                   = .VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
    state.pNext                   = null;
    state.flags                   = 0;
    state.depthClampEnable        = VK_FALSE;
    state.rasterizerDiscardEnable = VK_FALSE;
    state.polygonMode             = .VK_POLYGON_MODE_FILL;
    state.cullMode                = .VK_CULL_MODE_BACK_BIT;
    state.frontFace               = .VK_FRONT_FACE_CLOCKWISE;
    state.depthBiasEnable         = VK_FALSE;
    state.depthBiasConstantFactor = 0.0;
    state.depthBiasClamp          = 0.0;
    state.depthBiasSlopeFactor    = 0.0;
    state.lineWidth               = 1.0;
}

// @TODO: #ShaderCompiler. Get from shader:
//          1. Should we execute shader per sample or per pixel
initMultisampleState :: inline (state : *VkPipelineMultisampleStateCreateInfo) #no_context {
    state.sType                 = .VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
    state.pNext                 = null;
    state.flags                 = 0;
    state.rasterizationSamples  = .VK_SAMPLE_COUNT_1_BIT; // @TODO: Get from createVulkanShader
    state.sampleShadingEnable   = VK_FALSE;
    state.minSampleShading      = 0.0;
    state.pSampleMask           = null; // If pSampleMask is NULL, it is treated as if the mask has all bits set to 1.
    state.alphaToCoverageEnable = VK_FALSE; // @TODO: AlphaToCoverage
    state.alphaToOneEnable      = VK_FALSE; // @TODO: AlphaToOne
}

// @TODO: #ShaderCompiler. Get from shader:
//          1. depthTestEnable
//          2. depthWriteEnable
//          3. depthCompareOp
//          4. stencilTestEnable
initDepthStencilState :: inline (state : *VkPipelineDepthStencilStateCreateInfo) #no_context {
    state.sType                 = .VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO;
    state.pNext                 = null;
    state.flags                 = 0;
    state.depthTestEnable       = VK_FALSE;
    state.depthWriteEnable      = VK_FALSE;
    state.depthCompareOp        = .VK_COMPARE_OP_ALWAYS;
    state.depthBoundsTestEnable = VK_FALSE;
    state.stencilTestEnable     = VK_FALSE;
    state.front                 = .{};
    state.back                  = .{};
    state.minDepthBounds        = 0.0;
    state.maxDepthBounds        = 0.0;
}

// @Cleanup. #Hardcoded
COLOR_BLEND_ATTACHMENT :: VkPipelineColorBlendAttachmentState.{
    blendEnable         = VK_FALSE,
    srcColorBlendFactor = .VK_BLEND_FACTOR_SRC_COLOR,
    dstColorBlendFactor = .VK_BLEND_FACTOR_ZERO,
    colorBlendOp        = .VK_BLEND_OP_ADD,
    srcAlphaBlendFactor = .VK_BLEND_FACTOR_SRC_ALPHA,
    dstAlphaBlendFactor = .VK_BLEND_FACTOR_ZERO,
    alphaBlendOp        = .VK_BLEND_OP_ADD,
    colorWriteMask      = .VK_COLOR_COMPONENT_R_BIT
                        | .VK_COLOR_COMPONENT_G_BIT
                        | .VK_COLOR_COMPONENT_B_BIT
                        | .VK_COLOR_COMPONENT_A_BIT,
};

// @TODO: #ShaderCompiler. Get from shader:
//          1. logicOp
//          2. attachments (fragment shader output)
initColorBlendState :: inline (state : *VkPipelineColorBlendStateCreateInfo) #no_context {
    state.sType           = .VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
    state.pNext           = null;
    state.flags           = 0;
    state.logicOpEnable   = VK_FALSE;
    state.logicOp         = .VK_LOGIC_OP_COPY;
    state.attachmentCount = 1;
    state.pAttachments    = *COLOR_BLEND_ATTACHMENT;
    state.blendConstants  = .[ 0.0, 0.0, 0.0, 0.0 ];
}

DYNAMIC_STATES :: VkDynamicState.[
    .VK_DYNAMIC_STATE_VIEWPORT,
    .VK_DYNAMIC_STATE_SCISSOR,
];

initDynamicStates :: inline (state : *VkPipelineDynamicStateCreateInfo) #no_context {
    state.sType             = .VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
    state.pNext             = null;
    state.flags             = 0;
    state.dynamicStateCount = DYNAMIC_STATES.count;
    state.pDynamicStates    = DYNAMIC_STATES.data;
}
