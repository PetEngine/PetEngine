ShaderManager :: struct {
    MAX_SHADERS :: 1024;

    shaders_count : s64;
}

createShaderManager :: (device : *Device) -> *ShaderManager #must {
    manager : *ShaderManager;

    if #complete device.graphics_api == {
        case .VULKAN;
           manager = createVulkanShaderManager(cast(*VulkanDevice) device);
    }

    return manager;
}

destroyShaderManager :: (device : *Device, manager : *ShaderManager) {
    if #complete device.graphics_api == {
        case .VULKAN;
           destroyVulkanShaderManager(cast(*VulkanDevice) device, cast(*VulkanShaderManager) manager);
    }
}

resetShaderManager :: (device : *Device, manager : *ShaderManager) {
    if #complete device.graphics_api == {
        case .VULKAN;
           resetVulkanShaderManager(cast(*VulkanDevice) device, cast(*VulkanShaderManager) manager);
    }
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

    binding_table : ShaderCompiler.BindingTable;
}

createShader :: (device : *Device, manager : *ShaderManager, name : string) -> *Shader #must {
    shader : *Shader;

    if #complete device.graphics_api == {
        case .VULKAN;
            shader = pushVulkanShader(cast(*VulkanShaderManager) manager);
    }

    shader.name = name;

    shader_file_data, file_error := readEntireFile(makeBinaryShaderFilename(shader.name), pushToArena, *context.pet.per_frame_arena);
    if file_error != .NONE {
        errorMessage("Shader \"%\" was not found", name);
        return shader;
    }

    assert(shader_file_data.count >= ShaderCompiler.MIN_FILE_SIZE);

    shader_file_header := ShaderCompiler.getHeader(shader_file_data);
    assert(shader_file_header.version == ShaderCompiler.VERSION);

    shader.kind = shader_file_header.shader_kind;

    shader.binding_table = ShaderCompiler.getBindingTable(shader_file_data).*;

    if #complete device.graphics_api == {
        case .VULKAN;
            if #complete shader.kind == {
                case .UNKNOWN;
                    // @TODO: Print some meaningful message why it's illegal

                case .GRAPHICS;
                    createGraphicsVulkanShader(cast(*VulkanDevice) device,
                                               cast(*VulkanShaderManager) manager,
                                               cast(*VulkanShader) shader,
                                               shader_file_data);
                case .COMPUTE;     #through;
                case .MESH;        #through;
                case .RAY_TRACING;
                    notImplemented(true);
            }
    }

    return shader;
}

findShader :: (device : *Device, manager : *ShaderManager, name : string) -> *Shader #must #no_context {
    shader : *Shader;

    if #complete device.graphics_api == {
        case .VULKAN;
           shader = findVulkanShader(cast(*VulkanShaderManager) manager, name);
    }

    return shader;
}

findOrCreateShader :: (device : *Device, manager : *ShaderManager, name : string) -> *Shader #must {
    shader : *Shader;

    if #complete device.graphics_api == {
        case .VULKAN;
           shader = findVulkanShader(cast(*VulkanShaderManager) manager, name);
    }

    if !shader {
        shader = createShader(device, manager, name);
    }

    return shader;
}

reloadShader :: (device : *Device, manager : *ShaderManager, shader : *Shader) {
    shader_file_data, file_error := readEntireFile(makeBinaryShaderFilename(shader.name), pushToArena, *context.pet.per_frame_arena);
    if file_error != .NONE {
        errorMessage("Shader \"%\" was not found", shader.name);
        return;
    }

    assert(shader_file_data.count >= ShaderCompiler.MIN_FILE_SIZE);

    shader_file_header := ShaderCompiler.getHeader(shader_file_data);
    assert(shader_file_header.version == ShaderCompiler.VERSION);

    shader.binding_table = ShaderCompiler.getBindingTable(shader_file_data).*;

    if #complete device.graphics_api == {
        case .VULKAN;
            if #complete shader.kind == {
                case .UNKNOWN;
                    // @TODO: Print some meaningful message why it's illegal

                case .GRAPHICS;
                    reloadGraphicsVulkanShader(cast(*VulkanDevice) device,
                                               cast(*VulkanShaderManager) manager,
                                               cast(*VulkanShader) shader,
                                               shader_file_data);
                case .COMPUTE;     #through;
                case .MESH;        #through;
                case .RAY_TRACING;
                    notImplemented(true);
            }
    }
}

#scope_file

#load "../platform/vulkan/shader.jai";
