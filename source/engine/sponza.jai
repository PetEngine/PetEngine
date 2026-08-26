Sponza :: struct {
    PushConstants :: struct {
        index_buffer_reference    : u64;
        vertex_buffer_reference   : u64;
        mesh_buffer_reference     : u64;
        material_buffer_reference : u64;
        per_view_uniform_index    : u32;
        sampler_index             : u16;
        first_texture_index       : u16;
    } #no_padding

    shader : *Shader;

    model         : ModelAsset;
    sampler       : *Sampler;
    texture_views : [69] *TextureView;

    handles : struct {
        push_constants : PushConstantsHandle;
        sampler        : BindingHandle;
        textures       : [texture_views.count] BindingHandle;
    };
}

createSponza :: (depth_format : Texture.Format) -> Sponza {
    sponza : Sponza;
    sponza.shader = createShader("model", .[ context.pet.render.device.back_buffer_format ], depth_format );
    sponza.handles.push_constants = getPushConstantsHandle(sponza.shader, "g_push_constants");
    return sponza;
}

destroySponza :: (sponza : *Sponza) {
    destroyModel(*sponza.model);
    sponza.* = .{};
}

loadSponza :: (sponza : *Sponza) {
    sponza.model = requestModel("Sponza");
    assert(sponza.model.vertex_format == .PNTUV);

    sponza.sampler = createSampler(.{
        min_filter     = .LINEAR,
        mag_filter     = .LINEAR,
        mip_filter     = .LINEAR,
        address_mode_u = .WRAP,
        address_mode_v = .WRAP,
        address_mode_w = .WRAP,
    }, .PER_SCENE, "Trilinear wrap sampler" );

    assert(sponza.model.textures.count <= Sponza.texture_views.count);
    for sponza.model.textures {
        sponza.texture_views[it_index] = createTextureView(it, .SHADER_READ, lifetime = .PER_SCENE);
    }
}

bindSponza :: (sponza : *Sponza) {
    sponza.handles.sampler = pushBinding(.PER_SCENE, sponza.sampler);

    for sponza.model.textures {
        sponza.handles.textures[it_index] = pushBinding(.PER_SCENE, sponza.texture_views[it_index]);
    }
}

drawSponza :: (command_buffer : *CommandBuffer, sponza : Sponza, per_view_uniform : PerViewUniform) {
    if !isAssetReady(*sponza.model) return;

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

    setPushConstants(command_buffer, sponza.handles.push_constants, *(Sponza.PushConstants.{
        index_buffer_reference    = sponza.model.buffer.device_address + sponza.model.indices_offset,
        vertex_buffer_reference   = sponza.model.buffer.device_address + sponza.model.vertices_offset,
        mesh_buffer_reference     = sponza.model.buffer.device_address + sponza.model.meshes_offset,
        material_buffer_reference = sponza.model.buffer.device_address + sponza.model.materials_offset,
        per_view_uniform_index    = per_view_uniform.handles[context.pet.render.device.frame_index][per_view_uniform.version].descriptor,
        sampler_index             = sponza.handles.sampler.descriptor,
        first_texture_index       = sponza.handles.textures[0].descriptor
    }));

    for sponza.model.meshes {
        drawPrimitives(command_buffer, it.indices_count, 1, it.indices_start, cast(u32) it_index);
    }
}
