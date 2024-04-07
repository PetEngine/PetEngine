ShaderManager :: struct {
    MAX_SHADERS :: 1024;

    shaders_count : s64;

    //
    // VTable
    //

    destroyPlatformShaderManager : (device : *Device, manager : *ShaderManager);
    resetPlatformShaderManager   : (device : *Device, manager : *ShaderManager);

    pushPlatformShader : (manager : *ShaderManager) -> *Shader #must;

    createGraphicsPlatformShader : (device : *Device, manager : *ShaderManager, shader : *Shader, shader_file_data : string);

    findPlatformShader           : (manager : *ShaderManager, name : string) -> *Shader #must #no_context;
    reloadGraphicsPlatformShader : (device : *Device, manager : *ShaderManager, shader : *Shader, shader_file_data : string);
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
        UNKNOWN;
        GRAPHICS;
        COMPUTE;
        MESH;
        RAY_TRACING;
    }

    kind : Kind = .UNKNOWN;
    name : string;

    color_target_formats : StaticArray(Texture.Format, ShaderCompiler.MAX_COLOR_TARGETS);
    depth_target_format  : Texture.Format;

    binding_table       : ShaderCompiler.BindingTable;
    binding_names_table : ShaderCompiler.RuntimeBindingNamesTable;
}

PushConstantsHandle :: struct {
    INVALID_INDEX :: ShaderCompiler.MAX_PUSH_CONSTANTS;

    index : u8 = INVALID_INDEX;
}

BindingHandle :: struct {
    INVALID_SET     :: ShaderCompiler.MAX_DESCRIPTOR_SETS;
    INVALID_BINDING :: ShaderCompiler.MAX_BINDINGS;

    set     : u8 = INVALID_SET;
    binding : u8 = INVALID_BINDING;
}


createShader :: (
    device               : *Device,
    manager              : *ShaderManager,
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
        case .UNKNOWN;
            // @TODO: Print some meaningful message why it's illegal

        case .GRAPHICS;
            pushBack(*shader.color_target_formats, color_target_formats);
            shader.depth_target_format = depth_target_format;

            manager.createGraphicsPlatformShader(device, manager, shader, shader_file_data);

        case .COMPUTE;     #through;
        case .MESH;        #through;
        case .RAY_TRACING;
            notImplemented(true);
    }

    return shader;
}

findShader :: inline (manager : *ShaderManager, name : string) -> *Shader #must #no_context {
    return manager.findPlatformShader(manager, name);
}

reloadShader :: (device : *Device, manager : *ShaderManager, shader : *Shader) {
    shader_file_data := deserializeShaderFile(shader);
    if !shader_file_data return;

    if #complete shader.kind == {
        case .UNKNOWN;
            // @TODO: Print some meaningful message why it's illegal

        case .GRAPHICS;
            manager.reloadGraphicsPlatformShader(device, manager, shader, shader_file_data);

        case .COMPUTE;     #through;
        case .MESH;        #through;
        case .RAY_TRACING;
            notImplemented(true);
    }
}

getPushConstantsHandle :: (shader : *Shader, name : string) -> PushConstantsHandle {
    handle : PushConstantsHandle;
    for toView(shader.binding_names_table.push_constants.data, shader.binding_table.push_constants_count) {
        name_in_table := string.{ count = it.length, data = it.buffer.data };
        if name_in_table == name {
            handle.index = cast(u8) it_index;
            break;
        }
    }
    return handle;
}

getBindingHandle :: (shader : *Shader, name : string) -> BindingHandle {
    handle : BindingHandle;
    for set_names, set_index : toView(shader.binding_names_table.bindings.data, shader.binding_table.descriptor_sets_count) {
        bindings_count := shader.binding_table.bindings_count[set_index];
        if !bindings_count continue;

        for binding_name, binding_index : toView(shader.binding_names_table.bindings[set_index].data, bindings_count) {
            name_in_table := string.{ count = binding_name.length, data = binding_name.buffer.data };
            if name_in_table == name {
                handle.set     = cast(u8) set_index;
                handle.binding = cast(u8) binding_index;
                break set_names;
            }
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
    ShaderCompiler.deserializeBindingNamesTable(shader_file_data, *shader.binding_names_table);

    return shader_file_data;
}

#load "vulkan/shader.jai";
