#scope_export

// @TODO: #EfficientBindings.
//      - @Continue: Descriptor buffers

VulkanShaderManager :: struct {
    #as using public_data : ShaderManager;

    ResetData :: struct {
        pipeline               : VkPipeline;
        pipeline_layout        : VkPipelineLayout;
        descriptor_set_layouts : StaticArray(VkDescriptorSetLayout, ShaderCompiler.MAX_DESCRIPTOR_SETS);
    }

    PerFrameResetData :: struct {
        data  : StaticArray(ResetData, MAX_SHADERS);
        mutex : Mutex;
    }

    pipeline_cache  : VkPipelineCache;
    shaders_storage : [MAX_SHADERS] VulkanShader;

    per_frame_reset_data : StaticArray(PerFrameResetData, Device.MAX_FRAME_BUFFERING);
}

createVulkanShaderManager :: (device : *VulkanDevice) -> *VulkanShaderManager #must {
    manager := pushToArena(*context.pet.persistent_arena, VulkanShaderManager);
    manager.per_frame_reset_data.count = cast,no_check(s64) device.frame_buffering;

    #insert -> string { return generatePlatformVtableInitialization(ShaderManager, "manager", "Vulkan"); }

SHADER_LIMITS_FORMAT_STRING :: #string END
Shader limits:
    Max bound descriptor sets           = %
    Max bound samplers                  = %
    Max bound uniform buffers           = %
    Max bound storage buffers           = %
    Max bound sampled images            = %
    Max bound storage images            = %
    Max bound samplers per stage        = %
    Max bound uniform buffers per stage = %
    Max bound storage buffers per stage = %
    Max bound sampled images per stage  = %
    Max bound storage images per stage  = %
END;

    verboseMessage(SHADER_LIMITS_FORMAT_STRING,
                   device.limits.maxBoundDescriptorSets,
                   device.limits.maxDescriptorSetSamplers,
                   device.limits.maxDescriptorSetUniformBuffers,
                   device.limits.maxDescriptorSetStorageBuffers,
                   device.limits.maxDescriptorSetSampledImages,
                   device.limits.maxDescriptorSetStorageImages,
                   device.limits.maxPerStageDescriptorSamplers,
                   device.limits.maxPerStageDescriptorUniformBuffers,
                   device.limits.maxPerStageDescriptorStorageBuffers,
                   device.limits.maxPerStageDescriptorSampledImages,
                   device.limits.maxPerStageDescriptorStorageImages);

    // @TODO: #PipelineCache. Initial data.
    create_info : VkPipelineCacheCreateInfo;
    debugCheckVK(vkCreatePipelineCache(device.device, *create_info, null, *manager.pipeline_cache));

    return manager;
}

destroyVulkanShaderManager :: (device_ : *Device, manager_ : *ShaderManager) {
    device  := cast(*VulkanDevice)        device_;
    manager := cast(*VulkanShaderManager) manager_;

    vkDestroyPipelineCache(device.device, manager.pipeline_cache, null);

    for toView(manager.shaders_storage.data, manager.shaders_count) {
        vkDestroyPipeline(device.device, it.pipeline, null);
        vkDestroyPipelineLayout(device.device, it.pipeline_layout, null);

        for it.descriptor_set_layouts {
            if it != VK_NULL_HANDLE {
                vkDestroyDescriptorSetLayout(device.device, it, null);
            }
        }
    }
}

resetVulkanShaderManager :: (device_ : *Device, manager_ : *ShaderManager) {
    device  := cast(*VulkanDevice)        device_;
    manager := cast(*VulkanShaderManager) manager_;

    assertThreadKind(.MAIN);

    reset_data := *manager.per_frame_reset_data[device.frame_index];
    scopedLock(*reset_data.mutex);

    if reset_data.data.count > 0 {
        waitVulkanDeviceIdle(device);

        for reset_data.data {
            if it.pipeline {
                // @TODO: #VkAllocationCallbacks
                vkDestroyPipeline(device.device, it.pipeline, null);
                it.pipeline = VK_NULL_HANDLE;
            }

            if it.pipeline_layout {
                // @TODO: #VkAllocationCallbacks
                vkDestroyPipelineLayout(device.device, it.pipeline_layout, null);
                it.pipeline_layout = VK_NULL_HANDLE;
            }

            for * descriptor_set_layout : it.descriptor_set_layouts {
                if descriptor_set_layout.* {
                    vkDestroyDescriptorSetLayout(device.device, descriptor_set_layout.*, null);
                    descriptor_set_layout.* = VK_NULL_HANDLE;
                }
            }
        }

        reset_data.data.count = 0;
    }
}

findVulkanShader :: (manager_ : *ShaderManager, name : string) -> *Shader #must #no_context {
    manager := cast(*VulkanShaderManager) manager_;

    shaders_it := manager.shaders_storage.data;
    for 0 .. manager.shaders_count {
        if shaders_it.name == name {
            return shaders_it;
        }
        shaders_it += 1;
    }
    return null;
}

VulkanShader :: struct {
    #as using public_data : Shader;

    pipeline_layout : VkPipelineLayout;
    pipeline        : VkPipeline;

    descriptor_set_layouts : StaticArray(VkDescriptorSetLayout, ShaderCompiler.MAX_DESCRIPTOR_SETS);
}

pushVulkanShader :: (manager_ : *ShaderManager) -> *Shader #must {
    manager := cast(*VulkanShaderManager) manager_;

    assert(manager.shaders_count < manager.shaders_storage.count,
           "Too many shaders were created. Consider increasing ShaderManager.MAX_SHADERS");

    shader := *manager.shaders_storage[manager.shaders_count];
    manager.shaders_count += 1;

    return shader;
}

createGraphicsVulkanShader :: (device_ : *Device, manager_ : *ShaderManager, shader_ : *Shader, shader_file_data : string) {
    device  := cast(*VulkanDevice)        device_;
    manager := cast(*VulkanShaderManager) manager_;
    shader  := cast(*VulkanShader)        shader_;

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

        it.* = createShaderStage(device, spirv, cast(ShaderStage) it_index, shader.name);
    }
    defer for shader_stages {
        // @TODO: #VkAllocationCallbacks
        vkDestroyShaderModule(device.device, it, null);
    }

    createDescriptorSetLayouts(device, manager, shader);

    {
        ranges : [ShaderCompiler.MAX_PUSH_CONSTANTS] VkPushConstantRange;
        fillPushConstantRanges(ranges, *shader.binding_table);

        create_info := VkPipelineLayoutCreateInfo.{
            setLayoutCount         = cast(u32) shader.descriptor_set_layouts.count,
            pSetLayouts            = shader.descriptor_set_layouts.data.data,
            pushConstantRangeCount = shader.binding_table.push_constants_count,
            pPushConstantRanges    = ranges.data,
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

    pipeline_state          := ShaderCompiler.getPipelineState(shader_file_data);
    graphics_pipeline_state := *pipeline_state.graphics;

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

reloadGraphicsVulkanShader :: (device_ : *Device, manager_ : *ShaderManager, shader_ : *Shader, shader_file_data : string) {
    device  := cast(*VulkanDevice)        device_;
    manager := cast(*VulkanShaderManager) manager_;
    shader  := cast(*VulkanShader)        shader_;

    reset_data := VulkanShaderManager.ResetData.{
        pipeline               = shader.pipeline,
        pipeline_layout        = shader.pipeline_layout,
        descriptor_set_layouts = shader.descriptor_set_layouts,
    };

    createGraphicsVulkanShader(device, manager, shader, shader_file_data);

    per_frame_reset_data := *manager.per_frame_reset_data[device.frame_index];
    scopedLock(*per_frame_reset_data.mutex);

    pushBack(*per_frame_reset_data.data).* = reset_data;
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

descriptorTypeToVulkanDescriptorType :: inline (type : ShaderCompiler.BindingTable.DescriptorType) -> VkDescriptorType {
    if type == {
        case .BUFFER_CBV;  return .VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
        case .BUFFER_SRV;  return .VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        case .BUFFER_UAV;  return .VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        case .TEXTURE_SRV; return .VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE;
        case .TEXTURE_UAV; return .VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
        case .SAMPLER;     return .VK_DESCRIPTOR_TYPE_SAMPLER;
    }

    assert(false, "Unhandled descriptor type: %", type);
    return 0xFFFF_FFFF;
}

#scope_file

createShaderStage :: (device : *VulkanDevice, spirv : string, stage : ShaderStage, shader_name : string) -> VkShaderModule #must {
    create_info := VkShaderModuleCreateInfo.{
        codeSize = cast(size_t) spirv.count,
        pCode    = cast(*u32)   spirv.data,
    };

    module : VkShaderModule;
    debugCheckVK(vkCreateShaderModule(device.device, *create_info, null, *module)); // @TODO: VkAllocationCallbacks

    setVulkanObjectName(device, module, "% stage % shader module", stage, shader_name);

    return module;
}

createDescriptorSetLayouts :: (device : *VulkanDevice, manager : *VulkanShaderManager, shader : *VulkanShader) {
    shader.descriptor_set_layouts.count = shader.binding_table.descriptor_sets_count;

    for set_bindings, set_index : toView(shader.binding_table.bindings.data, shader.binding_table.descriptor_sets_count) {
        bindings_count := shader.binding_table.bindings_count[set_index];
        if !bindings_count continue;

        binding_layouts : [ShaderCompiler.MAX_BINDINGS] VkDescriptorSetLayoutBinding;

        for binding, binding_index : toView(set_bindings.data, bindings_count) {
            if binding.descriptor_type != .UNKNOWN {
                binding_layout := *binding_layouts[binding_index];
                binding_layout.binding         = cast(u32) binding_index;
                binding_layout.descriptorType  = descriptorTypeToVulkanDescriptorType(binding.descriptor_type);
                binding_layout.descriptorCount = binding.descriptors_count;
                binding_layout.stageFlags      = shaderStageFlagsToVulkanStageFlags(binding.stage_flags);
            }
        }

        create_info := VkDescriptorSetLayoutCreateInfo.{
            flags        = .VK_DESCRIPTOR_SET_LAYOUT_CREATE_DESCRIPTOR_BUFFER_BIT_EXT,
            bindingCount = bindings_count,
            pBindings    = binding_layouts.data,
        };

        debugCheckVK(vkCreateDescriptorSetLayout(device.device, *create_info, null, *shader.descriptor_set_layouts[set_index]));

        setVulkanObjectName(device, shader.descriptor_set_layouts[set_index], "% descriptor set layout #%", shader.name, set_index);
    }
}

fillPushConstantRanges :: inline (ranges : [] VkPushConstantRange, binding_table : *ShaderCompiler.BindingTable) #no_context {
    for toView(binding_table.push_constants.data, binding_table.push_constants_count) {
        range := *ranges[it_index];
        range.stageFlags = shaderStageFlagsToVulkanStageFlags(it.stage_flags);
        range.offset     = it.offset;
        range.size       = it.bytes;
    }
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

    this.blendConstants  = .[ 0.0, 0.0, 0.0, 0.0 ];
    this.attachmentCount = state.color_targets_count;
    if this.attachmentCount {
        this.pAttachments = pushToArena(*context.pet.per_frame_arena, VkPipelineColorBlendAttachmentState, this.attachmentCount);

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
