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
}

createShader :: (device : *Device, manager : *ShaderManager, name : string) -> *Shader #must {
    shader : *Shader;

    if #complete device.graphics_api == {
        case .VULKAN;
            shader = pushVulkanShader(cast(*VulkanShaderManager) manager);
    }

    shader.name = name;

    shader_filename := makeBinaryShaderFilename(shader.name);
    shader_file_data, success := File.read_entire_file(shader_filename, log_errors = false);
    assert(success);
    defer Basic.free(shader_file_data);

    // @TODO: #BindingTable.
    MIN_SHADER_FILE_SIZE :: size_of(ShaderCompiler.Header) + size_of(ShaderCompiler.PipelineState);
    assert(shader_file_data.count >= MIN_SHADER_FILE_SIZE);

    shader_file_header := cast(*ShaderCompiler.Header) shader_file_data.data;
    assert(shader_file_header.version == ShaderCompiler.VERSION);

    shader.kind = shader_file_header.shader_kind;

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

#scope_file

#load "../platform/vulkan/shader.jai";
