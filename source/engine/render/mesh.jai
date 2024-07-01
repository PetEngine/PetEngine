Mesh :: struct {
    MAX_SUBMESHES :: 16;

    SubmeshInfo :: struct {
        vertices_offset : u64;
        indices_offset  : u64;
    }

    vertex_format   : VertexFormat;
    submeshes_count : u8;

    submesh_infos : [MAX_SUBMESHES] SubmeshInfo;

    vertex_buffer : *Buffer;
    index_buffer  : *Buffer;
}
