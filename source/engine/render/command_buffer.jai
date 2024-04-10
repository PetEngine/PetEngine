CommandBuffer :: struct(usage : QueueType) {
    handles : StaticArray(*void, Device.MAX_FRAME_BUFFERING);

    shaders : [#run Basic.enum_highest_value(PipelineBindPoint) + 1] *Shader;

    #if usage == .GRAPHICS {
        viewport         : Viewport;
        scissor_rect     : ScissorRect;
        inside_rendering : bool;
    }

    descriptor_buffer_set_offsets : [ShaderCompiler.MAX_DESCRIPTOR_SETS] s64;
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

resetCommandBuffer :: (device : *Device, command_buffer : *CommandBuffer, shader_manager : *ShaderManager) {
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

    if #complete device.graphics_api == {
        case .VULKAN;
            vulkan_device         := cast(*VulkanDevice)        device;
            vulkan_shader_manager := cast(*VulkanShaderManager) shader_manager;

            binding_info := VkDescriptorBufferBindingInfoEXT.{
                address = cast(VkDeviceAddress) vulkan_shader_manager.per_frame_bindings[device.frame_index].descriptor_buffer.device_address,
                usage   = .VK_BUFFER_USAGE_SAMPLER_DESCRIPTOR_BUFFER_BIT_EXT
                        | .VK_BUFFER_USAGE_RESOURCE_DESCRIPTOR_BUFFER_BIT_EXT
            };

            vulkan_device.loader.extensions.device.required.vkCmdBindDescriptorBuffersEXT(command_buffer.handles[device.frame_index],
                                                                                          1,
                                                                                          *binding_info);
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

setShader :: (device : *Device, command_buffer : *CommandBuffer, shader_manager : *ShaderManager, shader : *Shader) #no_context {
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

    command_buffer.shaders[pipeline_bind_point] = shader;

    if #complete device.graphics_api == {
        case .VULKAN;
            setVulkanShader(command_buffer, cast(*VulkanShaderManager) shader_manager, cast(*VulkanShader) shader, device.frame_index);
    }
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
            commitVulkanBindings(cast(*VulkanDevice) device, command_buffer, cast(*VulkanShader) shader);

            drawVulkanPrimitives(command_buffer.handles[device.frame_index],
                                 cast(*VulkanShader) shader,
                                 ifx vertex_count   then vertex_count   else 1,
                                 ifx instance_count then instance_count else 1,
                                 first_vertex,
                                 first_instance);
    }
}

// @TODO: Other shaders
setPushConstants :: inline (device : *Device, command_buffer : *CommandBuffer, handle : PushConstantsHandle, data : *$T) {
    #assert command_buffer.usage == .GRAPHICS "Only graphics command buffers can use push constants for now";

    shader := command_buffer.shaders[PipelineBindPoint.GRAPHICS_OR_MESH];
    assert(shader, "You should set shader before setting its push constants");

    if #complete device.graphics_api == {
        case .VULKAN;
            setVulkanPushConstants(command_buffer.handles[device.frame_index], cast(*VulkanShader) shader, handle, data);
    }
}

// @TODO: Other shaders
bindResource :: (
    device         : *Device,
    command_buffer : *CommandBuffer,
    shader_manager : *ShaderManager,
    handle         : BindingHandle,
    resource       : *$Resource
) {
    #assert command_buffer.usage == .GRAPHICS "Only graphics command buffers can use bindings for now";
    #assert Resource == Buffer || Resource == TextureView;

    shader := command_buffer.shaders[PipelineBindPoint.GRAPHICS_OR_MESH];
    assert(shader, "You should set shader before setting its bindings");

    if #complete device.graphics_api == {
        case .VULKAN;
            #if Resource == {
                case Buffer;
                    bindVulkanBuffer(cast(*VulkanDevice) device,
                                     command_buffer,
                                     cast(*VulkanShaderManager) shader_manager,
                                     cast(*VulkanShader) shader,
                                     handle,
                                     cast(*VulkanBuffer) resource);

                case TextureView;
                    bindVulkanTexture(cast(*VulkanDevice) device,
                                     command_buffer,
                                     cast(*VulkanShaderManager) shader_manager,
                                     cast(*VulkanShader) shader,
                                     handle,
                                     cast(*VulkanTextureView) resource);
            }
    }
}

copyBuffer :: (
    device         : *Device,
    command_buffer : *CommandBuffer,
    dest_buffer    : *Buffer,
    source_buffer  : *Buffer,
    dest_offset    : u32 = 0,
    source_offset  : u32 = 0,
    bytes          : u32 = 0xFFFF_FFFF
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

    assert(dest_offset   < dest_buffer.bytes);
    assert(source_offset < source_buffer.bytes);

    if bytes == 0xFFFF_FFFF {
        bytes = source_buffer.bytes;
        assert(source_buffer.bytes == dest_buffer.bytes);
    } else {
        assert(dest_offset   + bytes <= dest_buffer.bytes);
        assert(source_offset + bytes <= source_buffer.bytes);
    }

    if #complete device.graphics_api == {
        case .VULKAN;
            copyVulkanBuffer(command_buffer.handles[device.frame_index],
                             cast(*VulkanBuffer) dest_buffer,
                             cast(*VulkanBuffer) source_buffer,
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
