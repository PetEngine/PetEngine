Heart :: struct {
    shader : *Shader;

    model         : ModelAsset;
    sampler       : *Sampler;
    textures      : [10] TextureAsset;
    texture_views : [textures.count] *TextureView;

    handles : struct {
        push_constants : PushConstantsHandle;
        sampler        : BindingHandle;
        textures       : [texture_views.count] BindingHandle;
    };
}

createHeart :: (depth_format : Texture.Format) -> Heart {
    heart : Heart;
    heart.shader = getOrCreateShader("opaque_model", .[ context.pet.render.device.back_buffer_format ], depth_format );
    heart.handles.push_constants = getPushConstantsHandle(heart.shader, "g_push_constants");
    return heart;
}

destroyHeart :: (heart : *Heart) {
    destroyAsset(*heart.model);
    for * heart.textures {
        destroyAsset(it);
    }
    heart.* = .{};
}

loadHeart :: (heart : *Heart) {
    heart.model = requestModel("HumanHeart_OBJ");

    // Initial world transform
    {
        postTranslate(*heart.model.model_to_world, .{ y =  6.0 });
        preTranslate(*heart.model.world_to_model,  .{ y = -6.0 });
    }

    heart.sampler = createSampler(.{ min_filter = .LINEAR, mag_filter = .LINEAR, mip_filter = .LINEAR }, .PER_SCENE, "Trilinear clamp sampler" );

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
    heart.handles.sampler = pushBinding(.PER_SCENE, heart.sampler);

    for * heart.handles.textures {
        it.* = pushBinding(.PER_SCENE, heart.texture_views[it_index]);
    }
}

updateHeart :: (heart : *Heart, dt : f32) {
    rot     := rotationY(dt);
    inv_rot := transpose(rot);

    postTransform(*heart.model.model_to_world, extend(rot, m3x4));
    preTransform(*heart.model.world_to_model, extend(inv_rot, m3x4));
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

    setPushConstants(command_buffer, heart.handles.push_constants, *(Model.PushConstants.{
        index_buffer_reference    = heart.model.buffer.device_address + heart.model.indices_offset,
        vertex_buffer_reference   = heart.model.buffer.device_address + heart.model.vertices_offset,
        mesh_buffer_reference     = heart.model.buffer.device_address + heart.model.meshes_offset,
        material_buffer_reference = heart.model.buffer.device_address + heart.model.materials_offset,
        model_to_world            = heart.model.model_to_world,
        world_to_model            = heart.model.world_to_model,
        per_view_uniform_index    = per_view_uniform.handles[context.pet.render.device.frame_index][per_view_uniform.version].descriptor,
        sampler_index             = heart.handles.sampler.descriptor,
        first_texture_index       = heart.handles.textures[0].descriptor
    }));

    assert(heart.model.meshes.count == 1);
    drawPrimitives(command_buffer, heart.model.meshes[0].indices_count);
}
