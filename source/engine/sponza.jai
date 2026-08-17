Sponza :: struct {
    VSPushConstants :: struct {
        index_buffer_reference  : u64;
        vertex_buffer_reference : u64;
        mesh_buffer_reference   : u64;
        per_view_uniform_index  : u32;
    } #no_padding

    PSPushConstants :: struct {
        material_buffer_reference : u64;
        per_view_uniform_index    : u32;
    } #no_padding

    shader  : *Shader;
    model   : *Model;
    handles : struct {
        vs_push_constants : PushConstantsHandle;
        ps_push_constants : PushConstantsHandle;
    };
}

createSponza :: (depth_format : Texture.Format) -> Sponza {
    sponza : Sponza;
    sponza.shader = createShader("sponza", .[ context.pet.render.device.back_buffer_format ], depth_format );
    sponza.handles.vs_push_constants = getPushConstantsHandle(sponza.shader, "g_vs_push_constants");
    sponza.handles.ps_push_constants = getPushConstantsHandle(sponza.shader, "g_ps_push_constants");
    return sponza;
}

destroySponza :: (sponza : *Sponza) {
    if sponza.model {
        if sponza.model.textures.data then Basic.array_reset(*sponza.model.textures);
        if sponza.model.meshes.data   then Basic.array_reset(*sponza.model.meshes);
    }
    sponza.* = .{};
}

loadSponza :: (sponza : *Sponza) {
    sponza.model = requestModel("Sponza");
}

drawSponza :: (command_buffer : *CommandBuffer, sponza : Sponza, per_view_uniform : PerViewUniform) {
    if !isModelReady(sponza.model) return;

    render_resolution := context.pet.render.device.render_resolution;

    setViewport(command_buffer, .{
        width  = cast(f32) render_resolution.width,
        height = cast(f32) render_resolution.height,
    }, render_resolution.height);

    setScissorRect(command_buffer, .{
        width  = render_resolution.width,
        height = render_resolution.height,
    });

    setShader(command_buffer, sponza.shader);

    setPushConstants(command_buffer, sponza.handles.vs_push_constants, *(Sponza.VSPushConstants.{
        index_buffer_reference  = sponza.model.index_buffer.device_address,
        vertex_buffer_reference = sponza.model.vertex_buffer.device_address,
        mesh_buffer_reference   = sponza.model.mesh_buffer.device_address,
        per_view_uniform_index  = per_view_uniform.handles[context.pet.render.device.frame_index][per_view_uniform.version].descriptor,
    }));

    setPushConstants(command_buffer, sponza.handles.ps_push_constants, *(Sponza.PSPushConstants.{
        material_buffer_reference = sponza.model.material_buffer.device_address,
        per_view_uniform_index    = per_view_uniform.handles[context.pet.render.device.frame_index][per_view_uniform.version].descriptor,
    }));

    for sponza.model.meshes {
        drawPrimitives(command_buffer, it.indices_count, 1, it.indices_start, cast(u32) it_index);
    }
}
