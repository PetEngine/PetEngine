ShaderCompiler :: struct {
    SOURCE_SHADERS_FOLDER      :: "../../../source/shaders"; // @TODO: #FileSystem.
    OUTPUT_SHADERS_FOLDER      :: "shaders";                 // @TODO: #FileSystem.
    VERSION                    :: 1;
    INVALID_OFFSET             :: -1;
    MAX_COLOR_TARGETS          :: 8;
    INVALID_COLOR_TARGET_INDEX : u8 : 0xFF;

    Header :: struct {
        version       : u8 = VERSION;
        shader_kind   : Shader.Kind;
        stage_offsets : [#run Basic.enum_highest_value(ShaderStage) + 1] s64;
    } #no_padding

    PipelineState :: union {
        graphics : GraphicsPipelineState;
    } #no_padding

    GraphicsPipelineState :: struct {
        primitive_topology : enum u8{
            POINT_LIST;
            LINE_LIST;
            LINE_STRIP;
            TRIANGLE_LIST;
            TRIANGLE_STRIP;
        } = .TRIANGLE_LIST;

        fill_mode : enum u8 {
            FILL;
            LINE;
        } = .FILL;

        cull_mode : enum u8 {
            NONE;
            FRONT_FACE;
            BACK_FACE;
        } = .NONE;

        front_face : enum u8 {
            CLOCKWISE;
            COUNTER_CLOCKWISE;
        } = .CLOCKWISE;

        depth_bias_enable          := false;
        depth_bias_constant_factor := 0.0;
        depth_bias_clamp           := 0.0;
        depth_bias_slope_factor    := 0.0;
        depth_test_enable          := false;
        depth_write_enable         := false;

        depth_compare_op : enum u8 {
            NEVER;
            ALWAYS;
            NOT_EQUAL;
            EQUAL;
            LESS;
            LESS_OR_EQUAL;
            GREATER;
            GREATER_OR_EQUAL;
        } = .GREATER;

        blend_logic_op_enable := false;

        blend_logic_op : enum u8 {
            ZERO;
            ONE;
            COPY;
            COPY_INVERTED;
            NO_OP;
            INVERT;
            AND;
            AND_REVERSE;
            AND_INVERTED;
            NAND;
            OR;
            OR_REVERSE;
            OR_INVERTED;
            NOR;
            XOR;
            EQUIVALENT;
        } = .COPY;

        color_targets_count : u8;

        color_targets : [MAX_COLOR_TARGETS] struct {
            BlendFactor :: enum u8 {
                ZERO;
                ONE;
                SRC_COLOR;
                ONE_MINUS_SRC_COLOR;
                DST_COLOR;
                ONE_MINUS_DST_COLOR;
                SRC_ALPHA;
                ONE_MINUS_SRC_ALPHA;
                DST_ALPHA;
                ONE_MINUS_DST_ALPHA;
                CONSTANT_COLOR;
                ONE_MINUS_CONSTANT_COLOR;
                CONSTANT_ALPHA;
                ONE_MINUS_CONSTANT_ALPHA;
                SRC_ALPHA_SATURATE;
            }

            BlendOp :: enum u8 {
                ADD;
                SUBTRACT;
                REVERSE_SUBTRACT;
                MIN;
                MAX;
            }

            write_mask : enum_flags u8 {
                R;
                G;
                B;
                A;
            } = .R | .G | .B | .A;

            blend_enable := false;

            src_color_blend_factor : BlendFactor = .SRC_COLOR;
            dst_color_blend_factor : BlendFactor = .ZERO;
            color_blend_op         : BlendOp     = .ADD;
            src_alpha_blend_factor : BlendFactor = .SRC_ALPHA;
            dst_alpha_blend_factor : BlendFactor = .ZERO;
            alpha_blend_op         : BlendOp     = .ADD;
        } #no_padding;
    } #no_padding

    // @TODO: #BindingTable
    BindingTable :: struct {
    } #no_padding
}

ShaderStage :: enum u8 {
    VERTEX;
    FRAGMENT;
}

// @TODO: #DumpShaders. shaderc_compile_into_spv_assembly
compileShader :: (name : string) {
    source_filename := String.join(SOURCE_SHADERS_FOLDER, "/", name, ".shader", allocator = Basic.temporary_allocator);

    source, success := File.read_entire_file(source_filename, log_errors = false);
    assert(success);
    defer Basic.free(source);

    stream := source;

    //
    // 1. Get common shader part
    //

    common_code := getShaderStageCode(*stream);

    //
    // 2. Get code for each shader stage and pipeline state
    //

    shader_kind         := Shader.Kind.UNKNOWN;
    stage_codes         : [Header.stage_offsets.count] string;
    pipeline_state_code : string;

    while stream {
        line := getLine(*stream);

        if line && line[0] == #char "#" {
            line = String.trim_right(line);

            if line == {
                case "#vertex_shader";
                    if shader_kind != .GRAPHICS && shader_kind != .UNKNOWN {
                        errorMessage("Vertex shader stage is unavailable for shader kind %", shader_kind);
                        return;
                    }
                    shader_kind = .GRAPHICS;
                    stage_codes[ShaderStage.VERTEX] = getShaderStageCode(*stream);

                case "#fragment_shader";
                    if shader_kind != .GRAPHICS && shader_kind != .UNKNOWN {
                        errorMessage("Vertex shader stage is unavailable for shader kind %", shader_kind);
                        return;
                    }
                    shader_kind = .GRAPHICS;
                    stage_codes[ShaderStage.FRAGMENT] = getShaderStageCode(*stream);

                case "#pipeline_state";
                    pipeline_state_code = getShaderStageCode(*stream);
            }
        }
    }

    //
    // 3. Parse pipeline state
    //

    pipeline_state : PipelineState;
    if shader_kind == .GRAPHICS {
        parseGraphicsPipelineState(*pipeline_state.graphics, pipeline_state_code);
    } else {
        notImplemented(true);
    }

    //
    // 4. Compile shader stages
    //

    stage_spirvs : [Header.stage_offsets.count] string;

    shaderc_compiler := shaderc_compiler_initialize();
    defer shaderc_compiler_release(shaderc_compiler);

    shaderc_options := shaderc_compile_options_initialize();
    defer shaderc_compile_options_release(shaderc_options);

    shaderc_compile_options_set_source_language(shaderc_options, .shaderc_source_language_glsl);
    #if DEBUG_BUILD {
        shaderc_compile_options_add_macro_definition(shaderc_options,
                                                     cast(*s8) "DEBUG_BUILD".data,
                                                     "DEBUG_BUILD".count,
                                                     cast(*s8) "1".data,
                                                     1);
        shaderc_compile_options_set_generate_debug_info(shaderc_options);
        shaderc_compile_options_set_optimization_level(shaderc_options, .shaderc_optimization_level_zero);
    } else {
        shaderc_compile_options_add_macro_definition(shaderc_options,
                                                     cast(*s8) "DEBUG_BUILD".data,
                                                     "DEBUG_BUILD".count,
                                                     cast(*s8) "0".data,
                                                     1);
        shaderc_compile_options_set_optimization_level(shaderc_options, .shaderc_optimization_level_performance);
    }
    shaderc_compile_options_set_forced_version_profile(shaderc_options, 460, .shaderc_profile_none);
    // @Cleanup: if Vulkan?
    shaderc_compile_options_set_target_env(shaderc_options,
                                           .shaderc_target_env_vulkan,
                                           cast(u32) shaderc_env_version.shaderc_env_version_vulkan_1_3);
    shaderc_compile_options_set_target_spirv(shaderc_options, .shaderc_spirv_version_1_6);
    shaderc_compile_options_set_auto_bind_uniforms(shaderc_options, true);
    // @TODO: shaderc_compile_options_set_binding_base
    shaderc_compile_options_set_auto_map_locations(shaderc_options, true);
    // @TOOD: #Viewport. Experiment with shaderc_compile_options_set_invert_y

    nt_name : string = ---;
    nt_name.count = name.count + 1;
    nt_name.data  = pushToArena(*context.pet.per_frame_arena, u8, nt_name.count);
    memcpy(nt_name.data, name.data, name.count);

    for stage_codes {
        if !it continue;

        SEPARATOR   :: "\n\n";
        full_length := it.count;

        if common_code {
            full_length += common_code.count + SEPARATOR.count;
        }

        code : string = ---;
        code.count = 0;
        code.data  = pushToArena(*context.pet.per_frame_arena, u8, full_length);

        if common_code {
            memcpy(code.data + code.count, common_code.data, common_code.count);
            code.count += common_code.count;

            memcpy(code.data + code.count, SEPARATOR.data, SEPARATOR.count);
            code.count += SEPARATOR.count;
        }

        memcpy(code.data + code.count, it.data, it.count);
        code.count += it.count;

        result := shaderc_compile_into_spv(shaderc_compiler,
                                           cast(*s8) code.data,
                                           cast(u64) code.count,
                                           shaderStageToShadercShaderKind(cast(ShaderStage) it_index),
                                           cast(*s8) nt_name.data,
                                           cast(*s8) "main\0".data,
                                           shaderc_options);
        defer shaderc_result_release(result);

        status := shaderc_result_get_compilation_status(result);
        if status != .shaderc_compilation_status_success {
            error_message := shaderc_result_get_error_message(result);
            errorMessage("% shader compilation failed: %\n%", cast(ShaderStage) it_index, status, to_string(cast(*u8) error_message));
            return;
        }

        stage_spirv := *stage_spirvs[it_index];
        stage_spirv.count = cast(s64) shaderc_result_get_length(result);
        stage_spirv.data  = pushToArena(*context.pet.per_frame_arena, u8, stage_spirv.count);
        memcpy(stage_spirv.data, shaderc_result_get_bytes(result), stage_spirv.count);
    }

    //
    // 5. Get binding table from platform specific intermediate shader language
    //

    // @TODO, @Continue

    //
    // 6. Write everything to file
    //

    header : Header;
    header.shader_kind = shader_kind;

    // @TODO: #BindingTable
    offset := size_of(Header) + size_of(PipelineState);

    for * header.stage_offsets {
        stage_spirv := stage_spirvs[it_index];

        if stage_spirv {
            it.* = offset;
            offset += stage_spirv.count;
        } else {
            it.* = INVALID_OFFSET;
        }
    }

    output_filename := makeBinaryShaderFilename(name);

    output_directory : string = ---;
    output_directory.data  = output_filename.data;
    output_directory.count = String.find_index_from_right(output_filename, #char "/");

    debugCheck(File.make_directory_if_it_does_not_exist(output_directory, true));

    output_file, success= := File.file_open(output_filename, true, log_errors = false);
    assert(success);
    defer File.file_close(*output_file);

    File.file_write(*output_file, *header, size_of(Header));
    File.file_write(*output_file, *pipeline_state, size_of(PipelineState));
    // @TODO: #BindingTable
    for stage_spirvs {
        if it {
            File.file_write(*output_file, it);
        }
    }
}

makeBinaryShaderFilename :: (name : string, allocator := Basic.temporary_allocator) -> string {
    return String.join(OUTPUT_SHADERS_FOLDER, "/", name, ".shader_bin", allocator = allocator);
}

#scope_file

#load "shaderc.jai";
#load "spirv_cross.jai";

using ShaderCompiler;

getLine :: (stream : *string) -> string {
    line : string = ---;
    line.data  = stream.data;
    line.count = 0;

    while stream.* && stream.*[0] != #char "\n" {
        stream.data  += 1;
        stream.count -= 1;
    }

    line.count = cast(s64) (stream.data - line.data);

    if stream.* {
        assert(stream.*[0] == #char "\n");

        stream.data  += 1;
        stream.count -= 1;
    }

    return line;
}

getShaderStageCode :: (stream : *string) -> string {
    stream.* = String.trim_left(stream.*);

    stage_code : string = ---;
    stage_code.data  = stream.data;
    stage_code.count = 0;

    STAGE_KEYWORDS :: string.[
        "#vertex_shader",
        "#fragment_shader",
        "#pipeline_state",
    ];

    line : string;
    while outer_loop := stream.* {
        line = getLine(stream);

        if line && line[0] == #char "#" {
            line = String.trim_right(line);

            // If we met next stage, this is the end.
            for STAGE_KEYWORDS {
                if line == it {
                    break outer_loop;
                }
            }
        }
    }

    if line {
        stage_code.count = cast(s64) (line.data - stage_code.data);

        stream.data   = line.data;
        stream.count += line.count;
    }

    return String.trim_right(stage_code);
}

parseGraphicsPipelineState :: (state : *GraphicsPipelineState, state_code : string) {
    while state_code {
        line := getLine(*state_code);

        if String.starts_with(line, "ColorTarget") {
            line_it : string = ---;
            line_it.data  = line.data  + "ColorTarget".count;
            line_it.count = line.count - "ColorTarget".count;

            line_it = String.trim_left(line_it);
            if line_it.count <= 0 {
                // @TODO: #BetterMessage.
                errorMessage("Compilation failed");
                return;
            }

            color_target_index := getColorTargetIndex(*line_it);
            if color_target_index == INVALID_COLOR_TARGET_INDEX {
                return;
            }

            line_it = String.trim_left(line_it);
            if !line_it || line_it[0] != #char "." {
                // @TODO: #BetterMessage.
                errorMessage("Compilation failed");
                return;
            }

            // Skip "."
            line_it.data  += 1;
            line_it.count -= 1;

            line_it = String.trim_left(line_it);
            if !line_it {
                // @TODO: #BetterMessage.
                errorMessage("Compilation failed");
                return;
            }

            name, value := splitToNameAndValue(line_it);

            if name == {
                case "WriteMask";
                    handleWriteMaskValue(*state.color_targets[color_target_index].write_mask, value);

                case "BlendEnable";
                    handleBoolValue(*state.color_targets[color_target_index].blend_enable, value);

                case "SrcColorBlendFactor";
                    handleEnumValue(*state.color_targets[color_target_index].src_color_blend_factor, value);

                case "DstColorBlendFactor";
                    handleEnumValue(*state.color_targets[color_target_index].dst_color_blend_factor, value);

                case "ColorBlendOp";
                    handleEnumValue(*state.color_targets[color_target_index].color_blend_op, value);

                case "SrcAlphaBlendFactor";
                    handleEnumValue(*state.color_targets[color_target_index].src_alpha_blend_factor, value);

                case "DstAlphaBlendFactor";
                    handleEnumValue(*state.color_targets[color_target_index].dst_alpha_blend_factor, value);

                case "AlphaBlendOp";
                    handleEnumValue(*state.color_targets[color_target_index].alpha_blend_op, value);

                case;
                    // @TODO: #BetterMessage.
                    errorMessage("Compilation failed");
                    return;
            }
        } else {
            name, value := splitToNameAndValue(line);

            if name == {
                case "PrimitiveTopology";
                    handleEnumValue(*state.primitive_topology, value);

                case "FillMode";
                    handleEnumValue(*state.fill_mode, value);

                case "CullMode";
                    handleEnumValue(*state.cull_mode, value);

                case "FrontFace";
                    handleEnumValue(*state.front_face, value);

                case "DepthBiasEnable";
                    handleBoolValue(*state.depth_bias_enable, value);

                case "DepthBiasConstantFactor";
                    handleFloatValue(*state.depth_bias_constant_factor, value);

                case "DepthBiasClamp";
                    handleFloatValue(*state.depth_bias_clamp, value);

                case "DepthBiasSlopeFactor";
                    handleFloatValue(*state.depth_bias_slope_factor, value);

                case "DepthTestEnable";
                    handleBoolValue(*state.depth_test_enable, value);

                case "DepthWriteEnable";
                    handleBoolValue(*state.depth_write_enable, value);

                case "DepthCompareOp";
                    handleEnumValue(*state.depth_compare_op, value);

                case "BlendLogicOpEnable";
                    handleBoolValue(*state.blend_logic_op_enable, value);

                case "BlendLogicOp";
                    handleEnumValue(*state.blend_logic_op, value);

                case;
                    // @TODO: #BetterMessage.
                    errorMessage("Compilation failed");
                    return;
            }
        }
    }
}

splitToNameAndValue :: (line_ : string) -> (name : string, value : string) {
    line := String.trim_left(line_);

    name : string = ---;
    {
        name_end := line;
        while name_end && name_end[0] != #char "=" {
            name_end.data  += 1;
            name_end.count -= 1;
        }

        if name_end[0] != #char "=" {
            // @TODO: #BetterMessage.
            errorMessage("Compilation failed");
            return "", "";
        }

        name.data  = line.data;
        name.count = cast(s64) (name_end.data - line.data);

        name = String.trim_right(name);

        line = name_end;
    }

    // Skip "="
    line.data  += 1;
    line.count -= 1;

    line = String.trim_left(line);

    value : string = ---;
    {
        value_end := line;
        while value_end && value_end[0] != #char ";" {
            value_end.data  += 1;
            value_end.count -= 1;
        }

        if value_end[0] != #char ";" {
            // @TODO: #BetterMessage.
            errorMessage("Compilation failed");
            return "", "";
        }

        value.data  = line.data;
        value.count = cast(s64) (value_end.data - line.data);

        value = String.trim_right(value);
    }

    return name, value;
}

handleEnumValue :: inline (enum_value : *$T, value : string) #modify {
    return (cast(*Type_Info) T).type == .ENUM;
} {
    info := type_info(T);

    for info.names {
        if it == value {
            enum_value.* = cast(T) info.values[it_index];
            return;
        }
    }

    // @TODO: #BetterMessage.
    errorMessage("Compilation failed");
}

handleWriteMaskValue :: (write_mask : *type_of(GraphicsPipelineState.color_targets[0].write_mask), value : string) {
    Type :: type_of(GraphicsPipelineState.color_targets[0].write_mask);
    info := type_info(Type);

    write_mask.* = 0;

    values := value;
    while values {
        found : bool;

        one_value : string = ---;
        one_value.data  = values.data;
        one_value.count = 1;

        for info.names {
            if it == one_value {
                write_mask.* |= cast(Type) info.values[it_index];

                found = true;

                values.data  += 1;
                values.count -= 1;

                break;
            }
        }

        if !found {
            // @TODO: #BetterMessage.
            errorMessage("Compilation failed");
            return;
        }
    }
}

handleBoolValue :: inline (bool_value : *bool, value : string) {
    if value == {
        case "true";
            bool_value.* = true;

        case "false";
            bool_value.* = false;

        case;
            // @TODO: #BetterMessage.
            errorMessage("Compilation failed");
    }
}

handleFloatValue :: inline (float_value : *f32, value : string) {
    f32_value, success := Basic.string_to_float(value);

    if success {
        float_value.* = f32_value;
    } else {
        // @TODO: #BetterMessage.
        errorMessage("Compilation failed");
    }
}

getColorTargetIndex :: (stream : *string) -> u8 {
    line_it := String.trim_left(stream.*);
    defer stream.* = line_it;

    if !line_it || line_it[0] != #char "[" {
        // @TODO: #BetterMessage.
        errorMessage("Compilation failed");
        return INVALID_COLOR_TARGET_INDEX;
    }

    // Skip "["
    line_it.data  += 1;
    line_it.count -= 1;

    line_it = String.trim_left(line_it);
    if !line_it {
        // @TODO: #BetterMessage.
        errorMessage("Compilation failed");
        return INVALID_COLOR_TARGET_INDEX;
    }

    color_target_index, success, line_it= := Basic.string_to_int(line_it, T = u8);
    if !success {
        // @TODO: #BetterMessage.
        errorMessage("Compilation failed");
        return INVALID_COLOR_TARGET_INDEX;
    }

    if color_target_index >= MAX_COLOR_TARGETS {
        // @TODO: #BetterMessage.
        errorMessage("Compilation failed");
        return INVALID_COLOR_TARGET_INDEX;
    }

    line_it = String.trim_left(line_it);
    if !line_it || line_it[0] != #char "]" {
        // @TODO: #BetterMessage.
        errorMessage("Compilation failed");
        return INVALID_COLOR_TARGET_INDEX;
    }

    // Skip "]"
    line_it.data  += 1;
    line_it.count -= 1;

    return color_target_index;
}

shaderStageToShadercShaderKind :: inline (stage : ShaderStage) -> shaderc_shader_kind {
    if #complete stage == {
        case .VERTEX;   return .shaderc_vertex_shader;
        case .FRAGMENT; return .shaderc_fragment_shader;
    }
    return .shaderc_glsl_infer_from_source;
}
