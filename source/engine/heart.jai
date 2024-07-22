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

createHeart :: (
    device          : *Device,
    shader_manager  : *ShaderManager,
    binding_manager : *BindingManager,
    depth_format    : Texture.Format
) -> Heart {
    heart : Heart;
    heart.shader                = createShader(device, shader_manager, binding_manager, "heart", .[ getBackBuffer(device).format ], depth_format );
    heart.push_constants_handle = getPushConstantsHandle(heart.shader, "g_push_constants");
    return heart;
}

loadHeartMesh :: (device : *Device, asset_manager : *AssetManager, resource_manager : *ResourceManager, heart : *Heart) {
    heart.mesh = requestMesh(device, asset_manager, resource_manager, "HumanHeart_OBJ");
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

drawHeart :: (
    device           : *Device,
    shader_manager   : *ShaderManager,
    binding_manager  : *BindingManager,
    command_buffer   : *CommandBuffer,
    heart            : *Heart,
    per_view_uniform : *PerViewUniform
) {
    if !isMeshReady(device, heart.mesh) return;

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

    setShader(device, command_buffer, shader_manager, binding_manager, heart.shader);

    setPushConstants(device, command_buffer, heart.push_constants_handle, *(Heart.PushConstants.{
        index_buffer_reference  = heart.mesh.index_buffer.device_address,
        vertex_buffer_reference = heart.mesh.vertex_buffer.device_address,
        per_view_uniform_index  = per_view_uniform.handles[device.frame_index][per_view_uniform.version].descriptor,
    }));

    if heart.submesh_index == 0 {
        for toView(heart.mesh.submesh_infos.data, heart.mesh.submeshes_count) {
            drawPrimitives(device, command_buffer, it.indices_count, 1, it.indices_skip, it.vertices_skip);
        }
    } else {
        submesh := *heart.mesh.submesh_infos[heart.submesh_index];
        drawPrimitives(device, command_buffer, submesh.indices_count, 1, submesh.indices_skip, submesh.vertices_skip);
    }
}
