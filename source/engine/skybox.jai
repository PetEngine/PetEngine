Skybox :: struct {
    VSPushConstants :: struct {
        per_view_uniform_index : u32;
    }

    PSPushConstants :: struct {
        texture_index : u16;
        __padding     : u16;
    }

    shader : *Shader;

    skybox_index : u8;

    textures      : [3] TextureAsset;
    texture_views : [textures.count] *TextureView;

    handles : struct {
        vs_push_constants : PushConstantsHandle;
        ps_push_constants : PushConstantsHandle;
        textures          : [texture_views.count] BindingHandle;
    };
}

#assert size_of(Skybox.VSPushConstants) & 3 == 0 "https://docs.vulkan.org/spec/latest/chapters/descriptorsets.html#VUID-VkPushConstantRange-size-00297";
#assert size_of(Skybox.PSPushConstants) & 3 == 0 "https://docs.vulkan.org/spec/latest/chapters/descriptorsets.html#VUID-VkPushConstantRange-size-00297";

createSkybox :: (depth_format : Texture.Format) -> Skybox {
    skybox : Skybox;
    skybox.shader                    = getOrCreateShader("skybox", .[ context.pet.render.device.back_buffer_format ], depth_format );
    skybox.handles.vs_push_constants = getPushConstantsHandle(skybox.shader, "g_vs_push_constants");
    skybox.handles.ps_push_constants = getPushConstantsHandle(skybox.shader, "g_ps_push_constants");
    return skybox;
}

destroySkybox :: (skybox : *Skybox) {
    for * skybox.textures {
        destroyAsset(it);
    }
    skybox.* = .{};
}

loadSkybox :: (skybox : *Skybox) {
    skybox.textures[0] = requestTexture("skybox_night");
    skybox.textures[1] = requestTexture("skybox_mirror");
    skybox.textures[2] = requestTexture("skybox_desert");

    for * skybox.texture_views {
        it.* = createTextureView(skybox.textures[it_index], .SHADER_READ, lifetime = .PER_SCENE);
    }
}

bindSkybox :: (skybox : *Skybox) {
    for * skybox.handles.textures {
        it.* = pushBinding(.PER_SCENE, skybox.texture_views[it_index]);
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
    if !isAssetReady(*skybox.textures[skybox.skybox_index]) return;

    render_resolution := context.pet.render.device.render_resolution;

    setViewport(command_buffer, .{
        width  = cast(f32) render_resolution.width,
        height = cast(f32) render_resolution.height,
    }, render_resolution.height);

    setScissorRect(command_buffer, .{
        width  = render_resolution.width,
        height = render_resolution.height,
    });

    setShader(command_buffer, skybox.shader);

    setPushConstants(command_buffer, skybox.handles.vs_push_constants, *(Skybox.VSPushConstants.{
        per_view_uniform_index = per_view_uniform.handles[context.pet.render.device.frame_index][per_view_uniform.version].descriptor,
    }));

    setPushConstants(command_buffer, skybox.handles.ps_push_constants, *(Skybox.PSPushConstants.{
        texture_index = skybox.handles.textures[skybox.skybox_index].descriptor
    }));

    drawPrimitives(command_buffer, 4);
}
