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

    buffer_copies_view  := toView(manager.buffer_copies.data, manager.buffer_copies_count);
    texture_copies_view := toView(manager.texture_copies.data, manager.texture_copies_count);

    for buffer_copies_view {
        assert(it.buffer);
        copyBufferRegions(*gurb.command_buffer, it.buffer, gurb.buffer, .{ it.regions_count, it.regions.data });
    }

    for texture_copies_view {
        assert(it.texture);
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
    asset.allocator     = context.allocator;

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

    assert(header.materials_count);
    {
        asset.materials.count = header.materials_count;
        asset.materials.data  = Basic.alloc(size_of(Model.Material) * header.materials_count);

        for * asset.materials {
            tightly_packed_material : ModelFile.Material = ---;
            readFile(file, *tightly_packed_material);
            it.m = tightly_packed_material;
        }
    }

    assert(header.meshes_count);
    {
        asset.meshes.count = header.meshes_count;
        asset.meshes.data  = Basic.alloc(size_of(Model.Mesh) * header.meshes_count);

        for * asset.meshes {
            tightly_packed_mesh : ModelFile.Mesh = ---;
            readFile(file, *tightly_packed_mesh);

            it.m = tightly_packed_mesh;
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

    materials_bytes := cast(u32, header.materials_count * size_of(Model.Material));
    assert(materials_bytes, "At least 1 default material must be presented");
    assertAligned(materials_bytes, 4);

    meshes_bytes := cast(u32, header.meshes_count * size_of(Model.Mesh));
    assert(meshes_bytes);
    assertAligned(meshes_bytes, 4);

    //
    // Create buffer
    //

    asset.indices_offset   = vertices_bytes;
    asset.materials_offset = vertices_bytes + indices_bytes;
    asset.meshes_offset    = vertices_bytes + indices_bytes + materials_bytes;

    total_bytes := vertices_bytes + indices_bytes + materials_bytes + meshes_bytes;

    asset.buffer = createBuffer(total_bytes, .PER_SCENE, .DEFAULT, .READ_ONLY, name);

    //
    // Read data to upload buffer
    //

    upload_offset := acquireGlobalUploadRingBufferMemory(total_bytes, 16);

    manager := context.pet.render.asset_manager;

    assert(manager.buffer_copies_count + 1 <= AssetManager.buffer_copies.count);
    buffer_copy := *manager.buffer_copies[manager.buffer_copies_count];
    manager.buffer_copies_count += 1;

    buffer_copy.buffer = asset.buffer;

    buffer_offset : u32;

    remaining_vertices_bytes := vertices_bytes;
    while remaining_vertices_bytes {
        chunk_bytes := min(remaining_vertices_bytes, gurb.buffer.size - upload_offset);

        destination := gurb.buffer.mapped_memory + upload_offset;
        readFile(file, destination, chunk_bytes);

        assert(buffer_copy.regions_count < AssetManager.BufferCopy.regions.count);
        region := *buffer_copy.regions[buffer_copy.regions_count];
        buffer_copy.regions_count += 1;

        region.dest_offset   = buffer_offset;
        region.source_offset = upload_offset;
        region.bytes         = chunk_bytes;

        upload_offset             = (upload_offset + chunk_bytes) & (gurb.buffer.size - 1);
        buffer_offset            += chunk_bytes;
        remaining_vertices_bytes -= chunk_bytes;
    }

    assertAligned(upload_offset, 4);
    remaining_indices_bytes := indices_bytes;
    while remaining_indices_bytes {
        chunk_bytes := min(remaining_indices_bytes, gurb.buffer.size - upload_offset);

        destination := gurb.buffer.mapped_memory + upload_offset;
        readFile(file, destination, chunk_bytes);

        assert(buffer_copy.regions_count < AssetManager.BufferCopy.regions.count);
        region := *buffer_copy.regions[buffer_copy.regions_count];
        buffer_copy.regions_count += 1;

        region.dest_offset   = buffer_offset;
        region.source_offset = upload_offset;
        region.bytes         = chunk_bytes;

        upload_offset            = (upload_offset + chunk_bytes) & (gurb.buffer.size - 1);
        buffer_offset           += chunk_bytes;
        remaining_indices_bytes -= chunk_bytes;
    }

    assertAligned(upload_offset, 4);
    materials_offset : u32;
    remaining_materials_bytes := materials_bytes;
    while remaining_materials_bytes {
        chunk_bytes := min(remaining_materials_bytes, gurb.buffer.size - upload_offset);

        destination := gurb.buffer.mapped_memory + upload_offset;
        memcpy(destination, cast(*void, asset.materials.data) + materials_offset, chunk_bytes);

        assert(buffer_copy.regions_count < AssetManager.BufferCopy.regions.count);
        region := *buffer_copy.regions[buffer_copy.regions_count];
        buffer_copy.regions_count += 1;

        region.dest_offset   = buffer_offset;
        region.source_offset = upload_offset;
        region.bytes         = chunk_bytes;

        upload_offset              = (upload_offset + chunk_bytes) & (gurb.buffer.size - 1);
        buffer_offset             += chunk_bytes;
        materials_offset          += chunk_bytes;
        remaining_materials_bytes -= chunk_bytes;
    }

    assertAligned(upload_offset, 4);
    meshes_offset : u32;
    remaining_meshes_bytes := meshes_bytes;
    while remaining_meshes_bytes {
        chunk_bytes := min(remaining_meshes_bytes, gurb.buffer.size - upload_offset);

        destination := gurb.buffer.mapped_memory + upload_offset;
        memcpy(destination, cast(*void, asset.meshes.data) + meshes_offset, chunk_bytes);

        assert(buffer_copy.regions_count < AssetManager.BufferCopy.regions.count);
        region := *buffer_copy.regions[buffer_copy.regions_count];
        buffer_copy.regions_count += 1;

        region.dest_offset   = buffer_offset;
        region.source_offset = upload_offset;
        region.bytes         = chunk_bytes;

        upload_offset           = (upload_offset + chunk_bytes) & (gurb.buffer.size - 1);
        buffer_offset          += chunk_bytes;
        meshes_offset          += chunk_bytes;
        remaining_meshes_bytes -= chunk_bytes;
    }

    assert(buffer_offset == total_bytes);
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
    assert(header.version == TextureFile.VERSION);

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
