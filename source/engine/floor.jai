Floor :: struct {
    PushConstants :: union {
        StructuredData :: struct {
            per_view_uniform_index : u32;
        } #no_padding
        using structured_data : StructuredData;

        _packed : [1] v4u;
        #assert(size_of(type_of(_packed)) >= size_of(StructuredData));
    } #no_padding

    shader                : *Shader;
    push_constants_handle : PushConstantsHandle;
}

createFloor :: (
    device          : *Device,
    shader_manager  : *ShaderManager,
    binding_manager : *BindingManager,
    depth_format    : Texture.Format
) -> Floor {
    floor : Floor;
    floor.shader                = createShader(device, shader_manager, binding_manager, "floor", .[ getBackBuffer(device).format ], depth_format );
    floor.push_constants_handle = getPushConstantsHandle(floor.shader, "g_push_constants");
    return floor;
}

drawFloor :: (
    device           : *Device,
    shader_manager   : *ShaderManager,
    binding_manager  : *BindingManager,
    command_buffer   : *CommandBuffer,
    floor            : *Floor,
    per_view_uniform : *PerViewUniform
) {
    viewport := Viewport.{
        width     = cast(f32) device.render_resolution.width,
        height    = cast(f32) device.render_resolution.height,
        min_depth = 0.0,
        max_depth = 1.0,
    };
    setViewport(device, command_buffer, *viewport, device.render_resolution.height);

    setScissorRect(device, command_buffer, *(ScissorRect.{
        width  = device.render_resolution.width,
        height = device.render_resolution.height,
    }));

    setShader(device, command_buffer, shader_manager, binding_manager, floor.shader);

    setPushConstants(device, command_buffer, floor.push_constants_handle, *(Floor.PushConstants.{
        per_view_uniform_index = per_view_uniform.handles[device.frame_index][per_view_uniform.version].descriptor
    }));

    drawPrimitives(device, command_buffer, 4);
}
