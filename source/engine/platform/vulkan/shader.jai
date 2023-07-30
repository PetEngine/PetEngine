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

createGraphicsVulkanShader :: (device : *VulkanDevice, manager : *VulkanShaderManager, shader : *VulkanShader, shader_file_data : string) {
    shader_file_header := cast(*ShaderCompiler.Header) shader_file_data.data;

    shader_stages : [ShaderCompiler.Header.stage_offsets.count] VkShaderModule = ---;
    for * shader_stages {
        this_stage_offset := shader_file_header.stage_offsets[it_index];

        if this_stage_offset == ShaderCompiler.INVALID_OFFSET {
            continue;
        }

        next_stage_offset := ShaderCompiler.INVALID_OFFSET;
        {
            for next_stage_index : it_index + 1 .. shader_stages.count - 1 {
                next_stage_offset = shader_file_header.stage_offsets[next_stage_index];
                if next_stage_offset != ShaderCompiler.INVALID_OFFSET {
                    break;
                }
            }

            if next_stage_offset == ShaderCompiler.INVALID_OFFSET {
                next_stage_offset = shader_file_data.count;
            }
        }

        spirv : string = ---;
        spirv.count = next_stage_offset - this_stage_offset;
        spirv.data  = *shader_file_data[this_stage_offset];

        it.* = createShaderStage(device, spirv, cast(ShaderStage) it_index, shader.name);
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

    graphics_pipeline_state := cast(*ShaderCompiler.GraphicsPipelineState) shader_file_data.data + size_of(ShaderCompiler.Header);

    vertex_input_state : VkPipelineVertexInputStateCreateInfo = ---;
    initVertexInputState(*vertex_input_state);

    input_assembly_state : VkPipelineInputAssemblyStateCreateInfo = ---;
    initInputAssemblyState(*input_assembly_state, graphics_pipeline_state);

    viewport_state : VkPipelineViewportStateCreateInfo = ---;
    initViewportState(*viewport_state);

    rasterization_state : VkPipelineRasterizationStateCreateInfo = ---;
    initRasterizationState(*rasterization_state, graphics_pipeline_state);

    multisample_state : VkPipelineMultisampleStateCreateInfo = ---;
    initMultisampleState(*multisample_state);

    depth_stencil_state : VkPipelineDepthStencilStateCreateInfo = ---;
    initDepthStencilState(*depth_stencil_state, graphics_pipeline_state);

    color_blend_state : VkPipelineColorBlendStateCreateInfo = ---;
    initColorBlendState(*color_blend_state, graphics_pipeline_state);

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
createShaderStage :: (device : *VulkanDevice, spirv : string, stage : ShaderStage, shader_name : string) -> VkShaderModule #must {
    create_info := VkShaderModuleCreateInfo.{
        sType    = .VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        pNext    = null,
        flags    = 0,
        codeSize = cast(size_t) spirv.count,
        pCode    = cast(*u32)   spirv.data,
    };

    module : VkShaderModule;
    debugCheckVK(vkCreateShaderModule(device.device, *create_info, null, *module)); // @TODO: VkAllocationCallbacks

    setVulkanObjectName(device, module, "% % shader module", stage, shader_name);

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
initVertexInputState :: inline (this : *VkPipelineVertexInputStateCreateInfo) #no_context {
    this.sType                           = .VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
    this.pNext                           = null;
    this.flags                           = 0;
    this.vertexBindingDescriptionCount   = 0;
    this.pVertexBindingDescriptions      = null;
    this.vertexAttributeDescriptionCount = 0;
    this.pVertexAttributeDescriptions    = null;
}

initInputAssemblyState :: inline (this : *VkPipelineInputAssemblyStateCreateInfo, state : *ShaderCompiler.GraphicsPipelineState) {
    this.sType = .VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
    this.pNext = null;
    this.flags = 0;

    if #complete state.primitive_topology == {
        case .POINT_LIST;     this.topology = .VK_PRIMITIVE_TOPOLOGY_POINT_LIST;
        case .LINE_LIST;      this.topology = .VK_PRIMITIVE_TOPOLOGY_LINE_LIST;
        case .LINE_STRIP;     this.topology = .VK_PRIMITIVE_TOPOLOGY_LINE_STRIP;
        case .TRIANGLE_LIST;  this.topology = .VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
        case .TRIANGLE_STRIP; this.topology = .VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP;
        case;                 assertMessage("Unknown topology: %", state.primitive_topology);
    }

    this.primitiveRestartEnable = cast,no_check(u32) (   this.topology == .VK_PRIMITIVE_TOPOLOGY_LINE_STRIP
                                                      || this.topology == .VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP
                                                      || this.topology == .VK_PRIMITIVE_TOPOLOGY_TRIANGLE_FAN
                                                      || this.topology == .VK_PRIMITIVE_TOPOLOGY_LINE_STRIP_WITH_ADJACENCY
                                                      || this.topology == .VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP_WITH_ADJACENCY);
}

initViewportState :: inline (this : *VkPipelineViewportStateCreateInfo) #no_context {
    this.sType         = .VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
    this.pNext         = null;
    this.flags         = 0;
    this.viewportCount = 1;
    this.pViewports    = null;
    this.scissorCount  = 1;
    this.pScissors     = null;
}

initRasterizationState :: inline (this : *VkPipelineRasterizationStateCreateInfo, state : *ShaderCompiler.GraphicsPipelineState) {
    this.sType                   = .VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
    this.pNext                   = null;
    this.flags                   = 0;
    this.depthClampEnable        = VK_FALSE;
    this.rasterizerDiscardEnable = VK_FALSE;

    if #complete state.fill_mode == {
        case .FILL; this.polygonMode = .VK_POLYGON_MODE_FILL;
        case .LINE; this.polygonMode = .VK_POLYGON_MODE_LINE;
        case;       assertMessage("Unknown fill mode: %", state.fill_mode);
    }

    if #complete state.cull_mode == {
        case .NONE;       this.cullMode = .VK_CULL_MODE_NONE;
        case .FRONT_FACE; this.cullMode = .VK_CULL_MODE_FRONT_BIT;
        case .BACK_FACE;  this.cullMode = .VK_CULL_MODE_BACK_BIT;
        case;             assertMessage("Unknown cull mode: %", state.cull_mode);
    }

    if #complete state.front_face == {
        case .CLOCKWISE;         this.frontFace = .VK_FRONT_FACE_CLOCKWISE;
        case .COUNTER_CLOCKWISE; this.frontFace = .VK_FRONT_FACE_COUNTER_CLOCKWISE;
        case;       assertMessage("Unknown front face: %", state.front_face);
    }

    this.depthBiasEnable         = cast,no_check(VkBool32) state.depth_bias_enable;
    this.depthBiasConstantFactor = state.depth_bias_constant_factor;
    this.depthBiasClamp          = state.depth_bias_clamp;
    this.depthBiasSlopeFactor    = state.depth_bias_slope_factor;
    this.lineWidth               = 1.0;
}

// @TODO: #ShaderCompiler. Get from shader:
//          1. Should we execute shader per sample or per pixel
initMultisampleState :: inline (this : *VkPipelineMultisampleStateCreateInfo) #no_context {
    this.sType                 = .VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
    this.pNext                 = null;
    this.flags                 = 0;
    this.rasterizationSamples  = .VK_SAMPLE_COUNT_1_BIT; // @TODO: Get from createVulkanShader
    this.sampleShadingEnable   = VK_FALSE;
    this.minSampleShading      = 0.0;
    this.pSampleMask           = null; // If pSampleMask is NULL, it is treated as if the mask has all bits set to 1.
    this.alphaToCoverageEnable = VK_FALSE; // @TODO: AlphaToCoverage
    this.alphaToOneEnable      = VK_FALSE; // @TODO: AlphaToOne
}

// @TODO: #ShaderCompiler. Get from shader:
//          1. stencilTestEnable
initDepthStencilState :: inline (this : *VkPipelineDepthStencilStateCreateInfo, state : *ShaderCompiler.GraphicsPipelineState) {
    this.sType            = .VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO;
    this.pNext            = null;
    this.flags            = 0;
    this.depthTestEnable  = cast,no_check(VkBool32) state.depth_test_enable;
    this.depthWriteEnable = cast,no_check(VkBool32) state.depth_write_enable;

    if #complete state.depth_compare_op == {
        case .NEVER;            this.depthCompareOp = .VK_COMPARE_OP_NEVER;
        case .ALWAYS;           this.depthCompareOp = .VK_COMPARE_OP_ALWAYS;
        case .NOT_EQUAL;        this.depthCompareOp = .VK_COMPARE_OP_NOT_EQUAL;
        case .EQUAL;            this.depthCompareOp = .VK_COMPARE_OP_EQUAL;
        case .LESS;             this.depthCompareOp = .VK_COMPARE_OP_LESS;
        case .LESS_OR_EQUAL;    this.depthCompareOp = .VK_COMPARE_OP_LESS_OR_EQUAL;
        case .GREATER;          this.depthCompareOp = .VK_COMPARE_OP_GREATER;
        case .GREATER_OR_EQUAL; this.depthCompareOp = .VK_COMPARE_OP_GREATER_OR_EQUAL;
        case;                   assertMessage("Unknown depth compare op: %", state.depth_compare_op);
    }

    this.depthBoundsTestEnable = VK_FALSE;
    this.stencilTestEnable     = VK_FALSE;
    this.front                 = .{};
    this.back                  = .{};
    this.minDepthBounds        = 0.0;
    this.maxDepthBounds        = 0.0;
}

initColorBlendState :: inline (this : *VkPipelineColorBlendStateCreateInfo, state : *ShaderCompiler.GraphicsPipelineState) {
    this.sType           = .VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
    this.pNext           = null;
    this.flags           = 0;
    this.logicOpEnable   = cast,no_check(VkBool32) state.blend_logic_op_enable;

    if state.blend_logic_op == {
        case .ZERO;          this.logicOp = .VK_LOGIC_OP_CLEAR;
        case .ONE;           this.logicOp = .VK_LOGIC_OP_SET;
        case .COPY;          this.logicOp = .VK_LOGIC_OP_COPY;
        case .COPY_INVERTED; this.logicOp = .VK_LOGIC_OP_COPY_INVERTED;
        case .NO_OP;         this.logicOp = .VK_LOGIC_OP_NO_OP;
        case .INVERT;        this.logicOp = .VK_LOGIC_OP_INVERT;
        case .AND;           this.logicOp = .VK_LOGIC_OP_AND;
        case .AND_REVERSE;   this.logicOp = .VK_LOGIC_OP_AND_REVERSE;
        case .AND_INVERTED;  this.logicOp = .VK_LOGIC_OP_AND_INVERTED;
        case .NAND;          this.logicOp = .VK_LOGIC_OP_NAND;
        case .OR;            this.logicOp = .VK_LOGIC_OP_OR;
        case .OR_REVERSE;    this.logicOp = .VK_LOGIC_OP_OR_REVERSE;
        case .OR_INVERTED;   this.logicOp = .VK_LOGIC_OP_OR_INVERTED;
        case .NOR;           this.logicOp = .VK_LOGIC_OP_NOR;
        case .XOR;           this.logicOp = .VK_LOGIC_OP_XOR;
        case .EQUIVALENT;    this.logicOp = .VK_LOGIC_OP_EQUIVALENT;
        case;                assertMessage("Unknown blend logic op op: %", state.blend_logic_op);
    }

    this.attachmentCount = state.color_targets_count;
    this.pAttachments    = pushToArena(*context.pet.per_frame_arena, VkPipelineColorBlendAttachmentState, this.attachmentCount);
    this.blendConstants  = .[ 0.0, 0.0, 0.0, 0.0 ];

    attachment_states : [] VkPipelineColorBlendAttachmentState;
    attachment_states.count = this.attachmentCount;
    attachment_states.data  = this.pAttachments;

    for * attachment_states {
        color_target := *state.color_targets[it_index];

        it.blendEnable = cast,no_check(VkBool32) color_target.blend_enable;

        if #complete color_target.src_color_blend_factor == {
            case .ZERO;                     it.srcColorBlendFactor = .VK_BLEND_FACTOR_ZERO;
            case .ONE;                      it.srcColorBlendFactor = .VK_BLEND_FACTOR_ONE;
            case .SRC_COLOR;                it.srcColorBlendFactor = .VK_BLEND_FACTOR_SRC_COLOR;
            case .ONE_MINUS_SRC_COLOR;      it.srcColorBlendFactor = .VK_BLEND_FACTOR_ONE_MINUS_SRC_COLOR;
            case .DST_COLOR;                it.srcColorBlendFactor = .VK_BLEND_FACTOR_DST_COLOR;
            case .ONE_MINUS_DST_COLOR;      it.srcColorBlendFactor = .VK_BLEND_FACTOR_ONE_MINUS_DST_COLOR;
            case .SRC_ALPHA;                it.srcColorBlendFactor = .VK_BLEND_FACTOR_SRC_ALPHA;
            case .ONE_MINUS_SRC_ALPHA;      it.srcColorBlendFactor = .VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
            case .DST_ALPHA;                it.srcColorBlendFactor = .VK_BLEND_FACTOR_DST_ALPHA;
            case .ONE_MINUS_DST_ALPHA;      it.srcColorBlendFactor = .VK_BLEND_FACTOR_ONE_MINUS_DST_ALPHA;
            case .CONSTANT_COLOR;           it.srcColorBlendFactor = .VK_BLEND_FACTOR_CONSTANT_COLOR;
            case .ONE_MINUS_CONSTANT_COLOR; it.srcColorBlendFactor = .VK_BLEND_FACTOR_ONE_MINUS_CONSTANT_COLOR;
            case .CONSTANT_ALPHA;           it.srcColorBlendFactor = .VK_BLEND_FACTOR_CONSTANT_ALPHA;
            case .ONE_MINUS_CONSTANT_ALPHA; it.srcColorBlendFactor = .VK_BLEND_FACTOR_ONE_MINUS_CONSTANT_ALPHA;
            case .SRC_ALPHA_SATURATE;       it.srcColorBlendFactor = .VK_BLEND_FACTOR_SRC_ALPHA_SATURATE;
            case;                           assertMessage("Unknown source color blend factor: %", color_target.src_color_blend_factor);
        }

        if #complete color_target.dst_color_blend_factor == {
            case .ZERO;                     it.dstColorBlendFactor = .VK_BLEND_FACTOR_ZERO;
            case .ONE;                      it.dstColorBlendFactor = .VK_BLEND_FACTOR_ONE;
            case .SRC_COLOR;                it.dstColorBlendFactor = .VK_BLEND_FACTOR_SRC_COLOR;
            case .ONE_MINUS_SRC_COLOR;      it.dstColorBlendFactor = .VK_BLEND_FACTOR_ONE_MINUS_SRC_COLOR;
            case .DST_COLOR;                it.dstColorBlendFactor = .VK_BLEND_FACTOR_DST_COLOR;
            case .ONE_MINUS_DST_COLOR;      it.dstColorBlendFactor = .VK_BLEND_FACTOR_ONE_MINUS_DST_COLOR;
            case .SRC_ALPHA;                it.dstColorBlendFactor = .VK_BLEND_FACTOR_SRC_ALPHA;
            case .ONE_MINUS_SRC_ALPHA;      it.dstColorBlendFactor = .VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
            case .DST_ALPHA;                it.dstColorBlendFactor = .VK_BLEND_FACTOR_DST_ALPHA;
            case .ONE_MINUS_DST_ALPHA;      it.dstColorBlendFactor = .VK_BLEND_FACTOR_ONE_MINUS_DST_ALPHA;
            case .CONSTANT_COLOR;           it.dstColorBlendFactor = .VK_BLEND_FACTOR_CONSTANT_COLOR;
            case .ONE_MINUS_CONSTANT_COLOR; it.dstColorBlendFactor = .VK_BLEND_FACTOR_ONE_MINUS_CONSTANT_COLOR;
            case .CONSTANT_ALPHA;           it.dstColorBlendFactor = .VK_BLEND_FACTOR_CONSTANT_ALPHA;
            case .ONE_MINUS_CONSTANT_ALPHA; it.dstColorBlendFactor = .VK_BLEND_FACTOR_ONE_MINUS_CONSTANT_ALPHA;
            case .SRC_ALPHA_SATURATE;       it.dstColorBlendFactor = .VK_BLEND_FACTOR_SRC_ALPHA_SATURATE;
            case;                           assertMessage("Unknown destination color blend factor: %", color_target.dst_color_blend_factor);
        }

        if #complete color_target.color_blend_op == {
            case .ADD;              it.colorBlendOp = .VK_BLEND_OP_ADD;
            case .SUBTRACT;         it.colorBlendOp = .VK_BLEND_OP_SUBTRACT;
            case .REVERSE_SUBTRACT; it.colorBlendOp = .VK_BLEND_OP_REVERSE_SUBTRACT;
            case .MIN;              it.colorBlendOp = .VK_BLEND_OP_MIN;
            case .MAX;              it.colorBlendOp = .VK_BLEND_OP_MAX;
            case;                   assertMessage("Unknown color blend operation: %", color_target.color_blend_op);
        }

        if #complete color_target.src_alpha_blend_factor == {
            case .ZERO;                     it.srcAlphaBlendFactor = .VK_BLEND_FACTOR_ZERO;
            case .ONE;                      it.srcAlphaBlendFactor = .VK_BLEND_FACTOR_ONE;
            case .SRC_COLOR;                it.srcAlphaBlendFactor = .VK_BLEND_FACTOR_SRC_COLOR;
            case .ONE_MINUS_SRC_COLOR;      it.srcAlphaBlendFactor = .VK_BLEND_FACTOR_ONE_MINUS_SRC_COLOR;
            case .DST_COLOR;                it.srcAlphaBlendFactor = .VK_BLEND_FACTOR_DST_COLOR;
            case .ONE_MINUS_DST_COLOR;      it.srcAlphaBlendFactor = .VK_BLEND_FACTOR_ONE_MINUS_DST_COLOR;
            case .SRC_ALPHA;                it.srcAlphaBlendFactor = .VK_BLEND_FACTOR_SRC_ALPHA;
            case .ONE_MINUS_SRC_ALPHA;      it.srcAlphaBlendFactor = .VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
            case .DST_ALPHA;                it.srcAlphaBlendFactor = .VK_BLEND_FACTOR_DST_ALPHA;
            case .ONE_MINUS_DST_ALPHA;      it.srcAlphaBlendFactor = .VK_BLEND_FACTOR_ONE_MINUS_DST_ALPHA;
            case .CONSTANT_COLOR;           it.srcAlphaBlendFactor = .VK_BLEND_FACTOR_CONSTANT_COLOR;
            case .ONE_MINUS_CONSTANT_COLOR; it.srcAlphaBlendFactor = .VK_BLEND_FACTOR_ONE_MINUS_CONSTANT_COLOR;
            case .CONSTANT_ALPHA;           it.srcAlphaBlendFactor = .VK_BLEND_FACTOR_CONSTANT_ALPHA;
            case .ONE_MINUS_CONSTANT_ALPHA; it.srcAlphaBlendFactor = .VK_BLEND_FACTOR_ONE_MINUS_CONSTANT_ALPHA;
            case .SRC_ALPHA_SATURATE;       it.srcAlphaBlendFactor = .VK_BLEND_FACTOR_SRC_ALPHA_SATURATE;
            case;                           assertMessage("Unknown source alpha blend factor: %", color_target.src_alpha_blend_factor);
        }

        if #complete color_target.dst_alpha_blend_factor == {
            case .ZERO;                     it.dstAlphaBlendFactor = .VK_BLEND_FACTOR_ZERO;
            case .ONE;                      it.dstAlphaBlendFactor = .VK_BLEND_FACTOR_ONE;
            case .SRC_COLOR;                it.dstAlphaBlendFactor = .VK_BLEND_FACTOR_SRC_COLOR;
            case .ONE_MINUS_SRC_COLOR;      it.dstAlphaBlendFactor = .VK_BLEND_FACTOR_ONE_MINUS_SRC_COLOR;
            case .DST_COLOR;                it.dstAlphaBlendFactor = .VK_BLEND_FACTOR_DST_COLOR;
            case .ONE_MINUS_DST_COLOR;      it.dstAlphaBlendFactor = .VK_BLEND_FACTOR_ONE_MINUS_DST_COLOR;
            case .SRC_ALPHA;                it.dstAlphaBlendFactor = .VK_BLEND_FACTOR_SRC_ALPHA;
            case .ONE_MINUS_SRC_ALPHA;      it.dstAlphaBlendFactor = .VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
            case .DST_ALPHA;                it.dstAlphaBlendFactor = .VK_BLEND_FACTOR_DST_ALPHA;
            case .ONE_MINUS_DST_ALPHA;      it.dstAlphaBlendFactor = .VK_BLEND_FACTOR_ONE_MINUS_DST_ALPHA;
            case .CONSTANT_COLOR;           it.dstAlphaBlendFactor = .VK_BLEND_FACTOR_CONSTANT_COLOR;
            case .ONE_MINUS_CONSTANT_COLOR; it.dstAlphaBlendFactor = .VK_BLEND_FACTOR_ONE_MINUS_CONSTANT_COLOR;
            case .CONSTANT_ALPHA;           it.dstAlphaBlendFactor = .VK_BLEND_FACTOR_CONSTANT_ALPHA;
            case .ONE_MINUS_CONSTANT_ALPHA; it.dstAlphaBlendFactor = .VK_BLEND_FACTOR_ONE_MINUS_CONSTANT_ALPHA;
            case .SRC_ALPHA_SATURATE;       it.dstAlphaBlendFactor = .VK_BLEND_FACTOR_SRC_ALPHA_SATURATE;
            case;                           assertMessage("Unknown destination alpha blend factor: %", color_target.dst_alpha_blend_factor);
        }

        if #complete color_target.alpha_blend_op == {
            case .ADD;              it.alphaBlendOp = .VK_BLEND_OP_ADD;
            case .SUBTRACT;         it.alphaBlendOp = .VK_BLEND_OP_SUBTRACT;
            case .REVERSE_SUBTRACT; it.alphaBlendOp = .VK_BLEND_OP_REVERSE_SUBTRACT;
            case .MIN;              it.alphaBlendOp = .VK_BLEND_OP_MIN;
            case .MAX;              it.alphaBlendOp = .VK_BLEND_OP_MAX;
            case;                   assertMessage("Unknown alpha blend operation: %", color_target.alpha_blend_op);
        }

        it.colorWriteMask = 0;
        if color_target.write_mask & .R then it.colorWriteMask |= .VK_COLOR_COMPONENT_R_BIT;
        if color_target.write_mask & .G then it.colorWriteMask |= .VK_COLOR_COMPONENT_G_BIT;
        if color_target.write_mask & .B then it.colorWriteMask |= .VK_COLOR_COMPONENT_B_BIT;
        if color_target.write_mask & .A then it.colorWriteMask |= .VK_COLOR_COMPONENT_A_BIT;
    }
}

DYNAMIC_STATES :: VkDynamicState.[
    .VK_DYNAMIC_STATE_VIEWPORT,
    .VK_DYNAMIC_STATE_SCISSOR,
];

initDynamicStates :: inline (this : *VkPipelineDynamicStateCreateInfo) #no_context {
    this.sType             = .VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
    this.pNext             = null;
    this.flags             = 0;
    this.dynamicStateCount = DYNAMIC_STATES.count;
    this.pDynamicStates    = DYNAMIC_STATES.data;
}
