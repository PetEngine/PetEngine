CommandBuffer :: struct(usage : QueueType) {
    handles : StaticArray(*void, Device.MAX_FRAME_BUFFERING);

    shaders : [#run Basic.enum_highest_value(PipelineBindPoint) + 1] *Shader;

    #if usage == .GRAPHICS {
        viewport         : Viewport;
        scissor_rect     : ScissorRect;
        inside_rendering : bool;
    }
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
}

TargetLoadAction :: enum u8 {
    NONE;
    CLEAR;
    LOAD;
}

TargetStoreAction :: enum u8 {
    NONE;
    STORE;
}

ColorTargetDesc :: struct {
    texture : *Texture;

    load_action  : TargetLoadAction;
    store_action : TargetStoreAction;
}

DepthTargetDesc :: struct {
    texture : *Texture;

    depth_load_action  : TargetLoadAction;
    depth_store_action : TargetStoreAction;

    stencil_load_action  : TargetLoadAction;
    stencil_store_action : TargetStoreAction;
}

// @TODO: Per-frame command buffers
createCommandBuffer :: (device : *Device, $usage : QueueType) -> CommandBuffer(usage) #must {
    command_buffer : CommandBuffer(usage);
    command_buffer.handles.count = cast,no_check(s64) device.frame_buffering;

    if #complete device.graphics_api == {
        case .VULKAN;
            for * command_buffer.handles {
                it.* = pushVulkanCommandBuffer(cast(*VulkanDevice) device, cast(u32) it_index, usage);
            }
    }

    return command_buffer;
}

resetCommandBuffer :: (device : *Device, command_buffer : *CommandBuffer) {
    // @TODO: #FrameBuffering.
    //    - If device.frame_buffering > command_buffer.handles.count allocate new memory memory
    //    - If device.frame_buffering < command_buffer.handles.count free unusused memory
    assert(command_buffer.handles.count == cast,no_check(s64) device.frame_buffering,
           "It's illegal to change frame buffering for now.");

    command_buffer.handles.count = cast,no_check(s64) device.frame_buffering;

    for * command_buffer.shaders {
        it.* = null;
    }

    #if command_buffer.usage == .GRAPHICS {
        command_buffer.viewport         = .{};
        command_buffer.scissor_rect     = .{};
        command_buffer.inside_rendering = false;
    }
}

clearTexture :: (device : *Device, command_buffer : *CommandBuffer, texture : *Texture) {
    #assert command_buffer.usage == .GRAPHICS "Only graphics command buffers can clear textures";

    assert(texture.current_owner == command_buffer.usage,
           "You are trying to clear texture \"%\" in % command buffer, but texture's current owner is %. Change texture's owner first to do so.",
           texture.name,
           command_buffer.usage,
           texture.current_owner);

    if #complete device.graphics_api == {
        case .VULKAN;
            clearVulkanTexture(command_buffer.handles[device.frame_index], cast(*VulkanTexture) texture);
    }
}

// @TOOD: #Viewport. If shaderc_compile_options_set_invert_y will work out, remove flipped viewport for Vulkan
setViewport :: (device : *Device, command_buffer : *CommandBuffer, viewport : *Viewport, render_target_height : u16) #no_context {
    #assert command_buffer.usage == .GRAPHICS "Only graphics command buffers can set viewport";

    if !memcmp(*command_buffer.viewport, viewport, size_of(Viewport)) {
        return;
    }

    if #complete device.graphics_api == {
        case .VULKAN;
            setVulkanViewport(command_buffer.handles[device.frame_index], viewport, render_target_height);
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
            setVulkanScissorRect(command_buffer.handles[device.frame_index], scissor_rect);
    }

    command_buffer.scissor_rect = scissor_rect.*;
}

setShader :: (device : *Device, command_buffer : *CommandBuffer, shader : *Shader) #no_context {
    #assert command_buffer.usage == .GRAPHICS || command_buffer.usage == .ASYNC_COMPUTE
            "Only graphics and compute command buffers can set shaders";

    pipeline_bind_point : PipelineBindPoint;

    if #complete shader.kind == {
        case .UNKNOWN;
            // @TODO: Print some meaningful message why it's illegal

        case .GRAPHICS; #through;
        case .MESH;
            pipeline_bind_point = .GRAPHICS_OR_MESH;
        case .COMPUTE;
            pipeline_bind_point = .COMPUTE;
        case .RAY_TRACING;
            pipeline_bind_point = .RAY_TRACING;
    }

    if command_buffer.shaders[pipeline_bind_point] == shader {
        return;
    }

    if #complete device.graphics_api == {
        case .VULKAN;
            setVulkanShader(command_buffer.handles[device.frame_index], cast(*VulkanShader) shader);
    }

    command_buffer.shaders[pipeline_bind_point] = shader;
}

beginRendering :: (
    device         : *Device,
    command_buffer : *CommandBuffer,
    color_targets  : [] ColorTargetDesc,
    depth_target   : *DepthTargetDesc = null
) {
    #assert command_buffer.usage == .GRAPHICS "Only graphics command buffers can begin rendering";

    assert(!command_buffer.inside_rendering);
    assert(color_targets.count > 0 || depth_target, "You must specify at least one color target or/and depth target");

    #if DEBUG_BUILD {
        reference_texture : *Texture = ---;
        if color_targets.count > 0 {
            reference_texture = color_targets[0].texture;
        } else {
            reference_texture = depth_target.texture;
        }

        for color_targets {
            assert(it.texture);

            assert(it.texture.usage & .COLOR_TARGET,
                   "If you want to use \"%\" texture as color target add % usage on its creation",
                   it.texture.name,
                   Texture.Usage.COLOR_TARGET);

            assert(it.texture.width == reference_texture.width && it.texture.height == reference_texture.height,
                   "All color targets should have the same width and height");
        }

        if depth_target {
            assert(depth_target.texture);

            assert(depth_target.texture.usage & .DEPTH_TARGET,
                   "If you want to use \"%\" texture as depth target add % usage on its creation",
                   depth_target.texture.name,
                   Texture.Usage.DEPTH_TARGET);

            assert(depth_target.texture.width == reference_texture.width && depth_target.texture.height == reference_texture.height,
                   "Depth target should have the same width and height as color targets have");
        }
    }

    if #complete device.graphics_api == {
        case .VULKAN;
            beginVulkanRendering(command_buffer.handles[device.frame_index], color_targets, depth_target);
    }

    command_buffer.inside_rendering = true;
}

endRendering :: (device : *Device, command_buffer : *CommandBuffer) {
    #assert command_buffer.usage == .GRAPHICS "Only graphics command buffers can end rendering";

    assert(command_buffer.inside_rendering);

    if #complete device.graphics_api == {
        case .VULKAN;
            endVulkanRendering(command_buffer.handles[device.frame_index]);
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

    shader := command_buffer.shaders[PipelineBindPoint.GRAPHICS_OR_MESH];
    assert(shader, "You should set graphics or mesh shader before calling %", #procedure_name());

    if #complete device.graphics_api == {
        case .VULKAN;
            drawVulkanPrimitives(command_buffer.handles[device.frame_index],
                                 cast(*VulkanShader) shader,
                                 ifx vertex_count   then vertex_count   else 1,
                                 ifx instance_count then instance_count else 1,
                                 first_vertex,
                                 first_instance);
    }
}

// @TODO: Other shaders
setPushConstants :: inline (device : *Device, command_buffer : *CommandBuffer, stage : ShaderStage, data : *$T) {
    #assert command_buffer.usage == .GRAPHICS "Only graphics command buffers can draw";

    shader := command_buffer.shaders[PipelineBindPoint.GRAPHICS_OR_MESH];
    assert(shader, "You should set shader before setting its push constants");

    if #complete device.graphics_api == {
        case .VULKAN;
            setVulkanPushConstants(command_buffer.handles[device.frame_index],
                                   cast(*VulkanShader) shader,
                                   stage,
                                   data);
    }
}

copyBuffer :: (
    device         : *Device,
    command_buffer : *CommandBuffer,
    dest           : *Buffer,
    source         : *Buffer,
    dest_offset    : u32 = 0,
    source_offset  : u32 = 0,
    bytes          : u32 = 0xFFFF_FFFF
) {
    assert(dest_offset   < dest.bytes);
    assert(source_offset < source.bytes);

    if bytes == 0xFFFF_FFFF {
        bytes = source.bytes;
        assert(source.bytes == dest.bytes);
    } else {
        assert(dest_offset   + bytes <= dest.bytes);
        assert(source_offset + bytes <= source.bytes);
    }

    if #complete device.graphics_api == {
        case .VULKAN;
            copyVulkanBuffer(command_buffer.handles[device.frame_index],
                             cast(*VulkanBuffer) dest,
                             cast(*VulkanBuffer) source,
                             dest_offset,
                             source_offset,
                             bytes);
    }
}

#scope_file

PipelineBindPoint :: enum u8 {
    GRAPHICS_OR_MESH;
    COMPUTE;
    RAY_TRACING;
}

#load "vulkan/command_buffer.jai";
