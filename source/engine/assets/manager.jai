// @TODO: #AssetManager.
//     - Possible owners for resource
//     - Transfer command buffer

AssetManager :: struct {
    UploadRingBuffer :: struct {
        buffer      : *Buffer;
        read_index  : u64;
        write_index : u64;
    }

    MeshAsset :: struct {
        #as using mesh : Mesh;

        all_vertices_bytes : u64;
        all_indices_bytes  : u64;

        vertices_offset : u32;
        indices_offset  : u32;

        name : string;
    }

    command_buffer : CommandBuffer(.GRAPHICS);
    upload_buffer  : UploadRingBuffer;

    mesh_assets : StaticArray(MeshAsset, 1024);
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
    assertThreadKind(.MAIN);
    resetCommandBuffer(device, *manager.command_buffer, null);
}

resetAssetManagerAssets :: (manager : *AssetManager) {
    assertThreadKind(.MAIN);
    reset(*manager.mesh_assets);
}

processRequestedAssets :: (device : *Device, manager : *AssetManager, resource_manager : *ResourceManager) {
    assertThreadKind(.MAIN);
    assert(resourceMemoryCommitted(resource_manager, .PER_SCENE));

    for manager.mesh_assets {
        autoResetPerFrameArenas();

        file_data, error := readEntireFile(makeRuntimeMeshFilename(it.name), pushToArena, *context.pet.per_frame_arena);
        assert(error == .NONE);

        upload_buffer_size_mask := manager.upload_buffer.buffer.size - 1;

        assert(it.vertex_buffer);
        {
            stream := file_data;
            advance(*stream, size_of(MeshFile.Header));

            assert(manager.upload_buffer.read_index == it.vertices_offset);

            offset_start    := it.vertices_offset;
            remaining_bytes := it.all_vertices_bytes;
            while remaining_bytes {
                chunk_bytes := cast(u32) min(remaining_bytes, manager.upload_buffer.buffer.size);

                memcpy(manager.upload_buffer.buffer.mapped_memory + offset_start, stream.data, chunk_bytes);
                copyBuffer(device, *manager.command_buffer, it.vertex_buffer, manager.upload_buffer.buffer, 0, offset_start, chunk_bytes);

                // We cannot read or write to read_index during processRequestedAssets, so there is no sense for atomic increment
                manager.upload_buffer.read_index += chunk_bytes;

                advance(*stream, chunk_bytes);
                offset_start     = (offset_start + chunk_bytes) & upload_buffer_size_mask;
                remaining_bytes -= chunk_bytes;
            }
        }

        if it.all_indices_bytes {
            stream := file_data;
            advance(*stream, size_of(MeshFile.Header) + cast(s64) it.all_vertices_bytes);

            assert(manager.upload_buffer.read_index == it.indices_offset);

            offset_start    := it.indices_offset;
            remaining_bytes := it.all_indices_bytes;
            while remaining_bytes {
                chunk_bytes := cast(u32) min(remaining_bytes, manager.upload_buffer.buffer.size);

                memcpy(manager.upload_buffer.buffer.mapped_memory + offset_start, stream.data, chunk_bytes);
                copyBuffer(device, *manager.command_buffer, it.index_buffer, manager.upload_buffer.buffer, 0, offset_start, chunk_bytes);

                // We cannot read or write to read_index during processRequestedAssets, so there is no sense for atomic increment
                manager.upload_buffer.read_index += chunk_bytes;

                advance(*stream, chunk_bytes);
                offset_start     = (offset_start + chunk_bytes) & upload_buffer_size_mask;
                remaining_bytes -= chunk_bytes;
            }
        }
    }
}

requestMesh :: (device : *Device, manager : *AssetManager, resource_manager : *ResourceManager, name : string) -> *Mesh {
    assert(!resourceMemoryCommitted(resource_manager, .PER_SCENE));

    header : MeshFile.Header = ---;
    {
        file, error := openFile(makeRuntimeMeshFilename(name), .READ | .SHARED_READ | .EXISTS);
        assert(error == .NONE);
        defer closeFile(*file);

        readFile(file, *header);
        assert(header.version == MeshFile.VERSION);
    }

    mesh := pushBack(*manager.mesh_assets);
    mesh.vertex_format   = header.vertex_format;
    mesh.submeshes_count = header.submeshes_count;
    mesh.name            = name;

    //
    // Calculate vertices and indices total size, fill submesh infos
    //

    vertex_stride := cast(u64) getVertexStride(mesh.vertex_format);

    submesh_infos_it := mesh.submesh_infos.data;
    for toView(header.submesh_infos.data, mesh.submeshes_count) {
        submesh_infos_it.vertices_offset = cast(u64) mesh.all_vertices_bytes;
        submesh_infos_it.indices_offset  = cast(u64) mesh.all_indices_bytes;

        mesh.all_vertices_bytes += it.vertices_count * vertex_stride;
        mesh.all_indices_bytes  += it.indices_count  * size_of(u32);

        submesh_infos_it += 1;
    }

    //
    // Calculate offsets in upload buffer
    //

    {
        all_bytes := mesh.all_vertices_bytes + mesh.all_indices_bytes;

        old_index := manager.upload_buffer.write_index;
        new_index := old_index + all_bytes;
        while lock_cmpxchg(*manager.upload_buffer.write_index, old_index, new_index) != old_index {
            old_index = manager.upload_buffer.write_index;
            new_index = old_index + all_bytes;
        }

        assert(new_index - manager.upload_buffer.read_index <= manager.upload_buffer.buffer.size, "Upload ring buffer overflow");

        upload_buffer_size_mask := manager.upload_buffer.buffer.size - 1;

        mesh.vertices_offset = cast(u32) (old_index & upload_buffer_size_mask);
        mesh.indices_offset  = cast(u32) ((old_index + mesh.all_vertices_bytes) & upload_buffer_size_mask);
    }

    //
    // Create buffers
    //

    assert(mesh.all_vertices_bytes);
    mesh.vertex_buffer = createBuffer(device,
                                      resource_manager,
                                      cast(u32) mesh.all_vertices_bytes,
                                      .PER_SCENE,
                                      .DEFAULT,
                                      .READ_ONLY,
                                      String.join(mesh.name, " vertices",, allocator = Basic.temp));

    if mesh.all_indices_bytes {
        mesh.index_buffer = createBuffer(device,
                                         resource_manager,
                                         cast(u32) mesh.all_indices_bytes,
                                         .PER_SCENE,
                                         .DEFAULT,
                                         .READ_ONLY,
                                         String.join(mesh.name, " indices",, allocator = Basic.temp));
    }

    return mesh;
}
