// @TODO: #AssetConverter.
//     - Vertex format for 1 position and 1 varying streams?
//     - u16 indices

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

VertexFormat :: enum u8 {
    DEFAULT;
}

VertexTypes :: struct {
    Default :: struct {
        position_u : v4f;
        normal_v   : v4f;
    } #no_padding
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

    writeFile(file, *header, size_of(MeshFile.Header));

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

getVertexStride :: (format : VertexFormat) -> s64 {
    if #complete format == {
        case .DEFAULT; return size_of(VertexTypes.Default);
    }
}

#scope_file

vertexTypeToVertexFormat :: (vertex_type : Type) -> (VertexFormat, success : bool) #compile_time {
    assert(#compile_time, "This function should be run only in compile time"); // @Cleanup: #CompileTime.

    info := type_info(VertexTypes);
    assert(info.type == .STRUCT);

    if (cast(*Type_Info) vertex_type).type != .STRUCT {
        errorMessage("Vertex type should be struct");
        return .DEFAULT, false;
    }

    for member : info.members {
        if member.type.type != .TYPE continue;

        assert(member.offset_into_constant_storage > -1);
        assert(member.type.runtime_size == size_of(*void));

        member_type_info := (cast(**Type_Info) *info.constant_storage[member.offset_into_constant_storage]).*;

        Compiler :: #import "Compiler";
        member_type := Compiler.get_type(member_type_info);

        if member_type == vertex_type {
            vertex_format_info := type_info(VertexFormat);
            assert(vertex_format_info.type == .ENUM);

            for vertex_format_info.values {
                vertex_format := cast(VertexFormat) it;
                if vertexFormatToVertexType(vertex_format) == vertex_type {
                    return vertex_format, true;
                }
            }

            errorMessage("Vertex type is found, but there is no VertexFormat associated with it");
            return .DEFAULT, false;
        }
    }

    errorMessage("Vertex type was not found in VertexTypes struct");
    return .DEFAULT, false;
}

vertexFormatToVertexType :: (format : VertexFormat) -> Type #compile_time {
    assert(#compile_time, "This function should be run only in compile time"); // @Cleanup: #CompileTime.

    if #complete format == {
        case .DEFAULT; return VertexTypes.Default;
    }
}
