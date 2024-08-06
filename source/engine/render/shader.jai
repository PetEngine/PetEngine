ShaderManager :: struct {
    MAX_SHADERS :: 1024;

    shaders_count : s64;

    //
    // VTable
    //

    destroyPlatformShaderManager : ();
    resetPlatformShaderManager   : ();

    pushPlatformShader : () -> *Shader #must;

    createGraphicsPlatformShader : (shader : *Shader, shader_file_data : string);

    findPlatformShader           : (name : string) -> *Shader #must;
    reloadGraphicsPlatformShader : (shader : *Shader, shader_file_data : string);
}

createShaderManager :: inline () {
    assert(!context.pet.render.shader_manager);

    if #complete context.pet.render.device.graphics_api == {
        case .VULKAN;
           createVulkanShaderManager();
    }
}

destroyShaderManager :: inline () {
    context.pet.render.shader_manager.destroyPlatformShaderManager();
}

resetShaderManager :: inline () {
    context.pet.render.shader_manager.resetPlatformShaderManager();
}

Shader :: struct {
    Kind :: enum u8 {
        GRAPHICS;
        MESH;
        COMPUTE;
        RAY_TRACING;
    }

    kind : Kind;
    name : string;

    color_target_formats : StaticArray(Texture.Format, ShaderCompiler.MAX_COLOR_TARGETS);
    depth_target_format  : Texture.Format;

    binding_table : ShaderCompiler.BindingTable;
}

PushConstantsHandle :: struct {
    INVALID_INDEX :: ShaderCompiler.MAX_PUSH_CONSTANTS;

    index : u8 = INVALID_INDEX;
}

createShader :: (name : string, color_target_formats : [] Texture.Format, depth_target_format : Texture.Format = .UNKNOWN) -> *Shader #must {
    assert(color_target_formats.count <= Shader.color_target_formats.capacity);

    shader := context.pet.render.shader_manager.pushPlatformShader();
    shader.name = name;

    shader_file_data := deserializeShaderFile(shader);
    if !shader_file_data return shader;

    if #complete shader.kind == {
        case .GRAPHICS;
            pushBack(*shader.color_target_formats, color_target_formats);
            shader.depth_target_format = depth_target_format;

            context.pet.render.shader_manager.createGraphicsPlatformShader(shader, shader_file_data);

        case .MESH;        #through;
        case .COMPUTE;     #through;
        case .RAY_TRACING;
            notImplemented(true);
    }

    return shader;
}

findShader :: inline (name : string) -> *Shader #must {
    return context.pet.render.shader_manager.findPlatformShader(name);
}

reloadShader :: (shader : *Shader) {
    shader_file_data := deserializeShaderFile(shader);
    if !shader_file_data return;

    if #complete shader.kind == {
        case .GRAPHICS;
            context.pet.render.shader_manager.reloadGraphicsPlatformShader(shader, shader_file_data);

        case .MESH;        #through;
        case .COMPUTE;     #through;
        case .RAY_TRACING;
            notImplemented(true);
    }
}

getPushConstantsHandle :: (shader : *Shader, name : string) -> PushConstantsHandle {
    handle : PushConstantsHandle;
    for toView(shader.binding_table.push_constants_names.data, shader.binding_table.push_constants_count) {
        name_in_table := string.{ count = it.length, data = it.buffer.data };
        if name_in_table == name {
            handle.index = cast(u8) it_index;
            break;
        }
    }
    return handle;
}

#scope_file

deserializeShaderFile :: (shader : *Shader) -> string {
    shader_file_data, file_error := readEntireFile(makeBinaryShaderFilename(shader.name), pushToArena, *context.pet.arenas.per_frame);
    if file_error != .NONE {
        errorMessage("Shader \"%\" was not found", shader.name);
        return "";
    }

    assert(shader_file_data.count >= ShaderCompiler.MIN_FILE_SIZE);

    shader_file_header := ShaderCompiler.getHeader(shader_file_data);
    assert(shader_file_header.version == ShaderCompiler.VERSION);

    shader.kind          = shader_file_header.shader_kind;
    shader.binding_table = ShaderCompiler.getBindingTable(shader_file_data).*;

    return shader_file_data;
}

#load "vulkan/shader.jai";
