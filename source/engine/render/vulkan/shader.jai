VulkanShaderManager :: struct {
    #as using public_data : ShaderManager;

    ResetData :: struct {
        pipeline        : VkPipeline;
        pipeline_layout : VkPipelineLayout;
    }

    PerFrameResetData :: struct {
        data  : StaticArray(ResetData, MAX_SHADERS);
        mutex : Mutex;
    }

    pipeline_cache  : VkPipelineCache;
    shaders_storage : [MAX_SHADERS] VulkanShader;

    per_frame_reset_data : StaticArray(PerFrameResetData, Device.MAX_FRAME_BUFFERING);
}

createVulkanShaderManager :: () {
    manager := pushToArena(*context.pet.arenas.persistent, VulkanShaderManager);
    context.pet.render.shader_manager = manager;

    device := cast(*VulkanDevice) context.pet.render.device;

    manager.per_frame_reset_data.count = cast,no_check(s64) device.frame_buffering;

    #insert -> string { return generatePlatformVtableInitialization(ShaderManager, "manager", "Vulkan"); }

    create_info : VkPipelineCacheCreateInfo;
    debugCheckVK(vkCreatePipelineCache(device.device, *create_info, null, *manager.pipeline_cache));
}

destroyVulkanShaderManager :: () {
    device  := cast(*VulkanDevice)        context.pet.render.device;
    manager := cast(*VulkanShaderManager) context.pet.render.shader_manager;

    vkDestroyPipelineCache(device.device, manager.pipeline_cache, null);

    for toView(manager.shaders_storage.data, manager.shaders_count) {
        vkDestroyPipeline(device.device, it.pipeline, null);
        vkDestroyPipelineLayout(device.device, it.pipeline_layout, null);
    }
}

resetVulkanShaderManager :: () {
    assertThreadKind(.MAIN);

    device  := cast(*VulkanDevice)        context.pet.render.device;
    manager := cast(*VulkanShaderManager) context.pet.render.shader_manager;

    // @TODO: #FrameBuffering.
    assert(manager.per_frame_reset_data.count == cast,no_check(s64) device.frame_buffering, "It's illegal to change frame buffering for now");
    manager.per_frame_reset_data.count = cast,no_check(s64) device.frame_buffering;

    reset_data := *manager.per_frame_reset_data[device.frame_index];
    if reset_data.data.count > 0 {
        scopedLock(*reset_data.mutex);

        waitVulkanDeviceIdle();

        for reset_data.data {
            if it.pipeline {
                vkDestroyPipeline(device.device, it.pipeline, null);
                it.pipeline = VK_NULL_HANDLE;
            }

            if it.pipeline_layout {
                vkDestroyPipelineLayout(device.device, it.pipeline_layout, null);
                it.pipeline_layout = VK_NULL_HANDLE;
            }
        }

        reset_data.data.count = 0;
    }
}

findVulkanShader :: (name : string) -> *Shader #must {
    manager := cast(*VulkanShaderManager) context.pet.render.shader_manager;

    for * toView(manager.shaders_storage.data, manager.shaders_count) {
        if it.name == name {
            return it;
        }
    }

    return null;
}

VulkanShader :: struct {
    #as using public_data : Shader;

    pipeline_layout : VkPipelineLayout;
    pipeline        : VkPipeline;
}

pushVulkanShader :: () -> *Shader #must {
    manager := cast(*VulkanShaderManager) context.pet.render.shader_manager;

    assert(manager.shaders_count < manager.shaders_storage.count,
           "Too many shaders were created. Consider increasing ShaderManager.MAX_SHADERS");

    shader := *manager.shaders_storage[manager.shaders_count];
    manager.shaders_count += 1;

    return shader;
}

createGraphicsVulkanShader :: (shader_ : *Shader, shader_file_data : string) {
    device := cast(*VulkanDevice) context.pet.render.device;
    shader := cast(*VulkanShader) shader_;

    shader_file_header := ShaderCompiler.getHeader(shader_file_data);

    shader_stages : [ShaderCompiler.MAX_STAGES] VkShaderModule = ---;
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

        spirv := string.{ next_stage_offset - this_stage_offset, *shader_file_data[this_stage_offset] };

        it.* = createShaderStage(spirv, cast(ShaderStage) it_index, shader.name);
    }
    defer for shader_stages {
        vkDestroyShaderModule(device.device, it, null);
    }

    {
        binding_manager := cast(*VulkanBindingManager) context.pet.render.binding_manager;

        descriptor_set_layouts : [BindingManager.MAX_DESCRIPTOR_SETS] VkDescriptorSetLayout;
        for binding_manager.descriptor_set_layouts {
            descriptor_set_layouts[it_index] = it.layout;
        }

        ranges : [ShaderCompiler.MAX_PUSH_CONSTANTS] VkPushConstantRange;
        fillPushConstantRanges(ranges, *shader.binding_table);

        create_info := VkPipelineLayoutCreateInfo.{
            setLayoutCount         = descriptor_set_layouts.count,
            pSetLayouts            = descriptor_set_layouts.data,
            pushConstantRangeCount = shader.binding_table.push_constants_count,
            pPushConstantRanges    = ranges.data,
        };

        debugCheckVK(vkCreatePipelineLayout(device.device, *create_info, null, *shader.pipeline_layout));

        setVulkanObjectName(shader.pipeline_layout, "% pipeline layout", shader.name);
    }

    #if DEBUG_BUILD {
        DEBUG_PIPELINE_CREATE_FLAGS : VkPipelineCreateFlags : .VK_PIPELINE_CREATE_DISABLE_OPTIMIZATION_BIT;
    } else {
        DEBUG_PIPELINE_CREATE_FLAGS : VkPipelineCreateFlags : 0;
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

    pipeline_state          := ShaderCompiler.getPipelineState(shader_file_data);
    graphics_pipeline_state := *pipeline_state.graphics;

    vertex_input_state : VkPipelineVertexInputStateCreateInfo;

    input_assembly_state : VkPipelineInputAssemblyStateCreateInfo;
    initInputAssemblyState(*input_assembly_state, graphics_pipeline_state);

    viewport_state := VkPipelineViewportStateCreateInfo.{
        viewportCount = 1,
        scissorCount  = 1,
    };

    rasterization_state : VkPipelineRasterizationStateCreateInfo = ---;
    initRasterizationState(*rasterization_state, graphics_pipeline_state);

    multisample_state : VkPipelineMultisampleStateCreateInfo = ---;
    initMultisampleState(*multisample_state);

    depth_stencil_state : VkPipelineDepthStencilStateCreateInfo = ---;
    initDepthStencilState(*depth_stencil_state, graphics_pipeline_state);

    color_blend_state : VkPipelineColorBlendStateCreateInfo = ---;
    initColorBlendState(*color_blend_state, graphics_pipeline_state);
    assert(color_blend_state.attachmentCount == shader.color_target_formats.count);

    dynamic_state : VkPipelineDynamicStateCreateInfo = ---;
    initDynamicStates(*dynamic_state);

    color_target_vk_formats : StaticArray(VkFormat, Shader.color_target_formats.capacity);
    color_target_vk_formats.count = shader.color_target_formats.count;
    for shader.color_target_formats {
        color_target_vk_formats[it_index] = textureFormatToVulkanFormat(it);
    }

    depth_target_format_flags := textureFormatFlags(shader.depth_target_format);
    depth_target_vk_format    := textureFormatToVulkanFormat(shader.depth_target_format);

    pipeline_rendering_create_info := VkPipelineRenderingCreateInfo.{
        viewMask                = 0,
        colorAttachmentCount    = cast(u32) color_target_vk_formats.count,
        pColorAttachmentFormats = color_target_vk_formats.data.data,
        depthAttachmentFormat   = ifx depth_target_format_flags & .DEPTH   then depth_target_vk_format else .VK_FORMAT_UNDEFINED,
        stencilAttachmentFormat = ifx depth_target_format_flags & .STENCIL then depth_target_vk_format else .VK_FORMAT_UNDEFINED,
    };

    create_info := VkGraphicsPipelineCreateInfo.{
        pNext               = *pipeline_rendering_create_info,
        flags               = DEBUG_PIPELINE_CREATE_FLAGS,
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

    if device.descriptor_buffers_supported {
        create_info.flags |= .VK_PIPELINE_CREATE_DESCRIPTOR_BUFFER_BIT_EXT;
    }

    manager := cast(*VulkanShaderManager) context.pet.render.shader_manager;

    debugCheckVK(vkCreateGraphicsPipelines(device.device, manager.pipeline_cache, 1, *create_info, null, *shader.pipeline));

    setVulkanObjectName(shader.pipeline, "% graphics pipeline", shader.name);
}

reloadGraphicsVulkanShader :: (shader_ : *Shader, shader_file_data : string) {
    manager := cast(*VulkanShaderManager) context.pet.render.shader_manager;
    shader  := cast(*VulkanShader)        shader_;

    reset_data := VulkanShaderManager.ResetData.{
        pipeline        = shader.pipeline,
        pipeline_layout = shader.pipeline_layout
    };

    createGraphicsVulkanShader(shader, shader_file_data);

    per_frame_reset_data := *manager.per_frame_reset_data[context.pet.render.device.frame_index];
    scopedLock(*per_frame_reset_data.mutex);

    pushBack(*per_frame_reset_data.data, reset_data);
}

shaderStageToVulkanStage :: inline (stage : ShaderStage) -> VkShaderStageFlags #no_context {
    if #complete stage == {
        case .VERTEX;   return .VK_SHADER_STAGE_VERTEX_BIT;
        case .FRAGMENT; return .VK_SHADER_STAGE_FRAGMENT_BIT;
    }
    return 0;
}

shaderStageFlagsToVulkanStageFlags :: inline (stage : ShaderStageFlags) -> VkShaderStageFlags #no_context {
    vk_flags : VkShaderStageFlags;
    if stage & .VERTEX   then vk_flags |= .VK_SHADER_STAGE_VERTEX_BIT;
    if stage & .FRAGMENT then vk_flags |= .VK_SHADER_STAGE_FRAGMENT_BIT;
    return vk_flags;
}

#scope_file

createShaderStage :: (spirv : string, stage : ShaderStage, shader_name : string) -> VkShaderModule #must {
    device := cast(*VulkanDevice) context.pet.render.device;

    create_info := VkShaderModuleCreateInfo.{
        codeSize = cast(size_t) spirv.count,
        pCode    = cast(*u32)   spirv.data,
    };

    module : VkShaderModule;
    debugCheckVK(vkCreateShaderModule(device.device, *create_info, null, *module));

    setVulkanObjectName(module, "% stage % shader module", stage, shader_name);

    return module;
}

fillPushConstantRanges :: inline (ranges : [] VkPushConstantRange, binding_table : *ShaderCompiler.BindingTable) #no_context {
    for toView(binding_table.push_constants.data, binding_table.push_constants_count) {
        range := *ranges[it_index];
        range.stageFlags = shaderStageFlagsToVulkanStageFlags(it.stage_flags);
        range.offset     = it.offset;
        range.size       = it.bytes;
    }
}

initInputAssemblyState :: inline (this : *VkPipelineInputAssemblyStateCreateInfo, state : *ShaderCompiler.GraphicsPipelineState) {
    if #complete state.primitive_topology == {
        case .POINT_LIST;     this.topology = .VK_PRIMITIVE_TOPOLOGY_POINT_LIST;
        case .LINE_LIST;      this.topology = .VK_PRIMITIVE_TOPOLOGY_LINE_LIST;
        case .LINE_STRIP;     this.topology = .VK_PRIMITIVE_TOPOLOGY_LINE_STRIP;
        case .TRIANGLE_LIST;  this.topology = .VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
        case .TRIANGLE_STRIP; this.topology = .VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP;
        case;                 assertMessage("Unknown topology: %", state.primitive_topology);
    }

    this.primitiveRestartEnable = cast,no_check(VkBool32) (   this.topology == .VK_PRIMITIVE_TOPOLOGY_LINE_STRIP
                                                           || this.topology == .VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP
                                                           || this.topology == .VK_PRIMITIVE_TOPOLOGY_TRIANGLE_FAN
                                                           || this.topology == .VK_PRIMITIVE_TOPOLOGY_LINE_STRIP_WITH_ADJACENCY
                                                           || this.topology == .VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP_WITH_ADJACENCY);
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

// @TODO: #ShaderCompiler.
initMultisampleState :: inline (this : *VkPipelineMultisampleStateCreateInfo) #no_context {
    this.sType                 = .VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
    this.pNext                 = null;
    this.flags                 = 0;
    this.rasterizationSamples  = .VK_SAMPLE_COUNT_1_BIT;
    this.sampleShadingEnable   = VK_FALSE;
    this.minSampleShading      = 0.0;
    this.pSampleMask           = null; // If pSampleMask is NULL, it is treated as if the mask has all bits set to 1.
    this.alphaToCoverageEnable = VK_FALSE;
    this.alphaToOneEnable      = VK_FALSE;
}

// @TODO: #ShaderCompiler.
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

    this.blendConstants  = .[ 0.0, 0.0, 0.0, 0.0 ];
    this.attachmentCount = state.color_targets_count;
    if this.attachmentCount {
        this.pAttachments = pushToArena(*context.pet.arenas.per_frame, VkPipelineColorBlendAttachmentState, this.attachmentCount);

        for * toView(this.pAttachments, this.attachmentCount) {
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
            if color_target.write_mask & .RED   then it.colorWriteMask |= .VK_COLOR_COMPONENT_R_BIT;
            if color_target.write_mask & .GREEN then it.colorWriteMask |= .VK_COLOR_COMPONENT_G_BIT;
            if color_target.write_mask & .BLUE  then it.colorWriteMask |= .VK_COLOR_COMPONENT_B_BIT;
            if color_target.write_mask & .ALPHA then it.colorWriteMask |= .VK_COLOR_COMPONENT_A_BIT;
        }
    } else {
        this.pAttachments = null;
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
