Skybox :: struct {
    VSPushConstants :: struct {
        per_view_uniform_index : u32;
    } #no_padding

    PSPushConstants :: struct {
        texture_index : u16;
        sampler_index : u16;
    } #no_padding

    shader : *Shader;

    skybox_index : u8;

    vs_push_constants_handle : PushConstantsHandle;
    ps_push_constants_handle : PushConstantsHandle;

    sampler                 : *Sampler;
    sampler_binding_handle  : BindingHandle;

    texture_assets          : [3] *TextureAsset;
    texture_binding_handles : [3] BindingHandle;
}

createSkybox :: (depth_format : Texture.Format) -> Skybox {
    skybox : Skybox;
    skybox.shader                   = createShader("skybox", .[ context.pet.render.device.back_buffer_format ], depth_format );
    skybox.vs_push_constants_handle = getPushConstantsHandle(skybox.shader, "g_vs_push_constants");
    skybox.ps_push_constants_handle = getPushConstantsHandle(skybox.shader, "g_ps_push_constants");
    return skybox;
}

loadSkybox :: (skybox : *Skybox) {
    skybox.sampler = createSampler(.{
        min_filter = .LINEAR,
        mag_filter = .LINEAR,
        mip_filter = .LINEAR,
        anisotropy = Sampler.MAX_ANISOTROPY
    }, .PER_SCENE, "Anisotropic sampler" );

    skybox.texture_assets[0] = requestTexture("skybox_night");
    skybox.texture_assets[1] = requestTexture("skybox_mirror");
    skybox.texture_assets[2] = requestTexture("skybox_desert");
}

bindSkybox :: (skybox : *Skybox) {
    skybox.sampler_binding_handle = pushBinding(.PER_SCENE, skybox.sampler);

    for skybox.texture_assets {
        skybox.texture_binding_handles[it_index] = pushBinding(.PER_SCENE, it.texture_view);
    }
}

updateSkybox :: (skybox : *Skybox, input : Input) {
    if (input.keyboard[Input.Key.LEFT_CTRL] | input.keyboard[Input.Key.RIGHT_CTRL]) & .DOWN {
        /**/ if input.keyboard[Input.Key.KEY_1] & .RELEASED then skybox.skybox_index = 0;
        else if input.keyboard[Input.Key.KEY_2] & .RELEASED then skybox.skybox_index = 1;
        else if input.keyboard[Input.Key.KEY_3] & .RELEASED then skybox.skybox_index = 2;
    }
}

drawSkybox :: (command_buffer : *CommandBuffer, skybox : Skybox, per_view_uniform : PerViewUniform) {
    if !isTextureReady(skybox.texture_assets[skybox.skybox_index]) return;

    render_resolution := context.pet.render.device.render_resolution;

    setViewport(command_buffer, *(Viewport.{
        width  = cast(f32) render_resolution.width,
        height = cast(f32) render_resolution.height,
    }), render_resolution.height);

    setScissorRect(command_buffer, *(ScissorRect.{
        width  = render_resolution.width,
        height = render_resolution.height,
    }));

    setShader(command_buffer, skybox.shader);

    setPushConstants(command_buffer, skybox.vs_push_constants_handle, *(Skybox.VSPushConstants.{
        per_view_uniform_index = per_view_uniform.handles[context.pet.render.device.frame_index][per_view_uniform.version].descriptor,
    }));

    setPushConstants(command_buffer, skybox.ps_push_constants_handle, *(Skybox.PSPushConstants.{
        texture_index = skybox.texture_binding_handles[skybox.skybox_index].descriptor,
        sampler_index = skybox.sampler_binding_handle.descriptor,
    }));

    drawPrimitives(command_buffer, 4);
}
