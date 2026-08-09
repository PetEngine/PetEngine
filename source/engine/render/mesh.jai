// @Cleanup: #GLTF. Replace with ModelMesh?
Mesh :: struct {
    MAX_SUBMESHES :: 16;

    SubmeshInfo :: struct {
        vertices_skip  : u32;
        vertices_count : u32;
        indices_skip   : u32;
        indices_count  : u32;
    }

    vertex_format   : VertexFormat;
    submeshes_count : u8;

    submesh_infos : [MAX_SUBMESHES] SubmeshInfo;

    vertex_buffer : *Buffer;
    index_buffer  : *Buffer;
}

Model :: struct {
    vertex_buffer : *Buffer;
    index_buffer  : *Buffer;

    materials : [] Material;
    meshes    : [] ModelMesh;

    // allocator : Allocator; // @TODO: Define MAXes?
}

Material :: struct {
    texture_albedo             : *Texture;
    texture_normal             : *Texture;
    texture_metallic_roughness : *Texture;
    texture_emissive           : *Texture;
    texture_occlusion          : *Texture;

    factor_albedo    : v4f;
    factor_metallic  : f32;
    factor_roughness : f32;
}

ModelMesh :: struct {
    material_index : s64;
    indices_start  : s64;
    indices_count  : s64;
    mesh_to_model  : m3x4;
    model_to_mesh  : m3x4;
}
