AssetManager :: struct {
    BufferCopy :: struct {
        buffer        : *Buffer;
        regions_count : u8;
        regions       : [32] CopyRegion;
    }

    // @TODO: #TextureLoader. Add space for array layers
    TextureCopy :: struct {
        texture       : *Texture;
        regions_count : u8;
        regions       : [Texture.MAX_MIPS_SUPPORTED * 6] BufferToTextureCopyRegion;
    }

    buffer_copies_count  : u16;
    texture_copies_count : u16;

    buffer_copies  : [1024] BufferCopy;
    texture_copies : [1024] TextureCopy;
}
#assert maxOf(type_of(AssetManager.buffer_copies_count)) >= AssetManager.buffer_copies.count;
#assert maxOf(type_of(AssetManager.texture_copies_count)) >= AssetManager.texture_copies.count;

MeshAsset :: struct {
    #as using mesh : Mesh;
    using _        : Asset;
}

ModelAsset :: struct {
    #as using model : Model;
    using _         : Asset;
}

TextureAsset :: struct {
    #as using texture : *Texture;
    using _ : Asset;
}

Asset :: struct {
    ready_event        : GPUEvent;
    cached_ready_state : bool;
}

createAssetManager :: () {
    manager := pushToArena(*context.pet.arenas.persistent, AssetManager);
    context.pet.render.asset_manager = manager;
}

processAssetManagerCopies :: () {
    assertThreadKind(.MAIN);
    assert(resourceMemoryCommitted(.PERSISTENT));
    assert(resourceMemoryCommitted(.PER_SCENE));

    manager := context.pet.render.asset_manager;
    gurb    := context.pet.render.global_upload_ring_buffer;

    for manager.buffer_copies {
        if !it.buffer continue; // We might not have materials, for example.
        copyBufferRegions(*gurb.command_buffer, it.buffer, gurb.buffer, .{ it.regions_count, it.regions.data });
    }

    for manager.texture_copies {
        copyBufferToTexture(*gurb.command_buffer, it.texture, gurb.buffer, .{ it.regions_count, it.regions.data });
    }

    memset(manager.buffer_copies.data, 0, manager.buffer_copies_count * size_of(AssetManager.BufferCopy));
    memset(manager.texture_copies.data, 0, manager.texture_copies_count * size_of(AssetManager.TextureCopy));

    manager.buffer_copies_count  = 0;
    manager.texture_copies_count = 0;
}

// @TODO: If I never call isAssetReady during `Device.frame_buffering` frames after request the state of `ready_event` will become invalid.
// Create GPUEvent for each asset inidividually and submit them in `processAssetManagerCopies`
isAssetReady :: (asset : *$T/interface Asset) -> bool {
    if  asset.cached_ready_state return true;
    if !asset.ready_event.handle return false;

    if isGPUEventSet(asset.ready_event) {
        asset.cached_ready_state = true;
        asset.ready_event = .{}; // unlink UploadRingBuffer event from asset
    }

    return asset.cached_ready_state;
}

requestMesh :: (name : string) -> MeshAsset {
    assert(resourceMemoryCommitted(.PERSISTENT));
    assert(!resourceMemoryCommitted(.PER_SCENE));

    file, file_error := openFile(makeRuntimeMeshFilename(name), .READ | .SHARED_READ | .EXISTS | .SEQ);
    assert(file_error == .NONE);
    defer closeFile(*file);

    header : MeshFile.Header = ---;
    readFile(file, *header);
    assert(header.version == MeshFile.VERSION);

    gurb := context.pet.render.global_upload_ring_buffer;

    asset : MeshAsset;
    asset.vertex_format   = header.vertex_format;
    asset.submeshes_count = header.submeshes_count;
    asset.ready_event     = gurb.done_events[context.pet.render.device.frame_index];

    //
    // Fill submesh infos, calculate total vertices and indices size in bytes
    //

    vertex_stride := cast(u32) getVertexStride(asset.vertex_format);
    INDEX_STRIDE  :: size_of(u32);

    total_vertices_count : u32;
    total_indices_count  : u32;

    submesh_infos_it := asset.submesh_infos.data;
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

    assertAligned(total_vertices_bytes, 16);
    assertAligned(total_indices_bytes, 4);

    //
    // Create buffers
    //

    assert(total_vertices_bytes);
    {
        vertex_buffer_name := String.join(name, " vertices",, allocator = Basic.temp);
        asset.vertex_buffer = createBuffer(total_vertices_bytes, .PER_SCENE, .DEFAULT, .READ_ONLY, vertex_buffer_name);
    }

    if total_indices_bytes {
        index_buffer_name := String.join(name, " indices",, allocator = Basic.temp);
        asset.index_buffer = createBuffer(total_indices_bytes, .PER_SCENE, .DEFAULT, .READ_ONLY, index_buffer_name);
    }

    //
    // Read data to upload buffer
    //

    total_bytes   := total_vertices_bytes + total_indices_bytes;
    upload_offset := acquireGlobalUploadRingBufferMemory(total_bytes, 16);

    vertex_offset : u32;
    index_offset  : u32;

    manager := context.pet.render.asset_manager;

    assert(manager.buffer_copies_count + 2 <= AssetManager.buffer_copies.count);
    vb_copy := *manager.buffer_copies[manager.buffer_copies_count + 0];
    ib_copy := *manager.buffer_copies[manager.buffer_copies_count + 1];
    manager.buffer_copies_count += 2;

    vb_copy.buffer = asset.vertex_buffer;
    ib_copy.buffer = asset.index_buffer;

    for toView(asset.submesh_infos.data, asset.submeshes_count) {
        assert(getFileCursorPosition(file) == cast(s64) header.submesh_infos[it_index].offset);

        remaining_vertices_bytes := it.vertices_count * vertex_stride;
        while remaining_vertices_bytes {
            chunk_bytes := min(remaining_vertices_bytes, gurb.buffer.size - upload_offset);

            destination := gurb.buffer.mapped_memory + upload_offset;
            readFile(file, destination, chunk_bytes);

            assert(vb_copy.regions_count < AssetManager.BufferCopy.regions.count);
            region := *vb_copy.regions[vb_copy.regions_count];
            vb_copy.regions_count += 1;

            region.dest_offset   = vertex_offset;
            region.source_offset = upload_offset;
            region.bytes         = chunk_bytes;

            upload_offset             = (upload_offset + chunk_bytes) & (gurb.buffer.size - 1);
            vertex_offset            += chunk_bytes;
            remaining_vertices_bytes -= chunk_bytes;
        }

        remaining_indices_bytes := it.indices_count * INDEX_STRIDE;
        while remaining_indices_bytes {
            chunk_bytes := min(remaining_indices_bytes, gurb.buffer.size - upload_offset);

            destination := gurb.buffer.mapped_memory + upload_offset;
            readFile(file, destination, chunk_bytes);

            assert(ib_copy.regions_count < AssetManager.BufferCopy.regions.count);
            region := *ib_copy.regions[ib_copy.regions_count];
            ib_copy.regions_count += 1;

            region.dest_offset   = index_offset;
            region.source_offset = upload_offset;
            region.bytes         = chunk_bytes;

            upload_offset            = (upload_offset + chunk_bytes) & (gurb.buffer.size - 1);
            index_offset            += chunk_bytes;
            remaining_indices_bytes -= chunk_bytes;
        }
    }

    return asset;
}

//
// @Continue: #GLTF. Rewrite functions below in a similar manner as `requestMesh`
//

// @TODO: #GLTF. Load textures
requestModel :: (name : string) -> ModelAsset {
    assert(resourceMemoryCommitted(.PERSISTENT));
    assert(!resourceMemoryCommitted(.PER_SCENE));

    file, file_error := openFile(makeRuntimeModelFilename(name), .READ | .SHARED_READ | .EXISTS | .SEQ);
    assert(file_error == .NONE);
    defer closeFile(*file);

    header : ModelFile.Header = ---;
    readFile(file, *header);
    assert(header.version == ModelFile.VERSION);

    gurb := context.pet.render.global_upload_ring_buffer;

    asset : ModelAsset;
    asset.vertex_format = header.vertex_format;
    asset.ready_event   = gurb.done_events[context.pet.render.device.frame_index];

    if header.textures_count {
        asset.textures.count = header.textures_count;
        asset.textures.data  = Basic.alloc(size_of(Texture) * header.textures_count);

        for * asset.textures {
            texture_name : ModelFile.TextureName = ---;
            readFile(file, *texture_name);

            name : string = ---;
            name.count = texture_name.length;
            name.data  = pushToArena(*context.pet.arenas.per_frame, texture_name.length);
            readFile(file, name);

            it.* = loadTexture(name);
        }
    }

    gpu_materials : [] Model.GPUMaterial;
    if header.materials_count {
        gpu_materials.count = header.materials_count;
        gpu_materials.data  = pushToArena(*context.pet.arenas.per_frame, Model.GPUMaterial, header.materials_count);

        for * gpu_materials {
            material : ModelFile.Material = ---;
            readFile(file, *material);
            it.m = material;
        }
    }

    gpu_meshes : [] Model.GPUMesh = ---;
    assert(header.meshes_count);
    {
        asset.meshes.count = header.meshes_count;
        gpu_meshes.count   = header.meshes_count;

        asset.meshes.data = Basic.alloc(size_of(Model.CPUMesh) * header.meshes_count);
        gpu_meshes.data   = pushToArena(*context.pet.arenas.per_frame, Model.GPUMesh, header.meshes_count);

        for * gpu_meshes {
            mesh : ModelFile.Mesh = ---;
            readFile(file, *mesh);

            asset.meshes[it_index].indices_start = mesh.indices_start;
            asset.meshes[it_index].indices_count = mesh.indices_count;

            it.model_to_mesh  = mesh.model_to_mesh;
            it.mesh_to_model  = mesh.mesh_to_model;
            it.material_index = mesh.material_index;
        }
    }

    vertex_stride := getVertexStride(asset.vertex_format);
    INDEX_STRIDE  :: size_of(u32);

    vertices_bytes := cast(u32, header.vertices_count * vertex_stride);
    assert(vertices_bytes);
    assertAligned(vertices_bytes, 16);

    indices_bytes := cast(u32, header.indices_count * INDEX_STRIDE);
    assert(indices_bytes, "Our models always have indices");
    assertAligned(indices_bytes, 4);

    materials_bytes := cast(u32, gpu_materials.count * size_of(Model.GPUMaterial));
    assertAligned(materials_bytes, 4);

    meshes_bytes := cast(u32, gpu_meshes.count * size_of(Model.GPUMesh));
    assert(meshes_bytes);
    assertAligned(meshes_bytes, 4);

    //
    // Create buffers
    //

    vertex_buffer_name   := String.join(name, " vertices",,  allocator = Basic.temp);
    index_buffer_name    := String.join(name, " indices",,   allocator = Basic.temp);
    material_buffer_name := String.join(name, " materials",, allocator = Basic.temp);
    mesh_buffer_name     := String.join(name, " meshes",,    allocator = Basic.temp);

    asset.vertex_buffer = createBuffer(vertices_bytes, .PER_SCENE, .DEFAULT, .READ_ONLY, vertex_buffer_name);
    asset.index_buffer  = createBuffer(indices_bytes,  .PER_SCENE, .DEFAULT, .READ_ONLY, index_buffer_name);
    if materials_bytes {
        asset.material_buffer = createBuffer(materials_bytes, .PER_SCENE, .DEFAULT, .READ_ONLY, material_buffer_name);
    }
    asset.mesh_buffer   = createBuffer(meshes_bytes,   .PER_SCENE, .DEFAULT, .READ_ONLY, mesh_buffer_name);

    //
    // Read data to upload buffer
    //

    total_bytes   := vertices_bytes + indices_bytes + materials_bytes + meshes_bytes;
    upload_offset := acquireGlobalUploadRingBufferMemory(total_bytes, 16);

    manager := context.pet.render.asset_manager;

    assert(manager.buffer_copies_count + 4 <= AssetManager.buffer_copies.count);
    vertex_buffer_copy   := *manager.buffer_copies[manager.buffer_copies_count + 0];
    index_buffer_copy    := *manager.buffer_copies[manager.buffer_copies_count + 1];
    material_buffer_copy := *manager.buffer_copies[manager.buffer_copies_count + 2];
    mesh_buffer_copy     := *manager.buffer_copies[manager.buffer_copies_count + 3];
    manager.buffer_copies_count += 4;

    vertex_buffer_copy.buffer = asset.vertex_buffer;
    index_buffer_copy.buffer  = asset.index_buffer;
    if materials_bytes {
        material_buffer_copy.buffer = asset.material_buffer;
    }
    mesh_buffer_copy.buffer   = asset.mesh_buffer;

    vertex_offset            : u32;
    remaining_vertices_bytes := vertices_bytes;
    while remaining_vertices_bytes {
        chunk_bytes := min(remaining_vertices_bytes, gurb.buffer.size - upload_offset);

        destination := gurb.buffer.mapped_memory + upload_offset;
        readFile(file, destination, chunk_bytes);

        assert(vertex_buffer_copy.regions_count < AssetManager.BufferCopy.regions.count);
        region := *vertex_buffer_copy.regions[vertex_buffer_copy.regions_count];
        vertex_buffer_copy.regions_count += 1;

        region.dest_offset   = vertex_offset;
        region.source_offset = upload_offset;
        region.bytes         = chunk_bytes;

        upload_offset             = (upload_offset + chunk_bytes) & (gurb.buffer.size - 1);
        vertex_offset            += chunk_bytes;
        remaining_vertices_bytes -= chunk_bytes;
    }

    assertAligned(upload_offset, 4);
    index_offset            : u32;
    remaining_indices_bytes := indices_bytes;
    while remaining_indices_bytes {
        chunk_bytes := min(remaining_indices_bytes, gurb.buffer.size - upload_offset);

        destination := gurb.buffer.mapped_memory + upload_offset;
        readFile(file, destination, chunk_bytes);

        assert(index_buffer_copy.regions_count < AssetManager.BufferCopy.regions.count);
        region := *index_buffer_copy.regions[index_buffer_copy.regions_count];
        index_buffer_copy.regions_count += 1;

        region.dest_offset   = index_offset;
        region.source_offset = upload_offset;
        region.bytes         = chunk_bytes;

        upload_offset            = (upload_offset + chunk_bytes) & (gurb.buffer.size - 1);
        index_offset            += chunk_bytes;
        remaining_indices_bytes -= chunk_bytes;
    }

    assertAligned(upload_offset, 4);
    material_offset : u32;
    remaining_materials_bytes := materials_bytes;
    while remaining_materials_bytes {
        chunk_bytes := min(remaining_materials_bytes, gurb.buffer.size - upload_offset);

        destination := gurb.buffer.mapped_memory + upload_offset;
        memcpy(destination, cast(*void, gpu_materials.data) + material_offset, chunk_bytes);

        assert(material_buffer_copy.regions_count < AssetManager.BufferCopy.regions.count);
        region := *material_buffer_copy.regions[material_buffer_copy.regions_count];
        material_buffer_copy.regions_count += 1;

        region.dest_offset   = material_offset;
        region.source_offset = upload_offset;
        region.bytes         = chunk_bytes;

        upload_offset              = (upload_offset + chunk_bytes) & (gurb.buffer.size - 1);
        material_offset           += chunk_bytes;
        remaining_materials_bytes -= chunk_bytes;
    }

    assertAligned(upload_offset, 4);
    mesh_offset : u32;
    remaining_meshes_bytes := meshes_bytes;
    while remaining_meshes_bytes {
        chunk_bytes := min(remaining_meshes_bytes, gurb.buffer.size - upload_offset);

        destination := gurb.buffer.mapped_memory + upload_offset;
        memcpy(destination, cast(*void, gpu_meshes.data) + mesh_offset, chunk_bytes);

        assert(mesh_buffer_copy.regions_count < AssetManager.BufferCopy.regions.count);
        region := *mesh_buffer_copy.regions[mesh_buffer_copy.regions_count];
        mesh_buffer_copy.regions_count += 1;

        region.dest_offset   = mesh_offset;
        region.source_offset = upload_offset;
        region.bytes         = chunk_bytes;

        upload_offset           = (upload_offset + chunk_bytes) & (gurb.buffer.size - 1);
        mesh_offset            += chunk_bytes;
        remaining_meshes_bytes -= chunk_bytes;
    }

    return asset;
}

requestTexture :: (name : string) -> TextureAsset {
    assert(resourceMemoryCommitted(.PERSISTENT));
    assert(!resourceMemoryCommitted(.PER_SCENE));

    asset : TextureAsset;
    asset.texture     = loadTexture(name);
    asset.ready_event = context.pet.render.global_upload_ring_buffer.done_events[context.pet.render.device.frame_index];

    return asset;
}

#scope_file

loadTexture :: (name : string) -> *Texture {
    autoResetPerFrameArenas();

    file, file_error := openFile(makeRuntimeTextureFilename(name), .READ | .SHARED_READ | .EXISTS | .SEQ);
    assert(file_error == .NONE);
    defer closeFile(*file);

    header : TextureFile.Header = ---;
    readFile(file, *header);
    assert(header.version == MeshFile.VERSION);

    //
    // Read surface offsets
    //

    faces_count := cast(u8) ifx header.flags & .CUBE then 6 else 1;
    array_size  := ifx header.flags & .ARRAY then header.array_size else 1;

    surfaces_count := header.mips_count * array_size * faces_count;
    assert(surfaces_count > 0);

    surface_offsets : [] u64;
    if surfaces_count > 1 {
        surface_offsets.count = surfaces_count - 1;
        surface_offsets.data  = pushToArena(*context.pet.arenas.per_frame, u64, surface_offsets.count);
        readFile(file, surface_offsets);
    }

    //
    // Create texture
    //

    texture := createTexture(header.format,
                             header.width,
                             header.height,
                             header.depth,
                             mips_count = header.mips_count,
                             header.flags,
                             usages = .SHADER_READ,
                             .PER_SCENE,
                             name);

    //
    // Read texture to upload buffer
    //

    texture_offset := cast(u64) (size_of(TextureFile.Header) + surface_offsets.count * size_of(u64));
    assert(cast(s64) texture_offset == getFileCursorPosition(file));

    file_size := cast(u64) getFileSize(file);

    next_surface_offset_index := 0;

    this_surface_offset := texture_offset;
    next_surface_offset := ifx surface_offsets.count > 0 then surface_offsets[next_surface_offset_index] else file_size;

    manager := context.pet.render.asset_manager;
    gurb    := context.pet.render.global_upload_ring_buffer;

    assert(manager.texture_copies_count + 1 <= AssetManager.texture_copies.count);
    texture_copy := *manager.texture_copies[manager.texture_copies_count];
    manager.texture_copies_count += 1;

    texture_copy.texture = texture;

    for face : 0 .. faces_count - 1 {
        for layer : 0 .. array_size - 1 {
            for mip : 0 .. header.mips_count - 1 {
                this_surface_size := next_surface_offset - this_surface_offset;

                // 16:    BC7 block size. @TODO: #TextureLoader. Align to the actual block size.
                // false: there is no way to copy a surface which is splitted in half
                upload_offset := acquireGlobalUploadRingBufferMemory(this_surface_size, 16, false);

                destination := gurb.buffer.mapped_memory + upload_offset;
                readFile(file, destination, cast(s64) this_surface_size);

                assert(texture_copy.regions_count < AssetManager.TextureCopy.regions.count);
                region := *texture_copy.regions[texture_copy.regions_count];
                texture_copy.regions_count += 1;

                region.buffer_offset       = upload_offset;
                region.texture_array_layer = layer;
                region.texture_face        = face;
                region.texture_mip         = mip;

                this_surface_offset = next_surface_offset;

                next_surface_offset_index += 1;
                if next_surface_offset_index < surface_offsets.count {
                    next_surface_offset = surface_offsets[next_surface_offset_index];
                } else {
                    next_surface_offset = file_size;
                }
            }
        }
    }

    return texture;
}
