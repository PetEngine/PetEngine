CommandBuffer :: struct (usage : QueueType) {
    handles : [Device.MAX_SWAPCHAIN_BUFFERS] *void;
}

// @TODO: Per-frame command buffers
createCommandBuffer :: (device : *Device, $usage : QueueType) -> CommandBuffer(usage) #must {
    command_buffer : CommandBuffer(usage);

    handles_it := command_buffer.handles.data;

    if #complete device.graphics_api == {
        case .VULKAN;
            for 0 .. device.swapchain_buffers_count - 1 {
                <<handles_it = pushVulkanCommandBuffer(cast(*VulkanDevice) device, it, usage);
                handles_it += 1;
            }
    }

    return command_buffer;
}

clearTexture :: (device : *Device, command_buffer : *CommandBuffer, texture : *Texture, clear_value : Texture.ClearValue) {
    #assert command_buffer.usage == .GRPAHICS "Only graphics command buffers can clear textures";

    if #complete device.graphics_api == {
        case .VULKAN;
            clearVulkanTexture(cast(*VulkanDevice) device,
                               command_buffer[device.back_buffer_index],
                               texture,
                               clear_value);
    }
}

#scope_file

#load "../platform/vulkan/command_buffer.jai";
