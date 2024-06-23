// @TODO:
//     1. Organize bindings by update frequency
//     2. Enrich error messages with <shader name>(col, line)
//     3. Allow comments in pipeline state description
//     4. Dump shaders

ShaderCompiler :: struct {
    VERSION :: 1;

    SOURCE_SHADERS_FOLDER :: "../../../source/shaders";
    OUTPUT_SHADERS_FOLDER :: "shaders";

    MIN_FILE_SIZE :: size_of(Header) + size_of(PipelineState) + size_of(BindingTable);

    INVALID_OFFSET             :: -1;
    INVALID_COLOR_TARGET_INDEX : u8 : 0xFF;

    // @Cleanup: Move these maxs to ShaderManager?
    MAX_STAGES         :: #run Basic.enum_highest_value(ShaderStage) + 1;
    MAX_COLOR_TARGETS  :: 8;
    MAX_PUSH_CONSTANTS :: 8;

    Header :: struct {
        version       : u8 = VERSION;
        shader_kind   : Shader.Kind;
        stage_offsets : [MAX_STAGES] s64;
    } #no_padding

    PipelineState :: union {
        graphics : GraphicsPipelineState;
    } #no_padding

    GraphicsPipelineState :: struct {
        PrimitiveTopology :: enum u8{
            POINT_LIST;
            LINE_LIST;
            LINE_STRIP;
            TRIANGLE_LIST;
            TRIANGLE_STRIP;
        }

        FillMode :: enum u8 {
            FILL;
            LINE;
        }

        CullMode :: enum u8 {
            NONE;
            FRONT_FACE;
            BACK_FACE;
        }

        FrontFace :: enum u8 {
            CLOCKWISE;
            COUNTER_CLOCKWISE;
        }

        DepthCompareOp :: enum u8 {
            NEVER;
            ALWAYS;
            NOT_EQUAL;
            EQUAL;
            LESS;
            LESS_OR_EQUAL;
            GREATER;
            GREATER_OR_EQUAL;
        }

        BlendLogicOp :: enum u8 {
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
        }

        primitive_topology         : PrimitiveTopology = .TRIANGLE_LIST;
        fill_mode                  : FillMode          = .FILL;
        cull_mode                  : CullMode          = .NONE;
        front_face                 : FrontFace         = .CLOCKWISE;
        depth_bias_enable          : bool              = false;
        depth_bias_constant_factor : f32               = 0.0;
        depth_bias_clamp           : f32               = 0.0;
        depth_bias_slope_factor    : f32               = 0.0;
        depth_test_enable          : bool              = false;
        depth_write_enable         : bool              = false;
        depth_compare_op           : DepthCompareOp    = .GREATER;
        blend_logic_op_enable      : bool              = false;
        blend_logic_op             : BlendLogicOp      = .COPY;
        color_targets_count        : u8                = 0;
        color_targets              : [MAX_COLOR_TARGETS] ColorTarget;
    } #no_padding

    ColorTarget :: struct {
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

        WriteMask :: enum_flags u8 {
            RED;
            GREEN;
            BLUE;
            ALPHA;
        }

        write_mask             : WriteMask   = .RED | .GREEN | .BLUE | .ALPHA;
        blend_enable           : bool        = false;
        src_color_blend_factor : BlendFactor = .SRC_COLOR;
        dst_color_blend_factor : BlendFactor = .ZERO;
        color_blend_op         : BlendOp     = .ADD;
        src_alpha_blend_factor : BlendFactor = .SRC_ALPHA;
        dst_alpha_blend_factor : BlendFactor = .ZERO;
        alpha_blend_op         : BlendOp     = .ADD;
    } #no_padding

    BindingTable :: struct {
        PushConstantsRange :: struct {
            stage_flags : ShaderStageFlags;
            offset      : u32;
            bytes       : u32;
        } #no_padding

        Name :: struct {
            length : u8;
            buffer : [127] u8;
        } #no_padding

        #assert size_of(Name) == 128;

        push_constants_count : u8;
        push_constants       : [MAX_PUSH_CONSTANTS] PushConstantsRange;
        push_constants_names : [MAX_PUSH_CONSTANTS] Name;
    } #no_padding

    //
    // Util functions
    //

    getHeader :: inline (file_data : string) -> *Header {
        return cast(*Header) file_data.data;
    }

    getPipelineState :: inline (file_data : string) -> *PipelineState {
        return cast(*PipelineState) (file_data.data + size_of(Header));
    }

    getBindingTable :: inline (file_data : string) -> *BindingTable {
        return cast(*BindingTable) (file_data.data + size_of(Header) + size_of(PipelineState));
    }
}

ShaderStage :: enum u8 {
    VERTEX;
    FRAGMENT;
}

ShaderStageFlags :: enum_flags u8 {
    VERTEX;
    FRAGMENT;
}

compileShader :: (name : string) -> bool {
    infoMessage("Compiling shader \"%\"...", name);

    setArenaMarker(*context.pet.per_frame_arena);
    defer resetArenaToMarker(*context.pet.per_frame_arena);
    Basic.auto_release_temp();

    source_filename := String.join(SOURCE_SHADERS_FOLDER, "/", name, ".shader",, allocator = Basic.temp);

    source     : string     = ---;
    file_error : File.Error = .SHARED_ACCESS_VIOLATION;

    while file_error == .SHARED_ACCESS_VIOLATION {
        source, file_error = readEntireFile(source_filename, pushToArena, *context.pet.per_frame_arena);
    }

    if file_error != .NONE {
        errorMessage("Compilation failed: Unable to open source shader file \"%\"", source_filename);
        return false;
    }

    //
    // 1. Get common shader part
    //

    common_code := getShaderStageCode(*source, name);

    //
    // 2. Get code for each shader stage and pipeline state
    //

    shader_kind         : Shader.Kind = 0xFF;
    stage_codes         : [MAX_STAGES] string;
    pipeline_state_code : string;

    while source {
        line := getLine(*source, name);

        if line && line[0] == #char "#" {
            line = String.trim_right(line);

            if line == {
                case "#vertex_shader";
                    if shader_kind != .GRAPHICS && shader_kind != 0xFF {
                        errorMessage("Vertex shader stage is unavailable for shader kind %", shader_kind);
                        return false;
                    }
                    shader_kind = .GRAPHICS;
                    stage_codes[ShaderStage.VERTEX] = getShaderStageCode(*source, name);

                case "#fragment_shader";
                    if shader_kind != .GRAPHICS && shader_kind != 0xFF {
                        errorMessage("Vertex shader stage is unavailable for shader kind %", shader_kind);
                        return false;
                    }
                    shader_kind = .GRAPHICS;
                    stage_codes[ShaderStage.FRAGMENT] = getShaderStageCode(*source, name);

                case "#pipeline_state";
                    pipeline_state_code = getShaderStageCode(*source, name);
            }
        }
    }

    //
    // 3. Parse pipeline state
    //

    pipeline_state : PipelineState;
    if shader_kind == .GRAPHICS {
        if !parseGraphicsPipelineState(*pipeline_state.graphics, pipeline_state_code, name) {
            // Error message has already been printed in parseGraphicsPipelineState
            return false;
        }
    } else {
        notImplemented(true);
        return false;
    }

    //
    // 4. Compile shader stages
    //

    stage_spirvs : [MAX_STAGES] string;

    shaderc_compiler := shaderc_compiler_initialize();
    defer shaderc_compiler_release(shaderc_compiler);

    shaderc_options := shaderc_compile_options_initialize();
    defer shaderc_compile_options_release(shaderc_options);

    shaderc_compile_options_set_source_language(shaderc_options, .shaderc_source_language_glsl);
    // @Important: Always generate debug info otherwise we won't have push constants' names
    shaderc_compile_options_set_generate_debug_info(shaderc_options);
    #if DEBUG_BUILD {
        shaderc_compile_options_add_macro_definition(shaderc_options,
                                                     cast(*s8) "DEBUG_BUILD".data,
                                                     "DEBUG_BUILD".count,
                                                     cast(*s8) "1".data,
                                                     "1".count);
        shaderc_compile_options_set_optimization_level(shaderc_options, .shaderc_optimization_level_zero);
    } else {
        shaderc_compile_options_add_macro_definition(shaderc_options,
                                                     cast(*s8) "DEBUG_BUILD".data,
                                                     "DEBUG_BUILD".count,
                                                     cast(*s8) "0".data,
                                                     "0".count);
        shaderc_compile_options_set_optimization_level(shaderc_options, .shaderc_optimization_level_performance);
    }
    shaderc_compile_options_set_forced_version_profile(shaderc_options, 460, .shaderc_profile_none);
    // @TODO, @Cleanup: if Vulkan. Get vulkan version from Device.
    shaderc_compile_options_set_target_env(shaderc_options,
                                           .shaderc_target_env_vulkan,
                                           cast(u32) shaderc_env_version.shaderc_env_version_vulkan_1_3);
    shaderc_compile_options_set_target_spirv(shaderc_options, .shaderc_spirv_version_1_6);
    shaderc_compile_options_set_auto_map_locations(shaderc_options, true);
    // @TOOD: #Viewport. Experiment with shaderc_compile_options_set_invert_y
    shaderc_compile_options_set_include_callbacks(shaderc_options, resolveIncludeCallback, releaseIncludeResult, *context);

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

        code := string.{ data = pushToArena(*context.pet.per_frame_arena, u8, full_length) };

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
            errorMessage("% shader compilation is failed with % error(s): %\n%",
                         cast(ShaderStage) it_index,
                         shaderc_result_get_num_errors(result),
                         status,
                         to_string(cast(*u8) shaderc_result_get_error_message(result)));
            return false;
        }

        warnings_count := shaderc_result_get_num_warnings(result);
        if warnings_count {
            warningMessage("% shader compilation is succeeded with % warning(s):\n%",
                           cast(ShaderStage) it_index,
                           warnings_count,
                           to_string(cast(*u8) shaderc_result_get_error_message(result)));
        }

        stage_spirv := *stage_spirvs[it_index];
        stage_spirv.count = cast(s64) shaderc_result_get_length(result);
        stage_spirv.data  = pushToArena(*context.pet.per_frame_arena, u8, stage_spirv.count);
        memcpy(stage_spirv.data, shaderc_result_get_bytes(result), stage_spirv.count);
    }

    //
    // 5. Reflect SPIR-V
    //

    stage_modules : [MAX_STAGES] SpvReflectShaderModule = ---;

    for stage_spirvs {
        debugCheckSpvReflect(spvReflectCreateShaderModule2(.SPV_REFLECT_MODULE_FLAG_NO_COPY,
                                                           cast(u64) it.count,
                                                           it.data,
                                                           *stage_modules[it_index]));
    }
    defer for * stage_modules {
        spvReflectDestroyShaderModule(it);
    }

    //
    // 5.1 Get the actual number of color targets
    //

    {
        fragment_stage_module := *stage_modules[ShaderStage.FRAGMENT];

        if fragment_stage_module.output_variable_count > MAX_COLOR_TARGETS {
            errorMessage("Compilation failed: Too many output variables used in \"%\" shader. Max allowed is %", name, MAX_COLOR_TARGETS);
            return false;
        }

        pipeline_state.graphics.color_targets_count = cast(u8) fragment_stage_module.output_variable_count;
    }

    //
    // 5.2. Get binding table from platform specific intermediate shader language
    //

    binding_table : BindingTable;
    if !reflectPushConstants(*binding_table, stage_modules) {
        // Error message has already been printed in reflectPushConstants
        return false;
    }

    //
    // 6. Write everything to file
    //

    header : Header;
    header.shader_kind = shader_kind;

    offset := MIN_FILE_SIZE;

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
    output_file, file_error= := openFile(output_filename, .WRITE | .TRUNCATE | .SEQ, true);
    if file_error == .NONE {
        writeFile(output_file, *header, size_of(Header));
        writeFile(output_file, *pipeline_state, size_of(PipelineState));
        writeFile(output_file, *binding_table, size_of(BindingTable));
        for stage_spirvs { if it writeFile(output_file, it); }

        closeFile(*output_file);
    } else {
        errorMessage("Compilation failed: Unable to open output shader file \"%\"", output_filename);
        return false;
    }

    infoMessage("Shader \"%\" has been compiled", name);
    return true;
}

makeBinaryShaderFilename :: inline (name : string) -> string {
    capacity := OUTPUT_SHADERS_FOLDER.count + "/".count + name.count + ".shader_bin".count;

    filename := string.{ data = pushToArena(*context.pet.per_frame_arena, capacity) };
    appendToString(*filename, capacity, OUTPUT_SHADERS_FOLDER, "/", name, ".shader_bin");

    return filename;
}

#scope_file

#load "shaderc.jai";
#load "spirv_reflect.jai";

using ShaderCompiler;

getLine :: (stream : *string, name : string) -> string {
    line := string.{ data = stream.data };

    while stream.* && stream.*[0] != #char "\n" {
        advance(stream);
    }

    line.count = cast(s64) (stream.data - line.data);

    assert(!line || line[line.count - 1] != #char "\r", "\"%.shader\": We do not support CRLF line endings in shaders", name);

    if stream.* {
        assert(stream.*[0] == #char "\n");
        advance(stream);
    }

    return line;
}

getShaderStageCode :: (stream : *string, name : string) -> string {
    stream.* = String.trim_left(stream.*);

    stage_code := string.{ data = stream.data };

    STAGE_KEYWORDS :: string.[
        "#vertex_shader",
        "#fragment_shader",
        "#pipeline_state",
    ];

    line : string;
    while outer_loop := stream.* {
        line = getLine(stream, name);

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

parseGraphicsPipelineState :: (state : *GraphicsPipelineState, state_code : string, name : string) -> bool {
    while state_code {
        line := getLine(*state_code, name);
        line = Basic.eat_spaces(line);

        if String.starts_with(line, "//") || String.starts_with(line, "/*") {
            errorMessage("Compilation failed: Comments are not allowed yet in pipeline state description.");
            return false;
        } else  if String.starts_with(line, "ColorTarget") {
            advance(*line, "ColorTarget".count);

            color_target_index, line := getColorTargetIndex(line);
            if color_target_index == INVALID_COLOR_TARGET_INDEX {
                // Error message has already been printed in getColorTargetIndex
                return false;
            }

            line = Basic.eat_spaces(line);
            if !line || line[0] != #char "." {
                errorMessage("Compilation failed: Expected '.', got '%'", ifx line then string.{ 1, line.data } else "<EOL>");
                return false;
            }
            advance(*line);

            name, value, success := splitToNameAndValue(line);
            if !success return false;

            if name == {
                case "WriteMask";
                    handleEnumFlagsValue(*state.color_targets[color_target_index].write_mask, value);

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
                    errorMessage("Compilation failed: unknown name of the ColorTarget[%] setting: '%'", color_target_index, name);
                    return false;
            }
        } else {
            name, value, success := splitToNameAndValue(line);
            if !success return false;

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
                    errorMessage("Compilation failed: unknown name of the graphics pipeline state setting: '%'", name);
                    return false;
            }
        }
    }

    return true;
}

splitToNameAndValue :: (line_ : string) -> (name : string, value : string, success : bool) {
    line := Basic.eat_spaces(line_);

    name : string = ---;
    {
        name_end := line;
        while name_end && name_end[0] != #char "=" {
            advance(*name_end);
        }

        if !name_end || name_end[0] != #char "=" {
            errorMessage("Compilation failed: Expected '=', got '%'", ifx name_end then string.{ 1, name_end.data } else "<EOL>");
            return "", "", false;
        }

        name.data  = line.data;
        name.count = cast(s64) (name_end.data - line.data);

        name = String.trim_right(name);

        line = name_end;
    }

    // Skip "="
    advance(*line);

    line = Basic.eat_spaces(line);

    value : string = ---;
    {
        value_end := line;
        while value_end && value_end[0] != #char ";" {
            advance(*value_end);
        }

        if !value_end || value_end[0] != #char ";" {
            errorMessage("Compilation failed: Expected ';', got '%'", ifx value_end then string.{ 1, value_end.data } else "<EOL>");
            return "", "", false;
        }

        value.data  = line.data;
        value.count = cast(s64) (value_end.data - line.data);

        value = String.trim_right(value);
    }

    return name, value, true;
}

handleEnumValue :: inline (enum_value : *$T, value : string) -> bool {
    #assert (cast(*Type_Info) T).type == .ENUM;
    info := type_info(T);

    for info.names {
        if it == value {
            enum_value.* = cast(T) info.values[it_index];
            return true;
        }
    }

    errorMessage("Compilation failed: invalid enum name: '%'", value);
    return false;
}

handleEnumFlagsValue :: (enum_flags_value : *$T, value : string) -> bool {
    #assert (cast(*Type_Info)      T).type            == .ENUM
         && (cast(*Type_Info_Enum) T).enum_type_flags == .FLAGS;

    assert(value);

    info := type_info(T);

    enum_flags_value.* = 0;

    flag_names_it := value;
    while flag_names_it {
        flag_name_end := flag_names_it;
        while flag_name_end && flag_name_end[0] != #char "|" {
            advance(*flag_name_end);
        }

        flag_name := string.{ cast(s64) (flag_name_end.data - flag_names_it.data), flag_names_it.data };
        flag_name = String.trim_right(flag_name);

        found : bool;
        for info.names {
            if it == flag_name {
                enum_flags_value.* |= cast(ColorTarget.WriteMask) info.values[it_index];

                found = true;
                break;
            }
        }

        if !found {
            errorMessage("Compilation failed: invalid enum_flags name: '%'", value);
            return false;
        }

        flag_names_it = flag_name_end;
        if flag_name_end && flag_names_it[0] == #char "|" {
            advance(*flag_names_it);
        }
        flag_names_it = Basic.eat_spaces(flag_names_it);
    }

    return true;
}

handleBoolValue :: inline (bool_value : *bool, value : string) -> bool {
    if value == {
        case "true";
            bool_value.* = true;

        case "false";
            bool_value.* = false;

        case;
            errorMessage("Compilation failed: inavlid bool value: '%'", value);
            return false;
    }
    return true;
}

handleFloatValue :: inline (float_value : *f32, value : string) -> bool {
    f32_value, success := Basic.string_to_float(value);

    if success {
        float_value.* = f32_value;
    } else {
        errorMessage("Compilation failed: invalid float literal: '%'", value);
    }

    return success;
}

getColorTargetIndex :: (line_ : string) -> (index : u8, line : string) {
    line := Basic.eat_spaces(line_);
    if !line || line[0] != #char "[" {
        errorMessage("Compilation failed: Expected '[', got '%'", ifx line then string.{ 1, line.data } else "<EOL>");
        return INVALID_COLOR_TARGET_INDEX, line;
    }
    advance(*line);

    color_target_index, success, line= := Basic.string_to_int(line, T = u8);
    if !success {
        errorMessage("Compilation failed: Failed to parse index of a color target");
        return INVALID_COLOR_TARGET_INDEX, line;
    }

    if color_target_index >= MAX_COLOR_TARGETS {
        errorMessage("Compilation failed: Too big color target index: %. Maximum allowed: %", color_target_index, MAX_COLOR_TARGETS - 1);
        return INVALID_COLOR_TARGET_INDEX, line;
    }

    line = Basic.eat_spaces(line);
    if !line || line[0] != #char "]" {
        errorMessage("Compilation failed: Expected ']', got '%'", ifx line then string.{ 1, line.data } else "<EOL>");
        return INVALID_COLOR_TARGET_INDEX, line;
    }
    advance(*line);

    return color_target_index, line;
}

shaderStageToShadercShaderKind :: inline (stage : ShaderStage) -> shaderc_shader_kind {
    if #complete stage == {
        case .VERTEX;   return .shaderc_vertex_shader;
        case .FRAGMENT; return .shaderc_fragment_shader;
    }
    return .shaderc_glsl_infer_from_source;
}

debugCheckSpvReflect :: ($code : Code) #expand #no_debug {
    #if DEBUG_BUILD {
        result := #insert code;
        assert(result == .SPV_REFLECT_RESULT_SUCCESS, "% returned %", #run codeToString(code), result);
    } else {
        #insert code;
    }
}

reflectPushConstants :: (binding_table : *BindingTable, stage_modules : [] SpvReflectShaderModule) -> bool {
    for stage_modules {
        stage_flag : ShaderStageFlags = ---;
        if #complete cast(ShaderStage) it_index == {
            case .VERTEX;   stage_flag = .VERTEX;
            case .FRAGMENT; stage_flag = .FRAGMENT;
        }

        for push_constant_block : toView(it.push_constant_blocks, it.push_constant_block_count) {
            push_constant_binding_index := -1;
            for toView(binding_table.push_constants.data, binding_table.push_constants_count) {
                if it.offset == push_constant_block.offset {
                    push_constant_binding_index = it_index;
                    break;
                }
            }

            if push_constant_binding_index != -1 {
                binding_table.push_constants[push_constant_binding_index].stage_flags |= stage_flag;
                continue;
            }

            push_constant_binding := *binding_table.push_constants[binding_table.push_constants_count];
            binding_table.push_constants_count += 1;

            push_constant_binding.stage_flags = stage_flag;
            push_constant_binding.offset      = push_constant_block.offset;
            for toView(push_constant_block.members, push_constant_block.member_count) {
                push_constant_binding.bytes += it.size;
            }

            assert(push_constant_block.name,
                   "A name for push constants instance #%, stage: % is null for some reason. It can be 0 length, but have to be non-null",
                   it_index,
                   stage_flag);

            push_constant_block_name_length := c_style_strlen(cast(*u8) push_constant_block.name);

            if push_constant_block_name_length <= 0 {
                errorMessage("Please, specify push constants instance name #%, stage: % (not the block/type name). It is required for bindings handles",
                             it_index,
                             stage_flag);
                return false;
            }

            if push_constant_block_name_length > BindingTable.Name.buffer.count {
                errorMessage("Too long push constants instance name: %. Current length: %, max allowed: %",
                             string.{ push_constant_block_name_length, cast(*u8) push_constant_block.name },
                             push_constant_block_name_length,
                             BindingTable.Name.buffer.count);
                return false;
            }

            name := *binding_table.push_constants_names[binding_table.push_constants_count - 1];
            name.length = cast(u8) push_constant_block_name_length;
            memcpy(name.buffer.data, push_constant_block.name, push_constant_block_name_length);
        }
    }

    return true;
}

resolveIncludeCallback :: (
    user_data         : *void,
    requested_source  : *s8,
    type              : shaderc_include_type,
    requesting_source : *s8,
    include_depth     : size_t
) -> *shaderc_include_result #c_call {
    push_context,defer_pop cast(*Context) user_data;

    include_filename := String.join(SOURCE_SHADERS_FOLDER, "/", to_string(cast(*u8) requested_source),, allocator = Basic.temp);

    include_result := pushToArena(*context.pet.per_frame_arena, shaderc_include_result);

    content, error := readEntireFile(include_filename, pushToArena, *context.pet.per_frame_arena);
    if error == {
        case .NONE;
            absolute_include_filename := getAbsolutePath(include_filename, pushToArena, *context.pet.per_frame_arena);

            include_result.source_name        = cast(*s8)    absolute_include_filename.data;
            include_result.source_name_length = cast(size_t) absolute_include_filename.count;

            include_result.content        = cast(*s8)    content.data;
            include_result.content_length = cast(size_t) content.count;

        case .FILE_NOT_FOUND; #through;
        case .PATH_NOT_FOUND;
            error_message := Basic.tprint("File \"%\" does not exist. There is a requirement that a path in #include should be specified relative to root shaders folder, maybe you violated it", include_filename);
            include_result.content        = cast(*s8)    error_message.data;
            include_result.content_length = cast(size_t) error_message.count;

        case;
            error_message := Basic.tprint("There was an error in opening \"%\" file. Look at previous error messages to get what went wrong", include_filename);
            include_result.content        = cast(*s8)    error_message.data;
            include_result.content_length = cast(size_t) error_message.count;
    }

    return include_result;
}

releaseIncludeResult :: (user_data : *void, include_result : *shaderc_include_result) #c_call {
    // Everything is in per frame arena, so we do not need to free anything
}
