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
