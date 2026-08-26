Model :: struct {
    CPUMesh :: struct {
        indices_start : u32;
        indices_count : u32;
    }

    GPUMesh :: struct {
        model_to_mesh  : m3x4;
        mesh_to_model  : m3x4;
        material_index : u16;
    }

    GPUMaterial :: struct {
        using m : ModelFile.Material;
    }

    textures : [] *Texture;
    meshes   : [] CPUMesh;

    vertices_offset  : u32 : 0;
    indices_offset   : u32;
    materials_offset : u32;
    meshes_offset    : u32;

    buffer : *Buffer;

    allocator     : Allocator;
    vertex_format : VertexFormat;
}

#assert size_of(Model.GPUMesh) & 3 == 0;
#assert size_of(Model.GPUMaterial) & 3 == 0;

destroyModel :: (model : *Model) {
    assert(model.allocator.proc || (!model.textures.data && !model.meshes.data));

    if model.textures.data {
        Basic.free(model.textures.data,, allocator = model.allocator);
        model.textures.data = null;
    }

    if model.meshes.data {
        Basic.free(model.meshes.data,, allocator = model.allocator);
        model.meshes.data = null;
    }

    model.* = .{};
}
