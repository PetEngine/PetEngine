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
    name : string;
}

createShader :: (device : *Device, manager : *ShaderManager, name : string) -> *Shader #must {
    shader : *Shader;

    if #complete device.graphics_api == {
        case .VULKAN;
           shader = createVulkanShader(cast(*VulkanDevice) device, cast(*VulkanShaderManager) manager, name);
    }

    return shader;
}

#scope_file

#load "../platform/vulkan/shader.jai";
