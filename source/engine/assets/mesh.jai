// @TODO: #AssetConverter.
//     - Vertex format for 1 position and 1 varying streams?

Mesh :: struct {
    VERSION :: 1;

    MAX_SUBMESHES :: 16;

    Header :: struct {
        version         : u8;
        submeshes_count : u8;
        vertex_format   : VertexFormat;
        submesh_offsets : [MAX_SUBMESHES] u64;
    } #no_padding
}

VertexFormat :: enum u8 {
    DEFAULT;
}

VertexFormats :: struct {
    Default :: struct {
        position_u : v4f;
        normal_v   : v4f;
    } #no_padding
}
