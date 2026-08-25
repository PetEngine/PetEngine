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

    // @TODO: #GLTF. Store allocator for them?
    textures : [] *Texture;
    meshes   : [] CPUMesh;

    // @TODO: #GLTF. Make it 1 buffer
    vertex_buffer   : *Buffer;
    index_buffer    : *Buffer;
    material_buffer : *Buffer;
    mesh_buffer     : *Buffer;

    vertex_format : VertexFormat;
}

#assert size_of(Model.GPUMesh) & 3 == 0;
#assert size_of(Model.GPUMaterial) & 3 == 0;
