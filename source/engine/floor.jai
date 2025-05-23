Floor :: struct {
    PushConstants :: struct {
        per_view_uniform_index : u32;
    } #no_padding

    shader                : *Shader;
    push_constants_handle : PushConstantsHandle;
}

createFloor :: (depth_format : Texture.Format) -> Floor {
    floor : Floor;
    floor.shader                = createShader("floor", .[ context.pet.render.device.back_buffer_format ], depth_format );
    floor.push_constants_handle = getPushConstantsHandle(floor.shader, "g_push_constants");
    return floor;
}

drawFloor :: (command_buffer : *CommandBuffer, floor : Floor, per_view_uniform : PerViewUniform) {
    render_resolution := context.pet.render.device.render_resolution;

    setViewport(command_buffer, *(Viewport.{
        width  = cast(f32) render_resolution.width,
        height = cast(f32) render_resolution.height,
    }), render_resolution.height);

    setScissorRect(command_buffer, *(ScissorRect.{
        width  = render_resolution.width,
        height = render_resolution.height,
    }));

    setShader(command_buffer, floor.shader);

    setPushConstants(command_buffer, floor.push_constants_handle, *(Floor.PushConstants.{
        per_view_uniform_index = per_view_uniform.handles[context.pet.render.device.frame_index][per_view_uniform.version].descriptor
    }));

    drawPrimitives(command_buffer, 4);
}
