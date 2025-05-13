Heart :: struct {
    VSPushConstants :: struct {
        index_buffer_reference  : u64;
        vertex_buffer_reference : u64;
        per_view_uniform_index  : u32;
    } #no_padding

    PSPushConstants :: struct {
        texture_index : u16;
        sampler_index : u16;
    } #no_padding

    shader : *Shader;

    mesh          : *Mesh;
    submesh_index : s8;

    vs_push_constants_handle : PushConstantsHandle;
    ps_push_constants_handle : PushConstantsHandle;

    sampler                 : *Sampler;
    sampler_binding_handle  : BindingHandle;

    texture_assets          : [10] *TextureAsset;
    texture_binding_handles : [10] BindingHandle;
}

createHeart :: (depth_format : Texture.Format) -> Heart {
    heart : Heart;
    heart.shader                   = createShader("heart", .[ context.pet.render.device.back_buffer_format ], depth_format );
    heart.vs_push_constants_handle = getPushConstantsHandle(heart.shader, "g_vs_push_constants");
    heart.ps_push_constants_handle = getPushConstantsHandle(heart.shader, "g_ps_push_constants");
    return heart;
}

loadHeart :: (heart : *Heart) {
    heart.mesh = requestMesh("HumanHeart_OBJ");

    heart.sampler = createSampler(.{ min_filter = .LINEAR, mag_filter = .LINEAR, mip_filter = .LINEAR }, .PER_SCENE, "Trilinear sampler" );

    heart.texture_assets[0] = requestTexture("HumanBase___cavity");
    heart.texture_assets[1] = requestTexture("HumanBase__color");
    heart.texture_assets[2] = requestTexture("HumanBase__normals");
    heart.texture_assets[3] = requestTexture("HumanOpening__cavity");
    heart.texture_assets[4] = requestTexture("HumanOpening__color");
    heart.texture_assets[5] = requestTexture("HumanOpening__normals");
    heart.texture_assets[6] = requestTexture("MitralValve__cavity");
    heart.texture_assets[7] = requestTexture("MitralValve_normals");
    heart.texture_assets[8] = requestTexture("TricuspidValve_cavity");
    heart.texture_assets[9] = requestTexture("TricuspidValve_normals");
}

bindHeart :: (heart : *Heart) {
    heart.sampler_binding_handle = pushBinding(.PER_SCENE, heart.sampler);

    for heart.texture_assets {
        heart.texture_binding_handles[it_index] = pushBinding(.PER_SCENE, it.texture_view);
    }
}

updateHeart :: (heart : *Heart, input : Input) {
    if !heart.mesh return;

    first_key := Input.Key.KEY_0;
    last_key  := Input.Key.KEY_0 + cast(Input.Key) heart.mesh.submeshes_count; // no need for -1
    for first_key .. last_key {
        if input.keyboard[it] & .PRESSED {
            heart.submesh_index = cast(s8) (it - first_key);
            debugMessage("heart.submesh_index = %", heart.submesh_index);
            break;
        }
    }
}

drawHeart :: (command_buffer : *CommandBuffer, heart : Heart, per_view_uniform : PerViewUniform) {
    if !isMeshReady(heart.mesh) return;
    if !isTextureReady(heart.texture_assets[0]) return;

    render_resolution := context.pet.render.device.render_resolution;

    setViewport(command_buffer, *(Viewport.{
        width  = cast(f32) render_resolution.width,
        height = cast(f32) render_resolution.height,
    }), render_resolution.height);

    setScissorRect(command_buffer, *(ScissorRect.{
        width  = render_resolution.width,
        height = render_resolution.height,
    }));

    setShader(command_buffer, heart.shader);

    setPushConstants(command_buffer, heart.vs_push_constants_handle, *(Heart.VSPushConstants.{
        index_buffer_reference  = heart.mesh.index_buffer.device_address,
        vertex_buffer_reference = heart.mesh.vertex_buffer.device_address,
        per_view_uniform_index  = per_view_uniform.handles[context.pet.render.device.frame_index][per_view_uniform.version].descriptor,
    }));

    setPushConstants(command_buffer, heart.ps_push_constants_handle, *(Heart.PSPushConstants.{
        texture_index = heart.texture_binding_handles[1].descriptor,
        sampler_index = heart.sampler_binding_handle.descriptor,
    }));

    if heart.submesh_index == 0 {
        for toView(heart.mesh.submesh_infos.data, heart.mesh.submeshes_count) {
            drawPrimitives(command_buffer, it.indices_count, 1, it.indices_skip, it.vertices_skip);
        }
    } else {
        submesh := *heart.mesh.submesh_infos[heart.submesh_index];
        drawPrimitives(command_buffer, submesh.indices_count, 1, submesh.indices_skip, submesh.vertices_skip);
    }
}
