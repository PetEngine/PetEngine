Model :: struct {
    Material :: struct {
        using m : ModelFile.Material;
    }

    Mesh :: struct {
        using m : ModelFile.Mesh;
    }

    PushConstants :: struct {
        index_buffer_reference    : u64;
        vertex_buffer_reference   : u64;
        mesh_buffer_reference     : u64;
        material_buffer_reference : u64;
        model_to_world            : m3x4;
        world_to_model            : m3x4;
        per_view_uniform_index    : u32;
        sampler_index             : u16;
        first_texture_index       : u16;
    }

    textures  : [] *Texture;
    materials : [] Material;
    meshes    : [] Mesh;

    vertices_offset  : u32 : 0;
    indices_offset   : u32;
    materials_offset : u32;
    meshes_offset    : u32;

    model_to_world : m3x4 = IDENTITY_3X4;
    world_to_model : m3x4 = IDENTITY_3X4;

    buffer : *Buffer;

    allocator     : Allocator;
    vertex_format : VertexFormat;
}

#assert size_of(Model.Material) & 3 == 0;
#assert size_of(Model.Mesh) & 3 == 0;

destroyModel :: (model : *Model) {
    assert(model.allocator.proc || (!model.textures.data && !model.meshes.data && !model.materials.data));

    if model.textures.data  then Basic.free(model.textures.data,,  allocator = model.allocator);
    if model.materials.data then Basic.free(model.materials.data,, allocator = model.allocator);
    if model.meshes.data    then Basic.free(model.meshes.data,,    allocator = model.allocator);

    model.* = .{};
}
