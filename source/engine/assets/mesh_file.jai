MeshFile :: struct {
    VERSION :: 1;

    Header :: struct {
        version         : u8 = VERSION;
        submeshes_count : u8;
        vertex_format   : VertexFormat;
        submesh_infos   : [Mesh.MAX_SUBMESHES] SubmeshInfo;
    } #no_padding

    SubmeshInfo :: struct {
        offset         : u64;
        vertices_count : u32;
        indices_count  : u32;
    } #no_padding

    getHeader :: inline (file_data : string) -> *Header {
        return cast(*Header) file_data.data;
    }
}

serializeMesh :: (
    vertices        : *[Mesh.MAX_SUBMESHES][..] $Vertex,
    indices         : *[Mesh.MAX_SUBMESHES][..] u32,
    submeshes_count : u8,
    name            : string
) -> bool {
    VERTEX_FORMAT, SUCCESS :: #run vertexTypeToVertexFormat(Vertex);
    #assert SUCCESS;

    assert(0 < submeshes_count && submeshes_count <= Mesh.MAX_SUBMESHES);

    header := MeshFile.Header.{
        submeshes_count = submeshes_count,
        vertex_format   = VERTEX_FORMAT,
    };

    submesh_offset := size_of(MeshFile.Header);

    submeshes   := toView(header.submesh_infos.data, header.submeshes_count);
    vertices_it := vertices.data;
    indices_it  := indices.data;
    for * submeshes {
        assert(vertices_it.count > 0);

        it.offset         = cast(u64) submesh_offset;
        it.vertices_count = cast(u32) vertices_it.count;
        it.indices_count  = cast(u32) max(0, indices_it.count);

        submesh_offset += it.vertices_count * size_of(Vertex)
                       +  it.indices_count  * size_of(u32);

        vertices_it += 1;
        indices_it  += 1;
    }

    filename := makeRuntimeMeshFilename(name);

    file, error := openFile(filename, .WRITE | .TRUNCATE | .SEQ, true);
    if error != .NONE {
        errorMessage("Failed to open runtime mesh file: \"%\". Error: %", filename, error);
        return false;
    }
    defer closeFile(*file);

    writeFile(file, *header);

    vertices_it = vertices.data;
    indices_it  = indices.data;
    for submeshes {
        assert(getFileCursorPosition(file) == cast(s64) it.offset);

        writeFile(file, vertices_it.*);
        if indices_it.* {
            writeFile(file, indices_it.*);
        }

        vertices_it += 1;
        indices_it  += 1;
    }

    return true;
}
