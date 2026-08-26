Heart :: struct {
    VSPushConstants :: struct {
        index_buffer_reference  : u64;
        vertex_buffer_reference : u64;
        mesh_buffer_reference   : u64;
        per_view_uniform_index  : u32;
    } #no_padding

    PSPushConstants :: struct {
        texture_index : u16;
        sampler_index : u16;
    } #no_padding

    shader : *Shader;

    model : ModelAsset;

    vs_push_constants_handle : PushConstantsHandle;
    ps_push_constants_handle : PushConstantsHandle;

    sampler                 : *Sampler;
    sampler_binding_handle  : BindingHandle;

    textures                : [10] TextureAsset;
    texture_views           : [10] *TextureView;
    texture_binding_handles : [10] BindingHandle;
}

createHeart :: (depth_format : Texture.Format) -> Heart {
    heart : Heart;
    heart.shader                   = createShader("heart", .[ context.pet.render.device.back_buffer_format ], depth_format );
    heart.vs_push_constants_handle = getPushConstantsHandle(heart.shader, "g_vs_push_constants");
    heart.ps_push_constants_handle = getPushConstantsHandle(heart.shader, "g_ps_push_constants");
    return heart;
}

destroyHeart :: (heart : *Heart) {
    destroyModel(*heart.model);
    heart.* = .{};
}

loadHeart :: (heart : *Heart) {
    heart.model = requestModel("HumanHeart_OBJ");

    heart.sampler = createSampler(.{ min_filter = .LINEAR, mag_filter = .LINEAR, mip_filter = .LINEAR }, .PER_SCENE, "Trilinear sampler" );

    heart.textures[0] = requestTexture("heart/HumanBase___cavity");
    heart.textures[1] = requestTexture("heart/HumanBase__color");
    heart.textures[2] = requestTexture("heart/HumanBase__normals");
    heart.textures[3] = requestTexture("heart/HumanOpening__cavity");
    heart.textures[4] = requestTexture("heart/HumanOpening__color");
    heart.textures[5] = requestTexture("heart/HumanOpening__normals");
    heart.textures[6] = requestTexture("heart/MitralValve__cavity");
    heart.textures[7] = requestTexture("heart/MitralValve_normals");
    heart.textures[8] = requestTexture("heart/TricuspidValve_cavity");
    heart.textures[9] = requestTexture("heart/TricuspidValve_normals");

    for * heart.texture_views {
        it.* = createTextureView(heart.textures[it_index], .SHADER_READ, lifetime = .PER_SCENE);
    }
}

bindHeart :: (heart : *Heart) {
    heart.sampler_binding_handle = pushBinding(.PER_SCENE, heart.sampler);

    for * heart.texture_binding_handles {
        it.* = pushBinding(.PER_SCENE, heart.texture_views[it_index]);
    }
}

drawHeart :: (command_buffer : *CommandBuffer, heart : Heart, per_view_uniform : PerViewUniform) {
    if !isAssetReady(*heart.model) return;
    if !isAssetReady(*heart.textures[0]) return;

    render_resolution := context.pet.render.device.render_resolution;

    setViewport(command_buffer, .{
        width  = cast(f32) render_resolution.width,
        height = cast(f32) render_resolution.height,
    }, render_resolution.height);

    setScissorRect(command_buffer, .{
        width  = render_resolution.width,
        height = render_resolution.height,
    });

    setShader(command_buffer, heart.shader);

    setPushConstants(command_buffer, heart.vs_push_constants_handle, *(Heart.VSPushConstants.{
        index_buffer_reference  = heart.model.index_buffer.device_address,
        vertex_buffer_reference = heart.model.vertex_buffer.device_address,
        mesh_buffer_reference   = heart.model.mesh_buffer.device_address,
        per_view_uniform_index  = per_view_uniform.handles[context.pet.render.device.frame_index][per_view_uniform.version].descriptor,
    }));

    setPushConstants(command_buffer, heart.ps_push_constants_handle, *(Heart.PSPushConstants.{
        texture_index = heart.texture_binding_handles[1].descriptor,
        sampler_index = heart.sampler_binding_handle.descriptor,
    }));

    assert(heart.model.meshes.count == 1);
    drawPrimitives(command_buffer, heart.model.meshes[0].indices_count);
}
