Heart :: struct {
    PushConstants :: union {
        StructuredData :: struct {
            index_buffer_reference  : u64;
            vertex_buffer_reference : u64;
            per_view_uniform_index  : u32;
        } #no_padding
        using structured_data : StructuredData;

        _packed : [2] v4u;
        #assert(size_of(type_of(_packed)) >= size_of(StructuredData));
    } #no_padding

    shader                : *Shader;
    mesh                  : *Mesh;
    push_constants_handle : PushConstantsHandle;
    submesh_index         : s8;
}

createHeart :: (depth_format : Texture.Format) -> Heart {
    heart : Heart;
    heart.shader                = createShader("heart", .[ context.pet.render.device.back_buffer_format ], depth_format );
    heart.push_constants_handle = getPushConstantsHandle(heart.shader, "g_push_constants");
    return heart;
}

loadHeartMesh :: (heart : *Heart) {
    heart.mesh = requestMesh("HumanHeart_OBJ");
}

updateHeart :: (heart : *Heart, input : *Input) {
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

drawHeart :: (command_buffer : *CommandBuffer, heart : *Heart, per_view_uniform : *PerViewUniform) {
    if !isMeshReady(heart.mesh) return;

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

    setPushConstants(command_buffer, heart.push_constants_handle, *(Heart.PushConstants.{
        index_buffer_reference  = heart.mesh.index_buffer.device_address,
        vertex_buffer_reference = heart.mesh.vertex_buffer.device_address,
        per_view_uniform_index  = per_view_uniform.handles[context.pet.render.device.frame_index][per_view_uniform.version].descriptor,
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
