compileShader :: (name : string) {
    source_filename := String.join(SOURCE_SHADERS_FOLDER, "/", name, ".shader", allocator = Basic.temporary_allocator);

    source, success := File.read_entire_file(source_filename);
    assert(success);
    defer Basic.free(source);

    stream := source;

    // 1. Get common shader part
    common_code := getShaderStageCode(*stream);

    line         := stream;
    shader_kind  := Shader.Kind.UNKNOWN;

    stage_codes         : [MAX_STAGES] string;
    pipeline_state_code : string;

    // 2. Get code for each shader stage and pipeline state
    while notEndOfStream(line, stream) {
        next_line := initLineLengthAndGetNextLine(*line, stream);

        if line.count > 0 && line[0] == #char "#" {
            line = String.trim_right(line);

            if line == "#vertex_shader" {
                if shader_kind != .GRAPHICS && shader_kind != .UNKNOWN {
                    errorMessage("Vertex shader stage is unavailable for shader kind %", shader_kind);
                    return;
                }

                shader_kind = .GRAPHICS;

                stage_codes[ShaderStage.VERTEX] = getShaderStageCode(*stream);
            } else if line == "#fragment_shader" {
                if shader_kind != .GRAPHICS && shader_kind != .UNKNOWN {
                    errorMessage("Vertex shader stage is unavailable for shader kind %", shader_kind);
                    return;
                }

                shader_kind = .GRAPHICS;

                stage_codes[ShaderStage.FRAGMENT] = getShaderStageCode(*stream);
            } else if line == "#pipeline_state" {
                // @TODO: Pasrse pipeline state
                pipeline_state_code = getShaderStageCode(*stream);
            }
        }

        moveToNextLine(*line, next_line);
    }

    // 3. Compile shader stages
    // 4. Parse pipeline state
    // 5. Get binding table from platform specific intermediate shader language
    // 6. Write everything to file
    output_filename := String.join(OUTPUT_SHADERS_FOLDER, "/", name, ".shader_bin", allocator = Basic.temporary_allocator);
}

ShaderStage :: enum u8 {
    VERTEX;
    FRAGMENT;
}

#scope_file

SOURCE_SHADERS_FOLDER :: "../../../source/shaders"; // @TODO: #FileSystem.
OUTPUT_SHADERS_FOLDER :: "shaders";                 // @TODO: #FileSystem.
COMPILER_VERSION      :: 1;
INVALID_OFFSET        :: 0xFFFF_FFFF_FFFF_FFFF;
MAX_COLOR_TARGETS     :: 8;
MAX_STAGES            :: #run Basic.enum_highest_value(ShaderStage) + 1;

Header :: struct {
    version        : u8 = COMPILER_VERSION;
    shader_kind    : Shader.Kind;
    stages_count   : u8;
    stages_offsets : [MAX_STAGES] u64;
} #no_padding

GraphicsPipelineState :: struct {
/*
    primitive_topology         : ;
    fill_mode                  : ;
    cull_mode                  : ;
    front_face                 : ;
    depth_bias_enable          : ;
    depth_bias_constant_factor : ;
    depth_bias_clamp           : ;
    depth_bias_slope_factor    : ;
    depth_test_enable          : ;
    depth_write_enable         : ;
    depth_compare_op           : ;
    blend_logic_op_enable      : ;
    blend_logic_op             : ;
    color_targets_count        : u8;
    color_targets              : [MAX_COLOR_TARGETS] struct {
        write_mask             : ;
        blend_enable           : ;
        src_color_blend_factor : ;
        dst_color_blend_factor : ;
        color_blend_op         : ;
        src_alpha_blend_factor : ;
        dst_alpha_blend_factor : ;
        alpha_blend_op         : ;
    } #no_padding;
*/
} #no_padding

// @TODO: #BindingTable
BindingTable :: struct {
} #no_padding

initLineLengthAndGetNextLine :: inline (line : *string, stream : string) -> *u8 {
    next_line := line.data;

    while notEndOfStream(next_line, stream) && next_line.* != #char "\n" {
        next_line += 1;
    }

    line.count = next_line - line.data;

    if notEndOfStream(next_line, stream) {
        next_line += 1;
    }

    return next_line;
}

moveToNextLine :: inline (line : *string, next_line : *u8) {
    line.data = next_line;
}

getShaderStageCode :: (stream : *string) -> string {
    ABORT_STAGE_KEYWORDS :: string.[
        "#vertex_shader",
        "#fragment_shader",
        "#pipeline_state",
    ];

    if stream.count > 0 && stream.data.* == #char "#" {
        line      := stream.*;
        next_line := initLineLengthAndGetNextLine(*line, stream.*);

        line = String.trim_right(line);

        for ABORT_STAGE_KEYWORDS {
            if line == it {
                moveToNextLine(*line, next_line);
                stream.count -= line.data - stream.data;
                stream.data   = line.data;
                break;
            }
        }
    }

    stream.* = String.trim_left(stream.*);
    line := stream.*;

    while outer_loop := notEndOfStream(line, stream.*) {
        next_line := initLineLengthAndGetNextLine(*line, stream.*);

        if line.count > 0 && line[0] == #char "#" {
            line = String.trim_right(line);

            for ABORT_STAGE_KEYWORDS {
                if line == it {
                    break outer_loop;
                }
            }
        }

        moveToNextLine(*line, next_line);
    }

    result : string = ---;
    result.data  = stream.data;
    result.count = line.data - stream.data;

    stream.data   = line.data;
    stream.count -= result.count;

    return String.trim_right(result);
}

notEndOfStream :: inline (iterator : *u8, stream : string) -> bool {
    return iterator - stream.data < stream.count;
}

notEndOfStream :: inline (iterator : string, stream : string) -> bool {
    return notEndOfStream(iterator.data, stream);
}
