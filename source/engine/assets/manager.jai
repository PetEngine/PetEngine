// @TODO: #AssetManager.
//     - Possible owners for resource
//     - Transfer command buffer

AssetManager :: struct {
    UploadRingBuffer :: struct {
        buffer      : *Buffer;
        read_index  : u64;
        write_index : u64;
    }

    command_buffer : CommandBuffer(.GRAPHICS);
    upload_buffer  : UploadRingBuffer;
}

createAssetManager :: (device : *Device, resource_manager : *ResourceManager) -> *AssetManager {
    manager := pushToArena(*context.pet.persistent_arena, AssetManager);

    manager.command_buffer = createCommandBuffer(device, AssetManager.command_buffer.usage);

    // #Settings. Capacity
    BUFFER_CAPACITY :: #run megaBytes(512);
    #assert isPowerOfTwo(BUFFER_CAPACITY);

    manager.upload_buffer.buffer = createBuffer(device,
                                                resource_manager,
                                                BUFFER_CAPACITY,
                                                .PERSISTENT,
                                                .UPLOAD,
                                                .NONE,
                                                "AssetManager upload ring buffer",
                                                AssetManager.command_buffer.usage);

    return manager;
}

resetAssetManager :: (device : *Device, manager : *AssetManager) {
    resetCommandBuffer(device, *manager.command_buffer, null);
}

loadMesh :: (device : *Device, manager : *AssetManager, resource_manager : *ResourceManager, name : string) -> Mesh {
    autoResetPerFrameArenas();

    file_data, error := readEntireFile(makeRuntimeMeshFilename(name), pushToArena, *context.pet.per_frame_arena);
    assert(error == .NONE);

    header := MeshFile.getHeader(file_data);
    assert(header.version == MeshFile.VERSION);

    mesh := Mesh.{
        vertex_format   = header.vertex_format,
        submeshes_count = header.submeshes_count
    };

    //
    // Calculate vertices and indices total size, fill submesh infos
    //

    vertex_stride := cast(u64) getVertexStride(mesh.vertex_format);

    all_vertices_bytes : u64;
    all_indices_bytes  : u64;

    submesh_infos_it := mesh.submesh_infos.data;
    for toView(header.submesh_infos.data, mesh.submeshes_count) {
        submesh_infos_it.vertices_offset = cast(u64) all_vertices_bytes;
        submesh_infos_it.indices_offset  = cast(u64) all_indices_bytes;

        all_vertices_bytes += it.vertices_count * vertex_stride;
        all_indices_bytes  += it.indices_count  * size_of(u32);

        submesh_infos_it += 1;
    }

    //
    // Calculate offsets in upload buffer
    //

    upload_buffer_size_mask := manager.upload_buffer.buffer.size - 1;

    vertices_offset : u32 = ---;
    indices_offset  : u32 = ---;
    {
        all_bytes := all_vertices_bytes + all_indices_bytes;

        old_index := manager.upload_buffer.write_index;
        new_index := old_index + all_bytes;
        while lock_cmpxchg(*manager.upload_buffer.write_index, old_index, new_index) != old_index {
            old_index = manager.upload_buffer.write_index;
            new_index = old_index + all_bytes;
        }

        assert(new_index - manager.upload_buffer.read_index <= manager.upload_buffer.buffer.size, "Upload ring buffer overflow");

        vertices_offset = cast(u32) (old_index & upload_buffer_size_mask);
        indices_offset  = cast(u32) ((old_index + all_vertices_bytes) & upload_buffer_size_mask);
    }

    //
    // Create vertex buffer, copy data to upload buffer, copy chunks of upload buffer to vertex buffer
    //

    {
        assert(all_vertices_bytes);
        mesh.vertex_buffer = createBuffer(device,
                                          resource_manager,
                                          cast(u32) all_vertices_bytes,
                                          .PER_SCENE,
                                          .DEFAULT,
                                          .READ_ONLY,
                                          String.join(name, " vertices",, allocator = Basic.temp));

        stream := file_data;
        advance(*stream, size_of(MeshFile.Header));

        offset_start    := vertices_offset;
        remaining_bytes := all_vertices_bytes;
        while remaining_bytes {
            chunk_bytes := cast(u32) min(remaining_bytes, manager.upload_buffer.buffer.size);

            memcpy(manager.upload_buffer.buffer.mapped_memory + offset_start, stream.data, chunk_bytes);
            copyBuffer(device, *manager.command_buffer, mesh.vertex_buffer, manager.upload_buffer.buffer, 0, offset_start, chunk_bytes);

            advance(*stream, chunk_bytes);
            offset_start     = (offset_start + chunk_bytes) & upload_buffer_size_mask;
            remaining_bytes -= chunk_bytes;
        }
    }

    //
    // Create index buffer, copy data to upload buffer, copy chunks of upload buffer to index buffer
    //

    if all_indices_bytes {
        mesh.index_buffer = createBuffer(device,
                                         resource_manager,
                                         cast(u32) all_indices_bytes,
                                         .PER_SCENE,
                                         .DEFAULT,
                                         .READ_ONLY,
                                         String.join(name, " indices",, allocator = Basic.temp));

        stream := file_data;
        advance(*stream, size_of(MeshFile.Header) + cast(s64) all_vertices_bytes);

        offset_start    := indices_offset;
        remaining_bytes := all_indices_bytes;
        while remaining_bytes {
            chunk_bytes := cast(u32) min(remaining_bytes, manager.upload_buffer.buffer.size);

            memcpy(manager.upload_buffer.buffer.mapped_memory + offset_start, stream.data, chunk_bytes);
            copyBuffer(device, *manager.command_buffer, mesh.index_buffer, manager.upload_buffer.buffer, 0, offset_start, chunk_bytes);

            advance(*stream, chunk_bytes);
            offset_start     = (offset_start + chunk_bytes) & upload_buffer_size_mask;
            remaining_bytes -= chunk_bytes;
        }
    }

    return mesh;
}
