CommandBuffer :: struct(usage : QueueType) {
    handles : StaticArray(*void, Device.MAX_FRAME_BUFFERING);

    #if usage == .GRAPHICS || usage == .ASYNC_COMPUTE {
        shaders : [#run Basic.enum_highest_value(ShaderBindPoint) + 1] *Shader;
    }

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
    max_depth : f32 = 1.0;
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
    view : *TextureView;

    load_action  : TargetLoadAction;
    store_action : TargetStoreAction;
}

DepthTargetDesc :: struct {
    view : *TextureView;

    depth_load_action  : TargetLoadAction;
    depth_store_action : TargetStoreAction;

    stencil_load_action  : TargetLoadAction;
    stencil_store_action : TargetStoreAction;
}

ShaderBindPoint :: enum u8 {
    GRAPHICS_OR_MESH;
    COMPUTE;
    RAY_TRACING;
}

CopyRegion :: struct {
    REMAINING_BYTES :: 0xFFFF_FFFF;

    dest_offset   : u32;
    source_offset : u32;
    bytes         : u32 = REMAINING_BYTES;
}

BufferToTextureCopyRegion :: struct {
    buffer_offset : u32;

    texture_array_layer : u16;
    texture_face        : u8;
    texture_mip         : u8;
}

createCommandBuffer :: ($usage : QueueType) -> CommandBuffer(usage) #must {
    command_buffer : CommandBuffer(usage);
    command_buffer.handles.count = cast,no_check(s64) context.pet.render.device.frame_buffering;

    if #complete context.pet.render.device.graphics_api == {
        case .VULKAN;
            for * command_buffer.handles {
                it.* = pushVulkanCommandBuffer(cast(u32) it_index, usage);
            }
    }

    return command_buffer;
}

resetCommandBuffer :: (command_buffer : *CommandBuffer) {
    // @TODO: #FrameBuffering.
    assert(command_buffer.handles.count == cast,no_check(s64) context.pet.render.device.frame_buffering, "It's illegal to change frame buffering for now");
    command_buffer.handles.count = cast,no_check(s64) context.pet.render.device.frame_buffering;

    #if command_buffer.usage == .GRAPHICS || command_buffer.usage == .ASYNC_COMPUTE {
        for * command_buffer.shaders {
            it.* = null;
        }
    }

    #if command_buffer.usage == .GRAPHICS {
        command_buffer.viewport         = .{};
        command_buffer.scissor_rect     = .{};
        command_buffer.inside_rendering = false;

        if #complete context.pet.render.device.graphics_api == {
            case .VULKAN;
                rebindVulkanDescriptorBuffers(command_buffer.handles[context.pet.render.device.frame_index]);
        }
    }
}

clearTexture :: (command_buffer : *CommandBuffer, texture : *Texture) {
    #assert command_buffer.usage == .GRAPHICS "Only graphics command buffers can clear textures";

    assert(texture.current_owner == command_buffer.usage,
           "You are trying to clear texture \"%\" in % command buffer, but texture's current owner is %. Change texture's owner first to do so.",
           texture.name,
           command_buffer.usage,
           texture.current_owner);

    if #complete context.pet.render.device.graphics_api == {
        case .VULKAN;
            clearVulkanTexture(command_buffer.handles[context.pet.render.device.frame_index], cast(*VulkanTexture) texture);
    }
}

setViewport :: (command_buffer : *CommandBuffer, viewport : *Viewport, render_target_height : u16) {
    #assert command_buffer.usage == .GRAPHICS "Only graphics command buffers can set viewport";

    if !memcmp(*command_buffer.viewport, viewport, size_of(Viewport)) {
        return;
    }

    if #complete context.pet.render.device.graphics_api == {
        case .VULKAN;
            setVulkanViewport(command_buffer.handles[context.pet.render.device.frame_index], viewport, render_target_height);
    }

    command_buffer.viewport = viewport.*;
}

setScissorRect :: (command_buffer : *CommandBuffer, scissor_rect : *ScissorRect) {
    #assert command_buffer.usage == .GRAPHICS "Only graphics command buffers can set scissor rect";

    if !memcmp(*command_buffer.scissor_rect, scissor_rect, size_of(ScissorRect)) {
        return;
    }

    if #complete context.pet.render.device.graphics_api == {
        case .VULKAN;
            setVulkanScissorRect(command_buffer.handles[context.pet.render.device.frame_index], scissor_rect);
    }

    command_buffer.scissor_rect = scissor_rect.*;
}

setShader :: (command_buffer : *CommandBuffer, shader : *Shader) {
    #assert command_buffer.usage == .GRAPHICS || command_buffer.usage == .ASYNC_COMPUTE
            "Only graphics and compute command buffers can set shaders";

    bind_point := shaderKindToShaderBindPoint(shader.kind);

    if command_buffer.shaders[bind_point] == shader {
        return;
    }

    command_buffer.shaders[bind_point] = shader;

    if #complete context.pet.render.device.graphics_api == {
        case .VULKAN;
            setVulkanShader(command_buffer, bind_point);
    }
}

beginRendering :: (command_buffer : *CommandBuffer, color_targets : [] ColorTargetDesc, depth_target : *DepthTargetDesc = null) {
    #assert command_buffer.usage == .GRAPHICS "Only graphics command buffers can begin rendering";

    assert(!command_buffer.inside_rendering);
    assert(color_targets.count > 0 || depth_target, "You must specify at least one color target or/and depth target");

    #if DEBUG_BUILD {
        reference_texture : *Texture = ---;
        if color_targets.count > 0 {
            reference_texture = color_targets[0].view.texture;
        } else {
            reference_texture = depth_target.view.texture;
        }

        for color_targets {
            assert(it.view.usage == .COLOR_TARGET,
                   "Expected texture view with % usage, got with %. Name: \"%\"",
                   Texture.Usage.COLOR_TARGET,
                   it.view.usage,
                   it.view.name);

            assert(textureFormatFlags(it.view.format) & .COLOR,
                   "Color target should have color format");

            assert(it.view.texture.width == reference_texture.width && it.view.texture.height == reference_texture.height,
                   "All color targets should have the same width and height");
        }

        if depth_target {
            assert(depth_target.view.usage == .DEPTH_TARGET || depth_target.view.usage == .DEPTH_READ_ONLY,
                   "Expected texture view with % or % usage, got with %. Name: \"%\"",
                   Texture.Usage.DEPTH_TARGET,
                   Texture.Usage.DEPTH_READ_ONLY,
                   depth_target.view.usage,
                   depth_target.view.name);

            assert(textureFormatFlags(depth_target.view.format) & (.DEPTH | .STENCIL),
                   "Depth target should have depth-stencil format");

            assert(depth_target.view.texture.width == reference_texture.width && depth_target.view.texture.height == reference_texture.height,
                   "Depth target should have the same width and height as color targets have");
        }
    }

    if #complete context.pet.render.device.graphics_api == {
        case .VULKAN;
            beginVulkanRendering(command_buffer.handles[context.pet.render.device.frame_index], color_targets, depth_target);
    }

    command_buffer.inside_rendering = true;
}

endRendering :: (command_buffer : *CommandBuffer) {
    #assert command_buffer.usage == .GRAPHICS "Only graphics command buffers can end rendering";

    assert(command_buffer.inside_rendering);

    if #complete context.pet.render.device.graphics_api == {
        case .VULKAN;
            endVulkanRendering(command_buffer.handles[context.pet.render.device.frame_index]);
    }

    command_buffer.inside_rendering = false;
}

drawPrimitives :: (
    command_buffer  : *CommandBuffer,
    vertices_count  : u32,
    instances_count : u32 = 1,
    first_vertex    : u32 = 0,
    first_instance  : u32 = 0
) {
    #assert command_buffer.usage == .GRAPHICS "Only graphics command buffers can draw";

    assert(command_buffer.inside_rendering);

    shader := command_buffer.shaders[ShaderBindPoint.GRAPHICS_OR_MESH];
    assert(shader, "You should set graphics or mesh shader before calling %", #procedure_name());

    if #complete context.pet.render.device.graphics_api == {
        case .VULKAN;
            drawVulkanPrimitives(command_buffer.handles[context.pet.render.device.frame_index],
                                 cast(*VulkanShader) shader,
                                 max(vertices_count, 1),
                                 max(instances_count, 1),
                                 first_vertex,
                                 first_instance);
    }
}

setPushConstants :: inline (command_buffer : *CommandBuffer, handle : PushConstantsHandle, data : *$T) {
    #assert command_buffer.usage == .GRAPHICS "Only graphics command buffers can use push constants for now";

    shader := command_buffer.shaders[ShaderBindPoint.GRAPHICS_OR_MESH];
    assert(shader, "You should set shader before setting its push constants");

    if #complete context.pet.render.device.graphics_api == {
        case .VULKAN;
            setVulkanPushConstants(command_buffer.handles[context.pet.render.device.frame_index], cast(*VulkanShader) shader, handle, data);
    }
}

copyBuffer :: (
    command_buffer : *CommandBuffer,
    dest_buffer    : *Buffer,
    source_buffer  : *Buffer,
    dest_offset    : u32 = 0,
    source_offset  : u32 = 0,
    bytes          : u32 = CopyRegion.REMAINING_BYTES
) {
    assert(source_buffer.current_owner == command_buffer.usage,
           "You are trying to copy from buffer \"%\" in % command buffer, but buffer's current owner is %. Change buffers's owner first to do so.",
           source_buffer.name,
           command_buffer.usage,
           source_buffer.current_owner);
    assert(dest_buffer.current_owner == command_buffer.usage,
           "You are trying to copy to buffer \"%\" in % command buffer, but buffer's current owner is %. Change buffers's owner first to do so.",
           dest_buffer.name,
           command_buffer.usage,
           dest_buffer.current_owner);

    assert(dest_offset   < dest_buffer.size);
    assert(source_offset < source_buffer.size);

    if bytes == CopyRegion.REMAINING_BYTES {
        bytes = source_buffer.size - source_offset;
    } else {
        assert(source_offset + bytes <= source_buffer.size);
    }
    assert(dest_offset + bytes <= dest_buffer.size);

    if #complete context.pet.render.device.graphics_api == {
        case .VULKAN;
            copyVulkanBuffer(command_buffer.handles[context.pet.render.device.frame_index],
                             cast(*VulkanBuffer) dest_buffer,
                             cast(*VulkanBuffer) source_buffer,
                             dest_offset,
                             source_offset,
                             bytes);
    }
}

copyBufferRegions :: (
    command_buffer : *CommandBuffer,
    dest_buffer    : *Buffer,
    source_buffer  : *Buffer,
    regions        : [] CopyRegion
) {
    if regions.count <= 0 return;

    assert(source_buffer.current_owner == command_buffer.usage,
           "You are trying to copy from buffer \"%\" in % command buffer, but buffer's current owner is %. Change buffers's owner first to do so.",
           source_buffer.name,
           command_buffer.usage,
           source_buffer.current_owner);
    assert(dest_buffer.current_owner == command_buffer.usage,
           "You are trying to copy to buffer \"%\" in % command buffer, but buffer's current owner is %. Change buffers's owner first to do so.",
           dest_buffer.name,
           command_buffer.usage,
           dest_buffer.current_owner);

    for * regions {
        assert(it.dest_offset   < dest_buffer.size);
        assert(it.source_offset < source_buffer.size);

        if it.bytes == CopyRegion.REMAINING_BYTES {
            assert(regions.count == 1, "Using CopyRegion.REMAINING_BYTES in CopyRegion.bytes field is allowed only when you copy 1 region");
            it.bytes = source_buffer.size - it.source_offset;
        } else {
            assert(it.source_offset + it.bytes <= source_buffer.size);
        }
        assert(it.dest_offset + it.bytes <= dest_buffer.size);
    }

    if #complete context.pet.render.device.graphics_api == {
        case .VULKAN;
            copyVulkanBufferRegions(command_buffer.handles[context.pet.render.device.frame_index],
                                    cast(*VulkanBuffer) dest_buffer,
                                    cast(*VulkanBuffer) source_buffer,
                                    regions);
    }
}

copyBufferToTexture :: (
    command_buffer : *CommandBuffer,
    texture        : *Texture,
    buffer         : *Buffer,
    regions        : [] BufferToTextureCopyRegion
) {
    if regions.count <= 0 return;

    assert(buffer.current_owner == command_buffer.usage,
           "You are trying to copy from buffer \"%\" in % command buffer, but buffer's current owner is %. Change buffers's owner first to do so.",
           buffer.name,
           command_buffer.usage,
           buffer.current_owner);
    assert(texture.current_owner == command_buffer.usage,
           "You are trying to copy to texture \"%\" in % command buffer, but texture's current owner is %. Change texture's owner first to do so.",
           buffer.name,
           command_buffer.usage,
           texture.current_owner);

    for regions {
        assert(it.buffer_offset < buffer.size);

        if texture.flags & .ARRAY {
            assert(it.texture_array_layer < texture.array_size);
        } else {
            assert(it.texture_array_layer == 0);
        }
        if texture.flags & .CUBE {
            assert(it.texture_face < 6);
        } else {
            assert(it.texture_face == 0);
        }
        assert(it.texture_mip < texture.mips_count);
    }

    if #complete context.pet.render.device.graphics_api == {
        case .VULKAN;
            copyVulkanBufferToTexture(command_buffer.handles[context.pet.render.device.frame_index],
                                      cast(*VulkanTexture) texture,
                                      cast(*VulkanBuffer) buffer,
                                      regions);
    }
}

#scope_file

shaderKindToShaderBindPoint :: inline (kind : Shader.Kind) -> ShaderBindPoint #no_context {
    if #complete kind == {
        case .GRAPHICS; #through;
        case .MESH;
            return .GRAPHICS_OR_MESH;

        case .COMPUTE;
            return .COMPUTE;

        case .RAY_TRACING;
            return .RAY_TRACING;
    }
}

#load "vulkan/command_buffer.jai";
