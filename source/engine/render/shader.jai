ShaderManager :: struct {
    MAX_SHADERS :: 1024;

    shaders_count : s64;

    //
    // VTable
    //

    destroyPlatformShaderManager : (device : *Device, manager : *ShaderManager);
    resetPlatformShaderManager   : (device : *Device, manager : *ShaderManager);

    pushPlatformShader : (manager : *ShaderManager) -> *Shader #must;

    createGraphicsPlatformShader : (device : *Device, manager : *ShaderManager, binding_manager : *BindingManager, shader : *Shader, shader_file_data : string);

    findPlatformShader           : (manager : *ShaderManager, name : string) -> *Shader #must #no_context;
    reloadGraphicsPlatformShader : (device : *Device, manager : *ShaderManager, binding_manager : *BindingManager, shader : *Shader, shader_file_data : string);
}

createShaderManager :: (device : *Device, resource_manager : *ResourceManager) -> *ShaderManager #must {
    manager : *ShaderManager;

    if #complete device.graphics_api == {
        case .VULKAN;
           manager = createVulkanShaderManager(cast(*VulkanDevice) device, cast(*VulkanResourceManager) resource_manager);
    }

    return manager;
}

destroyShaderManager :: inline (device : *Device, manager : *ShaderManager) {
    manager.destroyPlatformShaderManager(device, manager);
}

resetShaderManager :: inline (device : *Device, manager : *ShaderManager) {
    manager.resetPlatformShaderManager(device, manager);
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

createShader :: (
    device               : *Device,
    manager              : *ShaderManager,
    binding_manager      : *BindingManager,
    name                 : string,
    color_target_formats : [] Texture.Format,
    depth_target_format  : Texture.Format = .UNKNOWN
) -> *Shader #must {
    assert(color_target_formats.count <= Shader.color_target_formats.capacity);

    shader := manager.pushPlatformShader(manager);
    shader.name = name;

    shader_file_data := deserializeShaderFile(shader);
    if !shader_file_data return shader;

    if #complete shader.kind == {
        case .GRAPHICS;
            pushBack(*shader.color_target_formats, color_target_formats);
            shader.depth_target_format = depth_target_format;

            manager.createGraphicsPlatformShader(device, manager, binding_manager, shader, shader_file_data);

        case .MESH;        #through;
        case .COMPUTE;     #through;
        case .RAY_TRACING;
            notImplemented(true);
    }

    return shader;
}

findShader :: inline (manager : *ShaderManager, name : string) -> *Shader #must #no_context {
    return manager.findPlatformShader(manager, name);
}

reloadShader :: (device : *Device, manager : *ShaderManager, binding_manager : *BindingManager, shader : *Shader) {
    shader_file_data := deserializeShaderFile(shader);
    if !shader_file_data return;

    if #complete shader.kind == {
        case .GRAPHICS;
            manager.reloadGraphicsPlatformShader(device, manager, binding_manager, shader, shader_file_data);

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
    shader_file_data, file_error := readEntireFile(makeBinaryShaderFilename(shader.name), pushToArena, *context.pet.per_frame_arena);
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
