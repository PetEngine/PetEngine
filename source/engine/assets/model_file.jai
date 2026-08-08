ModelFile :: struct {
    VERSION :: 1;

    Header :: struct {
        version       : u8 = VERSION;
        vertex_format : VertexFormat;
    } #no_padding

    getHeader :: inline (file_data : string) -> *Header {
        return cast(*Header) file_data.data;
    }
}
