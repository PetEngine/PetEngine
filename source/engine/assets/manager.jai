AssetManager :: struct {
    UploadRingBuffer :: struct {
        buffer      : *Buffer;
        read_index  : u64;
        write_index : u64;
    }

    command_buffer : CommandBuffer(.GRAPHICS);
    upload_buffer  : UploadRingBuffer;

    mesh_assets : StaticArray(MeshAsset, 1024);
}

MeshAsset :: struct {
    #as using mesh : Mesh;

    upload_buffer_offset : u32;

    ready_event : *void;
    is_ready    : bool;

    name : string;
}

createAssetManager :: () {
    manager := pushToArena(*context.pet.arenas.persistent, AssetManager);
    context.pet.render.asset_manager = manager;

    manager.command_buffer = createCommandBuffer(AssetManager.command_buffer.usage);

    // @TODO: #Settings.
    BUFFER_CAPACITY :: #run megaBytes(512);
    #assert isPowerOfTwo(BUFFER_CAPACITY);

    manager.upload_buffer.buffer = createBuffer(BUFFER_CAPACITY,
                                                .PERSISTENT,
                                                .UPLOAD,
                                                .NONE,
                                                "AssetManager upload ring buffer",
                                                AssetManager.command_buffer.usage);
}

resetAssetManager :: () {
    assertThreadKind(.MAIN);
    resetCommandBuffer(*context.pet.render.asset_manager.command_buffer);
}

resetAssetManagerAssets :: () {
    assertThreadKind(.MAIN);

    if #complete context.pet.render.device.graphics_api == {
        case .VULKAN;
            vulkan_device := cast(*VulkanDevice) context.pet.render.device;

            for context.pet.render.asset_manager.mesh_assets {
                if it.ready_event {
                    vkDestroyEvent(vulkan_device.device, cast(VkEvent) it.ready_event, null);
                }
            }
    }

    reset(*context.pet.render.asset_manager.mesh_assets);
}

processRequestedAssets :: () {
    assertThreadKind(.MAIN);
    assert(resourceMemoryCommitted(.PERSISTENT));
    assert(resourceMemoryCommitted(.PER_SCENE));

    manager := context.pet.render.asset_manager;

    for mesh_asset : manager.mesh_assets {
        autoResetPerFrameArenas();

        file_data, error := readEntireFile(makeRuntimeMeshFilename(mesh_asset.name), pushToArena, *context.pet.arenas.per_frame);
        assert(error == .NONE);

        header := MeshFile.getHeader(file_data);
        assert(header.version == MeshFile.VERSION);

        stream := file_data;
        advance(*stream, size_of(MeshFile.Header));

        vertex_stride           := cast(u32) getVertexStride(mesh_asset.vertex_format);
        upload_buffer_size_mask := manager.upload_buffer.buffer.size - 1;

        upload_offset := mesh_asset.upload_buffer_offset;
        vertex_offset : u32;
        index_offset  : u32;

        // +1 because only one submesh may cycle (have 2 copy regions), otherwise we overflow upload buffer
        vertex_buffer_regions : StaticArray(CopyRegion, Mesh.MAX_SUBMESHES + 1);
        index_buffer_regions  : StaticArray(CopyRegion, Mesh.MAX_SUBMESHES + 1);

        for toView(mesh_asset.submesh_infos.data, mesh_asset.submeshes_count) {
            assert(cast(u64) (stream.data - file_data.data) == header.submesh_infos[it_index].offset);

            remaining_vertices_bytes := it.vertices_count * vertex_stride;
            while remaining_vertices_bytes {
                chunk_bytes := min(remaining_vertices_bytes, manager.upload_buffer.buffer.size - upload_offset);

                memcpy(manager.upload_buffer.buffer.mapped_memory + upload_offset, stream.data, chunk_bytes);

                region := pushBack(*vertex_buffer_regions);
                region.dest_offset   = vertex_offset;
                region.source_offset = upload_offset;
                region.bytes         = chunk_bytes;

                // We cannot read or write to read_index during processRequestedAssets, so there is no sense for atomic increment
                manager.upload_buffer.read_index += chunk_bytes;

                advance(*stream, chunk_bytes);
                upload_offset             = (upload_offset + chunk_bytes) & upload_buffer_size_mask;
                vertex_offset            += chunk_bytes;
                remaining_vertices_bytes -= chunk_bytes;
            }

            remaining_indices_bytes := it.indices_count * size_of(u32);
            while remaining_indices_bytes {
                chunk_bytes := min(remaining_indices_bytes, manager.upload_buffer.buffer.size - upload_offset);

                memcpy(manager.upload_buffer.buffer.mapped_memory + upload_offset, stream.data, chunk_bytes);

                region := pushBack(*index_buffer_regions);
                region.dest_offset   = index_offset;
                region.source_offset = upload_offset;
                region.bytes         = chunk_bytes;

                // We cannot read or write to read_index during processRequestedAssets, so there is no sense for atomic increment
                manager.upload_buffer.read_index += chunk_bytes;

                advance(*stream, chunk_bytes);
                upload_offset            = (upload_offset + chunk_bytes) & upload_buffer_size_mask;
                index_offset            += chunk_bytes;
                remaining_indices_bytes -= chunk_bytes;
            }
        }

        copyBufferRegions(*manager.command_buffer, mesh_asset.vertex_buffer, manager.upload_buffer.buffer, toView(vertex_buffer_regions));
        copyBufferRegions(*manager.command_buffer, mesh_asset.index_buffer,  manager.upload_buffer.buffer, toView(index_buffer_regions));

        if #complete context.pet.render.device.graphics_api == {
            case .VULKAN;
                vk_command_buffer := manager.command_buffer.handles[context.pet.render.device.frame_index];
                vkCmdSetEvent(vk_command_buffer, cast(VkEvent) mesh_asset.ready_event, .VK_PIPELINE_STAGE_TRANSFER_BIT);
        }
    }
}

requestMesh :: (name : string) -> *Mesh {
    assert(!resourceMemoryCommitted(.PER_SCENE));

    header : MeshFile.Header = ---;
    {
        file, error := openFile(makeRuntimeMeshFilename(name), .READ | .SHARED_READ | .EXISTS);
        assert(error == .NONE);
        defer closeFile(*file);

        readFile(file, *header);
        assert(header.version == MeshFile.VERSION);
    }

    manager := context.pet.render.asset_manager;

    mesh := pushBack(*manager.mesh_assets);
    mesh.vertex_format   = header.vertex_format;
    mesh.submeshes_count = header.submeshes_count;
    mesh.name            = name;

    //
    // Calculate vertices and indices total size, fill submesh infos
    //

    vertex_stride := cast(u32) getVertexStride(mesh.vertex_format);

    all_vertices_bytes : u32;
    all_indices_bytes  : u32;

    submesh_infos_it := mesh.submesh_infos.data;
    for toView(header.submesh_infos.data, header.submeshes_count) {
        submesh_infos_it.vertices_skip  = all_vertices_bytes;
        submesh_infos_it.vertices_count = it.vertices_count;
        submesh_infos_it.indices_skip   = all_indices_bytes;
        submesh_infos_it.indices_count  = it.indices_count;

        all_vertices_bytes += it.vertices_count;
        all_indices_bytes  += it.indices_count;

        submesh_infos_it += 1;
    }

    all_vertices_bytes *= vertex_stride;
    all_indices_bytes  *= size_of(u32);

    //
    // Calculate offsets in upload buffer
    //

    {
        // @Cleanup: #Atomics.
        atomicCompareAndSwap :: inline (mem : *$T, old : T, new : T) -> T {
            #assert size_of(T) == 1 || size_of(T) == 2 || size_of(T) == 4 || size_of(T) == 8;

            #if CPU == .X64 #asm {
                old === a;
                lock_cmpxchg?T old, [mem], new;
            } else {
                notImplemented();
            }

            return old;
        }

        all_bytes : u64 = all_vertices_bytes + all_indices_bytes;

        old_index := manager.upload_buffer.write_index;
        new_index := old_index + all_bytes;
        while atomicCompareAndSwap(*manager.upload_buffer.write_index, old_index, new_index) != old_index {
            old_index = manager.upload_buffer.write_index;
            new_index = old_index + all_bytes;
        }

        assert(new_index - manager.upload_buffer.read_index <= manager.upload_buffer.buffer.size, "Upload ring buffer overflow");

        mesh.upload_buffer_offset = cast(u32) (old_index & (manager.upload_buffer.buffer.size - 1));
    }

    //
    // Create buffers
    //

    assert(all_vertices_bytes);
    mesh.vertex_buffer = createBuffer(all_vertices_bytes,
                                      .PER_SCENE,
                                      .DEFAULT,
                                      .READ_ONLY,
                                      String.join(mesh.name, " vertices",, allocator = Basic.temp));

    if all_indices_bytes {
        mesh.index_buffer = createBuffer(all_indices_bytes,
                                         .PER_SCENE,
                                         .DEFAULT,
                                         .READ_ONLY,
                                         String.join(mesh.name, " indices",, allocator = Basic.temp));
    }

    //
    // Create event
    //

    if #complete context.pet.render.device.graphics_api == {
        case .VULKAN;
            vulkan_device := cast(*VulkanDevice) context.pet.render.device;

            create_info : VkEventCreateInfo;
            debugCheckVK(vkCreateEvent(vulkan_device.device, *create_info, null, cast(*VkEvent) *mesh.ready_event));
            setVulkanObjectName(cast(VkEvent) mesh.ready_event, "% mesh ready event", mesh.name);
    }

    return mesh;
}

isMeshReady :: (mesh : *Mesh) -> bool {
    if !mesh return false;

    mesh_asset := cast(*MeshAsset) mesh;
    if mesh_asset.is_ready return true;

    if #complete context.pet.render.device.graphics_api == {
        case .VULKAN;
            vulkan_device := cast(*VulkanDevice) context.pet.render.device;

            result := vkGetEventStatus(vulkan_device.device, cast(VkEvent) mesh_asset.ready_event);
            assert(result == .VK_EVENT_SET || result == .VK_EVENT_RESET, "vkGetEventStatus returned %", result);

            mesh_asset.is_ready = result == .VK_EVENT_SET;
    }

    return mesh_asset.is_ready;
}
