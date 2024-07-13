Mesh :: struct {
    MAX_SUBMESHES :: 16;

    SubmeshInfo :: struct {
        indices_offset  : u64;
        vertices_offset : u64;
        indices_count   : u32;
        vertices_count  : u32;
    }

    vertex_format   : VertexFormat;
    submeshes_count : u8;

    submesh_infos : [MAX_SUBMESHES] SubmeshInfo;

    vertex_buffer : *Buffer;
    index_buffer  : *Buffer;
}
