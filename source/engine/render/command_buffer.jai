CommandBuffer :: struct (usage : QueueType) {
    handles : [Device.MAX_SWAPCHAIN_BUFFERS] *void;

    shader       : *Shader;
    viewport     : Viewport;
    scissor_rect : ScissorRect;

    inside_rendering : bool; // @Cleanup: Rename
}

Viewport :: struct {
    x         : f32;
    y         : f32;
    width     : f32;
    height    : f32;
    min_depth : f32;
    max_depth : f32;
}

ScissorRect :: struct {
    x      : s32;
    y      : s32;
    width  : u32;
    height : u32;
};

// @TODO: Per-frame command buffers
createCommandBuffer :: (device : *Device, $usage : QueueType) -> CommandBuffer(usage) #must {
    command_buffer : CommandBuffer(usage);

    handles_it := command_buffer.handles.data;

    if #complete device.graphics_api == {
        case .VULKAN;
            for 0 .. device.swapchain_buffers_count - 1 {
                handles_it.*  = pushVulkanCommandBuffer(cast(*VulkanDevice) device, it, usage);
                handles_it   += 1;
            }
    }

    return command_buffer;
}

clearTexture :: (device : *Device, command_buffer : *CommandBuffer, texture : *Texture, clear_value : Texture.ClearValue) {
    #assert command_buffer.usage == .GRAPHICS "Only graphics command buffers can clear textures";

    assert(texture.current_owner == command_buffer.usage,
           "You are trying to clear texture \"%\" in % command buffer, but texture's current owner is %. Change texture's owner first to do so.",
           texture.name,
           command_buffer.usage,
           texture.current_owner);

    if #complete device.graphics_api == {
        case .VULKAN;
            clearVulkanTexture(command_buffer.handles[device.back_buffer_index],
                               cast(*VulkanTexture) texture,
                               clear_value);
    }
}

setViewport :: (device : *Device, command_buffer : *CommandBuffer, viewport : *Viewport, render_target_height : u16) {
    #assert command_buffer.usage == .GRAPHICS "Only graphics command buffers can set viewport";

    if !memcmp(*command_buffer.viewport, viewport, size_of(Viewport)) {
        return;
    }

    if #complete device.graphics_api == {
        case .VULKAN;
            setVulkanViewport(command_buffer.handles[device.back_buffer_index], viewport, render_target_height);
    }

    command_buffer.viewport = viewport.*;
}

setScissorRect :: (device : *Device, command_buffer : *CommandBuffer, scissor_rect : *ScissorRect) #no_context {
    #assert command_buffer.usage == .GRAPHICS "Only graphics command buffers can set scissor rect";

    if !memcmp(*command_buffer.scissor_rect, scissor_rect, size_of(ScissorRect)) {
        return;
    }

    if #complete device.graphics_api == {
        case .VULKAN;
            setVulkanScissorRect(command_buffer.handles[device.back_buffer_index], scissor_rect);
    }

    command_buffer.scissor_rect = scissor_rect.*;
}

setShader :: (device : *Device, command_buffer : *CommandBuffer, shader : *Shader) #no_context {
    #assert command_buffer.usage == .GRAPHICS || command_buffer.usage == .ASYNC_COMPUTE
            "Only graphics and compute command buffers can set shaders";

    if command_buffer.shader == shader {
        return;
    }

    if #complete device.graphics_api == {
        case .VULKAN;
            setVulkanShader(command_buffer.handles[device.back_buffer_index], cast(*VulkanShader) shader);
    }

    command_buffer.shader = shader;
}

beginRendering :: (
    device         : *Device,
    command_buffer : *CommandBuffer,
    color_targets  : .. *Texture,    // @TODO: Exchange with array view when Jai will support non-constant array literals.
    depth_target   : *Texture = null
) {
    #assert command_buffer.usage == .GRAPHICS "Only graphics command buffers can begin rendering";

    assert(!command_buffer.inside_rendering);
    assert(color_targets.count > 0 || depth_target, "You must specify at least one color target or/and depth target");

    #if DEBUG_BUILD {
        reference_target := color_targets[0];

        for color_targets {
            assert(it.flags & .COLOR_TARGET,
                   "If you want to use \"%\" texture as color target add % flag on its creation",
                   it.name,
                   Texture.Flags.COLOR_TARGET);

            assert(it.width == reference_target.width && it.height == reference_target.height,
                   "All color targets should have the same width and height");
        }

        if depth_target {
            assert(depth_target.flags & .COLOR_TARGET,
                   "If you want to use \"%\" texture as depth target add % flag on its creation",
                   depth_target.name,
                   Texture.Flags.DEPTH_STENCIL);

            assert(depth_target.width == reference_target.width && depth_target.height == reference_target.height,
                   "Depth target should have the same width and height as color targets have");
        }
    }

    if #complete device.graphics_api == {
        case .VULKAN;
            beginVulkanRendering(command_buffer.handles[device.back_buffer_index],
                                 .. cast([] *VulkanTexture) color_targets,
                                 depth_target = cast(*VulkanTexture) depth_target);
    }

    command_buffer.inside_rendering = true;
}

endRendering :: (device : *Device, command_buffer : *CommandBuffer) {
    #assert command_buffer.usage == .GRAPHICS "Only graphics command buffers can end rendering";

    assert(command_buffer.inside_rendering);

    if #complete device.graphics_api == {
        case .VULKAN;
            endVulkanRendering(command_buffer.handles[device.back_buffer_index]);
    }

    command_buffer.inside_rendering = false;
}

drawPrimitives :: (
    device         : *Device,
    command_buffer : *CommandBuffer,
    vertex_count   : u32,
    instance_count : u32 = 1,
    first_vertex   : u32 = 0,
    first_instance : u32 = 0
) {
    #assert command_buffer.usage == .GRAPHICS "Only graphics command buffers can draw";

    assert(command_buffer.inside_rendering);

    if #complete device.graphics_api == {
        case .VULKAN;
            drawVulkanPrimitives(command_buffer.handles[device.back_buffer_index],
                                 ifx vertex_count   then vertex_count   else 1,
                                 ifx instance_count then instance_count else 1,
                                 first_vertex,
                                 first_instance);
    }
}

#scope_file

#load "../platform/vulkan/command_buffer.jai";
