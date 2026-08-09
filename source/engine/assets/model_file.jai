// Layout:
//     [Header]
//     [Textures..]
//     [Materials..]
//     [Meshes..]
//     [Vertices..]
//     [Indices..]
ModelFile :: struct {
    VERSION       : u8  : 1;
    INVALID_INDEX : u16 : 0xFFFF;

    Header :: struct {
        version         : u8           = VERSION  #align 1;
        vertex_format   : VertexFormat = .DEFAULT #align 1;
        textures_count  : u16                     #align 1;
        materials_count : u16                     #align 1;
        meshes_count    : u16                     #align 1;
        vertices_count  : u32                     #align 1;
        indices_count   : u32                     #align 1;
    } #no_padding

    TextureHeader :: struct {
        name_length : u16 #align 1;
        // inplace data goes next
    } #no_padding

    Material :: struct {
        texture_index_albedo             : u16 = INVALID_INDEX #align 1;
        texture_index_normal             : u16 = INVALID_INDEX #align 1;
        texture_index_emissive           : u16 = INVALID_INDEX #align 1;
        texture_index_metallic_roughness : u16 = INVALID_INDEX #align 1;
        texture_index_occlusion          : u16 = INVALID_INDEX #align 1;

        factor_albedo    : v4f = .{ 1.0, 1.0, 1.0, 1.0 } #align 1;
        factor_emissive  : v3f                           #align 1;
        factor_metallic  : f32 = 1.0                     #align 1;
        factor_roughness : f32 = 1.0                     #align 1;
    } #no_padding

    PrimitiveTopology :: ShaderCompiler.GraphicsPipelineState.PrimitiveTopology;

    Mesh :: struct {
        indices_start      : u32                                #align 1;
        indices_count      : u32                                #align 1;
        mesh_to_model      : m3x4              =  IDENTITY_3X4  #align 1;
        model_to_mesh      : m3x4              =  IDENTITY_3X4  #align 1;
        material_index     : u16               =  INVALID_INDEX #align 1;
        primitive_topology : PrimitiveTopology = .TRIANGLE_LIST #align 1;
    } #no_padding

    getHeader :: inline (file_data : string) -> *Header {
        return cast(*Header) file_data.data;
    }
} #no_padding

VertexFormat :: enum u8 {
    DEFAULT;
}

VertexTypes :: struct {
    Default :: struct {
        position_u : v4f #align 1;
        normal_v   : v4f #align 1;
    } #no_padding
} #no_padding

serializeModel :: (
    name      : string,
    textures  : [] string,
    materials : [] ModelFile.Material,
    meshes    : [] ModelFile.Mesh,
    vertices  : [] $Vertex,
    indices   : [] u32,
) -> bool {
    VERTEX_FORMAT, SUCCESS :: #run vertexTypeToVertexFormat(Vertex);
    #assert SUCCESS;

    header := ModelFile.Header.{
        vertex_format   = VERTEX_FORMAT,
        textures_count  = cast(u16) textures.count,
        materials_count = cast(u16) materials.count,
        meshes_count    = cast(u16) meshes.count,
        vertices_count  = cast(u32) vertices.count,
        indices_count   = cast(u32) indices.count,
    };

    filename := makeRuntimeModelFilename(name);
    file, error := openFile(filename, .WRITE | .TRUNCATE | .SEQ, true);
    if error != .NONE {
        errorMessage("Failed to open runtime model file: \"%\". Error: %", filename, error);
        return false;
    }
    defer closeFile(*file);

    writeFile(file, *header);
    for textures {
        texture_header := ModelFile.TextureHeader.{
            name_length = cast(u16) it.count
        };
        writeFile(file, *texture_header);
        writeFile(file, it);
    }
    writeFile(file, materials);
    writeFile(file, meshes);
    writeFile(file, vertices);
    writeFile(file, indices);

    return true;
}

getVertexStride :: (format : VertexFormat) -> s64 {
    if #complete format == {
        case .DEFAULT; return size_of(VertexTypes.Default);
    }
}

// @TODO: #GLTF. #scope_file

vertexTypeToVertexFormat :: (vertex_type : Type) -> (VertexFormat, success : bool) #compile_time {
    INFO :: type_info(VertexTypes);
    #assert INFO.type == .STRUCT;

    if (cast(*Type_Info) vertex_type).type != .STRUCT {
        errorMessage("Vertex type should be struct");
        return .DEFAULT, false;
    }

    for member : INFO.members {
        if member.type.type != .TYPE continue;

        assert(member.offset_into_constant_storage > -1);
        assert(member.type.runtime_size == size_of(*void));

        member_type_info := (cast(**Type_Info) *INFO.constant_storage[member.offset_into_constant_storage]).*;
        member_type      := Compiler.get_type(member_type_info);

        if member_type == vertex_type {
            VERTEX_FORMAT_INFO :: type_info(VertexFormat);
            #assert VERTEX_FORMAT_INFO.type == .ENUM;

            for VERTEX_FORMAT_INFO.values {
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
    if #complete format == {
        case .DEFAULT; return VertexTypes.Default;
    }
}
