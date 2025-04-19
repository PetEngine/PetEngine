AssetManager :: struct {
    UploadRingBuffer :: struct {
        buffer       : *Buffer;
        read_offset  : u64;
        write_offset : u64;
    }

    command_buffer : CommandBuffer(.GRAPHICS);
    upload_buffer  : UploadRingBuffer;

    mesh_assets : StaticArray(MeshAsset, 1024);
}

MeshAsset :: struct {
    #as using mesh : Mesh;

    ready_event : *void;
    is_ready    : bool;

    vertex_buffer_regions_count : u32;
    index_buffer_regions_count  : u32;

    // +1 because only one submesh may cycle (have 2 copy regions), otherwise we overflow upload buffer
    vertex_buffer_regions : [Mesh.MAX_SUBMESHES + 1] CopyRegion;
    index_buffer_regions  : [Mesh.MAX_SUBMESHES + 1] CopyRegion;
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

    device  := context.pet.render.device;
    manager := context.pet.render.asset_manager;

    for manager.mesh_assets {
        vertex_buffer_regions_view := toView(it.vertex_buffer_regions.data, it.vertex_buffer_regions_count);
        index_buffer_regions_view  := toView(it.index_buffer_regions.data, it.index_buffer_regions_count);

        copyBufferRegions(*manager.command_buffer, it.vertex_buffer, manager.upload_buffer.buffer, vertex_buffer_regions_view);
        copyBufferRegions(*manager.command_buffer, it.index_buffer,  manager.upload_buffer.buffer, index_buffer_regions_view);

        if #complete device.graphics_api == {
            case .VULKAN;
                vk_command_buffer := manager.command_buffer.handles[device.frame_index];
                vkCmdSetEvent(vk_command_buffer, cast(VkEvent) it.ready_event, .VK_PIPELINE_STAGE_TRANSFER_BIT);
        }
    }
}

requestMesh :: (name : string) -> *Mesh {
    assert(!resourceMemoryCommitted(.PER_SCENE));

    file, file_error := openFile(makeRuntimeMeshFilename(name), .READ | .SHARED_READ | .EXISTS | .SEQ);
    assert(file_error == .NONE);
    defer closeFile(*file);

    header : MeshFile.Header = ---;
    readFile(file, *header);
    assert(header.version == MeshFile.VERSION);

    manager := context.pet.render.asset_manager;

    mesh := pushBack(*manager.mesh_assets);
    mesh.vertex_format   = header.vertex_format;
    mesh.submeshes_count = header.submeshes_count;

    //
    // Fill submesh infos, calculate total vertices and indices size in bytes
    //

    vertex_stride := cast(u32) getVertexStride(mesh.vertex_format);
    INDEX_STRIDE  :: size_of(u32);

    total_vertices_count : u32;
    total_indices_count  : u32;

    submesh_infos_it := mesh.submesh_infos.data;
    for toView(header.submesh_infos.data, header.submeshes_count) {
        submesh_infos_it.vertices_skip  = total_vertices_count;
        submesh_infos_it.vertices_count = it.vertices_count;
        submesh_infos_it.indices_skip   = total_indices_count;
        submesh_infos_it.indices_count  = it.indices_count;

        total_vertices_count += it.vertices_count;
        total_indices_count  += it.indices_count;

        submesh_infos_it += 1;
    }

    total_vertices_bytes := total_vertices_count * vertex_stride;
    total_indices_bytes  := total_indices_count  * INDEX_STRIDE;
    total_bytes          := total_vertices_bytes + total_indices_bytes;

    //
    // Read data to upload buffer
    //

    upload_offset := cast(u32) getUploadBufferOffset(total_bytes);
    vertex_offset : u32;
    index_offset  : u32;

    for toView(mesh.submesh_infos.data, mesh.submeshes_count) {
        assert(getFileCursorPosition(file) == cast(s64) header.submesh_infos[it_index].offset);

        remaining_vertices_bytes := it.vertices_count * vertex_stride;
        while remaining_vertices_bytes {
            chunk_bytes := min(remaining_vertices_bytes, manager.upload_buffer.buffer.size - upload_offset);

            destination := manager.upload_buffer.buffer.mapped_memory + upload_offset;
            readFile(file, destination, chunk_bytes);

            assert(mesh.vertex_buffer_regions_count < MeshAsset.vertex_buffer_regions.count);
            region := *mesh.vertex_buffer_regions[mesh.vertex_buffer_regions_count];
            mesh.vertex_buffer_regions_count += 1;

            region.dest_offset   = vertex_offset;
            region.source_offset = upload_offset;
            region.bytes         = chunk_bytes;

            upload_offset             = (upload_offset + chunk_bytes) & (manager.upload_buffer.buffer.size - 1);
            vertex_offset            += chunk_bytes;
            remaining_vertices_bytes -= chunk_bytes;
        }

        remaining_indices_bytes := it.indices_count * INDEX_STRIDE;
        while remaining_indices_bytes {
            chunk_bytes := min(remaining_indices_bytes, manager.upload_buffer.buffer.size - upload_offset);

            destination := manager.upload_buffer.buffer.mapped_memory + upload_offset;
            readFile(file, destination, chunk_bytes);

            assert(mesh.index_buffer_regions_count < MeshAsset.index_buffer_regions.count);
            region := *mesh.index_buffer_regions[mesh.index_buffer_regions_count];
            mesh.index_buffer_regions_count += 1;

            region.dest_offset   = index_offset;
            region.source_offset = upload_offset;
            region.bytes         = chunk_bytes;

            upload_offset            = (upload_offset + chunk_bytes) & (manager.upload_buffer.buffer.size - 1);
            index_offset            += chunk_bytes;
            remaining_indices_bytes -= chunk_bytes;
        }
    }

    //
    // Create buffers
    //

    assert(total_vertices_bytes);
    {
        vertex_buffer_name := String.join(name, " vertices",, allocator = Basic.temp);
        mesh.vertex_buffer = createBuffer(total_vertices_bytes, .PER_SCENE, .DEFAULT, .READ_ONLY, vertex_buffer_name);
    }

    if total_indices_bytes {
        index_buffer_name := String.join(name, " indices",, allocator = Basic.temp);
        mesh.index_buffer = createBuffer(total_indices_bytes, .PER_SCENE, .DEFAULT, .READ_ONLY, index_buffer_name);
    }

    //
    // Create event
    //

    if #complete context.pet.render.device.graphics_api == {
        case .VULKAN;
            vulkan_device := cast(*VulkanDevice) context.pet.render.device;

            create_info : VkEventCreateInfo;
            debugCheckVK(vkCreateEvent(vulkan_device.device, *create_info, null, cast(*VkEvent) *mesh.ready_event));
            setVulkanObjectName(cast(VkEvent) mesh.ready_event, "% mesh ready event", name);
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

    // @TODO: #SinglePointWait. This is incorrect if the order is not guaranteed.
    if mesh_asset.is_ready {
        manager := context.pet.render.asset_manager;

        vertex_stride := cast(u64) getVertexStride(mesh.vertex_format);
        INDEX_STRIDE  :: size_of(u32);

        total_bytes : u64;
        for toView(mesh.submesh_infos.data, mesh.submeshes_count) {
            total_bytes += it.vertices_count * vertex_stride
                        +  it.indices_count  * INDEX_STRIDE;
        }

        atomicAdd(*manager.upload_buffer.read_offset, total_bytes);
    }

    return mesh_asset.is_ready;
}

#scope_file

getUploadBufferOffset :: (data_size : u64) -> u64 {
    manager := context.pet.render.asset_manager;

    old_offset := manager.upload_buffer.write_offset;
    new_offset := old_offset + data_size;
    while atomicCompareAndSwap(*manager.upload_buffer.write_offset, old_offset, new_offset) != old_offset {
        old_offset = manager.upload_buffer.write_offset;
        new_offset = old_offset + data_size;
    }

    assert(new_offset - manager.upload_buffer.read_offset <= manager.upload_buffer.buffer.size, "Upload ring buffer overflow");

    return old_offset & (manager.upload_buffer.buffer.size - 1);
}

// @TODO: #Atomics.
atomicCompareAndSwap :: inline (mem : *$T, old : T, new : T) -> T #no_context {
    #assert size_of(T) == 1 || size_of(T) == 2 || size_of(T) == 4 || size_of(T) == 8;

    #if CPU == .X64 #asm {
        old === a;
        lock_cmpxchg?T old, [mem], new;
    } else {
        notImplemented();
    }

    return old;
}

// @TODO: #Atomics.
atomicAdd :: inline (mem : *$T, add : T) #no_context {
    #assert size_of(T) == 1 || size_of(T) == 2 || size_of(T) == 4 || size_of(T) == 8;

    #if CPU == .X64 #asm {
        lock_add?T [mem], add;
    } else {
        notImplemented();
    }
}
