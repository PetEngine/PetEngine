AssetConverter :: struct {
    VERSION :: 1;

    EXCHANGE_MESHES_FOLDER :: "../../../source/assets/meshes/exchange";
    RUNTIME_MESHES_FOLDER  :: "../../../source/assets/meshes/runtime";

    EXCHANGE_TEXTURES_FOLDER :: "../../../source/assets/textures/exchange";
    RUNTIME_TEXTURES_FOLDER  :: "../../../source/assets/textures/runtime";
}

convertExchangeAssetsToRuntime :: () {
    meshes_count : u64;
    meshes_begin := Basic.current_time_monotonic();
    if fileExists(AssetConverter.EXCHANGE_MESHES_FOLDER) {
        enumerateFiles(AssetConverter.EXCHANGE_MESHES_FOLDER, convertMeshesCallback, *meshes_count, recursively = true);
    } else {
        verboseMessage("Exchange meshes folder is not found: %", AssetConverter.EXCHANGE_MESHES_FOLDER);
    }
    meshes_end := Basic.current_time_monotonic();

    textures_count : u64;
    textures_begin := Basic.current_time_monotonic();
    if fileExists(AssetConverter.EXCHANGE_TEXTURES_FOLDER) {
        enumerateFiles(AssetConverter.EXCHANGE_TEXTURES_FOLDER, convertTexturesCallback, *textures_count, recursively = true);
    } else {
        verboseMessage("Exchange textures folder is not found: %", AssetConverter.EXCHANGE_TEXTURES_FOLDER);
    }
    textures_end := Basic.current_time_monotonic();

    infoMessage(#string END
AssetConverter has converted:
    Meshes:   % for % seconds
    Textures: % for % seconds
END,
                Basic.FormatInt.{ value = meshes_count, minimum_digits = 4, padding = #char " " },
                Basic.FormatFloat.{ value = Basic.to_float64_seconds(meshes_end - meshes_begin), width = 11, trailing_width = 6 },
                Basic.FormatInt.{ value = textures_count, minimum_digits = 4, padding = #char " " },
                Basic.FormatFloat.{ value = Basic.to_float64_seconds(textures_end - textures_begin), width = 11, trailing_width = 6 });
}

makeRuntimeMeshFilename :: (name : string) -> string {
    capacity := AssetConverter.RUNTIME_MESHES_FOLDER.count + "/".count + name.count + ".mesh".count;

    filename := string.{ data = pushToArena(*context.pet.arenas.per_frame, capacity) };
    appendToString(*filename, capacity, AssetConverter.RUNTIME_MESHES_FOLDER, "/", name, ".mesh");

    return filename;
}

makeRuntimeTextureFilename :: (name : string) -> string {
    capacity := AssetConverter.RUNTIME_TEXTURES_FOLDER.count + "/".count + name.count + ".texture".count;

    filename := string.{ data = pushToArena(*context.pet.arenas.per_frame, capacity) };
    appendToString(*filename, capacity, AssetConverter.RUNTIME_TEXTURES_FOLDER, "/", name, ".texture");

    return filename;
}


#load "mesh_file.jai";
#load "texture_file.jai";

#scope_file

convertMeshesCallback :: (meshes_count : *u64, exchange_file_info : *File.Info) -> EnumerateFilesCallbackResult {
    VALID_EXCHANGE_EXTENSIONS :: string.[
        "obj"
    ];

    extension, found := String.path_extension(exchange_file_info.name);
    if !found return .CONTINUE;

    if !Basic.array_find(VALID_EXCHANGE_EXTENSIONS, extension) {
        return .CONTINUE;
    }

    autoResetPerFrameArenas();

    mesh_name := string.{
        exchange_file_info.name.count - (AssetConverter.EXCHANGE_MESHES_FOLDER.count + "/".count) - (".".count + extension.count),
        exchange_file_info.name.data  + (AssetConverter.EXCHANGE_MESHES_FOLDER.count + "/".count)
    };

    runtime_filename := makeRuntimeMeshFilename(mesh_name);

    runtime_file_info, error := getFileInfo(runtime_filename);
    assert(error == .NONE || error == .FILE_NOT_FOUND || error == .PATH_NOT_FOUND);

    if runtime_file_info.last_write_time > exchange_file_info.last_write_time {
        runtime_file:, error = openFile(runtime_filename, .READ | .SHARED_READ | .EXISTS);
        assert(error == .NONE);
        defer closeFile(*runtime_file);

        header : MeshFile.Header = ---;
        readFile(runtime_file, *header);
        if header.version == MeshFile.VERSION {
            return .CONTINUE;
        }
    }

    success : bool;
    if extension == {
        case "obj"; success = convertObjMesh(exchange_file_info.name, mesh_name);
        case;       notImplemented(true);
    }

    if success {
        meshes_count.* += 1;
    } else {
        errorMessage("Failed to convert \"%1.%2\" to \"%1.mesh\"", mesh_name, extension);
    }

    return .CONTINUE;
}

convertTexturesCallback :: (textures_count : *u64, exchange_file_info : *File.Info) -> EnumerateFilesCallbackResult {
    VALID_EXCHANGE_EXTENSIONS :: string.[
        "png",
        "dds",
        "jpg",
        "jpeg",
    ];

    extension, found := String.path_extension(exchange_file_info.name);
    if !found return .CONTINUE;

    if !Basic.array_find(VALID_EXCHANGE_EXTENSIONS, extension) {
        return .CONTINUE;
    }

    autoResetPerFrameArenas();

    texture_name := string.{
        exchange_file_info.name.count - (AssetConverter.EXCHANGE_TEXTURES_FOLDER.count + "/".count) - (".".count + extension.count),
        exchange_file_info.name.data  + (AssetConverter.EXCHANGE_TEXTURES_FOLDER.count + "/".count)
    };

    /* @Cleanup: #TextureLoader. Uncomment
    runtime_filename := makeRuntimeTextureFilename(texture_name);

    runtime_file_info, error := getFileInfo(runtime_filename);
    assert(error == .NONE || error == .FILE_NOT_FOUND || error == .PATH_NOT_FOUND);

    if runtime_file_info.last_write_time > exchange_file_info.last_write_time {
        runtime_file:, error = openFile(runtime_filename, .READ | .SHARED_READ | .EXISTS);
        assert(error == .NONE);
        defer closeFile(*runtime_file);

        header : TextureFile.Header = ---;
        readFile(runtime_file, *header);
        if header.version == TextureFile.VERSION {
            return .CONTINUE;
        }
    } */

    if convertTextureNVTT(exchange_file_info.name, texture_name, extension) {
        textures_count.* += 1;
    } else {
        errorMessage("Failed to convert \"%1.%2\" to \"%1.texture\"", texture_name, extension);
    }

    return .CONTINUE;
}

convertTextureNVTT :: (exchange_filename : string, name : string, extension : string) -> bool {
    infoMessage("Converting \"%.%\"...", name, extension);

    file_data, error := readEntireFile(exchange_filename, pushToArena, *context.pet.arenas.per_frame);
    assert(error == .NONE);

    nvtt_success := nvttSetMessageCallback((severity : NvttSeverity, error : NvttError, message : *u8, userData : *void) #c_call {
        push_context,defer_pop cast(*#Context) userData;

        if severity == {
            case .Info;    infoMessage("%", to_string(message));
            case .Warning; warningMessage("%", to_string(message));
            case .Error;   errorMessage("%", to_string(message));
        }
    }, *context);
    if nvtt_success == .False return false;

    nvtt_surface := nvttCreateSurface();
    defer nvttDestroySurface(nvtt_surface);

    is_srgb       := false; // @TODO: #TextureLoader. Detect sRGB.
    is_hdr        := false; // @TODO: #TextureLoader. Detect HDR.
    is_normal_map := String.ends_with(name, "_normals");
    assert(!(is_normal_map && is_srgb), "Normals cannot be stored in sRGB");
    assert(!(is_normal_map && is_hdr), "Normals cannot be stored in HDR");
    assert(!(is_srgb && is_hdr), "Texture cannot be stored in HDR and sRGB at the same time");

    has_alpha : NvttBoolean;
    nvtt_success = nvttSurfaceLoadFromMemory(nvtt_surface,
                                             file_data.data,
                                             cast(u64) file_data.count,
                                             *has_alpha,
                                             cast(NvttBoolean) is_normal_map);
    if nvtt_success == .False return false;

    texture_file_header := TextureFile.Header.{
        width      = cast(u16) nvttSurfaceWidth(nvtt_surface),
        height     = cast(u16) nvttSurfaceHeight(nvtt_surface),
        depth      = cast(u16) nvttSurfaceDepth(nvtt_surface),
        mips_count = cast(u8)  nvttSurfaceCountMipmaps(nvtt_surface, 4),
    };

    nvtt_compression_options := nvttCreateCompressionOptions();
    defer nvttDestroyCompressionOptions(nvtt_compression_options);
    if is_hdr {
        texture_file_header.format = .BC6H_UFLOAT;
        nvttSetCompressionOptionsFormat(nvtt_compression_options, .BC6U);
        nvttSetCompressionOptionsQuality(nvtt_compression_options, .Normal);
    } else if has_alpha == .False {
        texture_file_header.format = .BC1_SRGB;
        nvttSetCompressionOptionsFormat(nvtt_compression_options, .BC1);
        nvttSetCompressionOptionsQuality(nvtt_compression_options, .Highest);
    } else {
        if is_normal_map {
            texture_file_header.format = .BC3_UNORM;
            warningMessage("Normal map \"%\" contains alpha channel. Is it intended?", name);
            nvttSetCompressionOptionsFormat(nvtt_compression_options, .BC3);
            nvttSetCompressionOptionsQuality(nvtt_compression_options, .Highest);
        } else {
            texture_file_header.format = .BC7_SRGB;
            nvttSetCompressionOptionsFormat(nvtt_compression_options, .BC7);
            nvttSetCompressionOptionsQuality(nvtt_compression_options, .Normal);
        }
    }
    assert(texture_file_header.format != .UNKNOWN);

    nvtt_output_options := nvttCreateOutputOptions();
    defer nvttDestroyOutputOptions(nvtt_output_options);
    nvttSetOutputOptionsOutputHandler(nvtt_output_options, null, outputHandler, null);
    nvttSetOutputOptionsOutputHeader(nvtt_output_options, .False);

    cuda_supported := nvttIsCudaSupported();
    if cuda_supported == .False {
        warningMessage("CUDA is not supported. Convertion will take much more time since it will be done on CPU.");
    }

    nvtt_context := nvttCreateContext();
    defer nvttDestroyContext(nvtt_context);
    nvttSetContextCudaAcceleration(nvtt_context, cuda_supported);

    if cuda_supported {
        assert(nvttContextIsCudaAccelerationEnabled(nvtt_context) == .True);
        nvttSurfaceToGPU(nvtt_surface);
    }

    texture_file := beginTextureFileSerialization(name);
    defer endTextureFileSerialization(*texture_file);

    context.pet.converter.texture_file = *texture_file;
    defer context.pet.converter = .{};
    g_contextForOutputHandler = *context;

    nvtt_texture_type := nvttSurfaceType(nvtt_surface);
    if #complete nvtt_texture_type == {
        case ._2D;
            texture_file_header.dimension = ._2D;

        case ._Cube;
            texture_file_header.dimension = ._2D;
            texture_file_header.flags     = .CUBE;

        case ._3D;
            texture_file_header.dimension = ._3D;

        case;
	       assertMessage("Corrupted NvttTextureType value: %", nvtt_texture_type);
    }

    array_size := 1; // @TODO: #TextureLoader. Detect array.
    assert(!(array_size > 1 && (texture_file_header.dimension == ._3D || texture_file_header.depth > 1)),
           "Array textures cannot contain 3D textures");

    writeTextureFileHeader(*texture_file, texture_file_header);

    for 0 .. array_size - 1 {
        for 0 .. texture_file_header.mips_count - 1 {
            nvtt_surface_copy := nvttSurfaceClone(nvtt_surface);
            defer nvttDestroySurface(nvtt_surface_copy);

            if is_normal_map {
                nvttSurfacePackNormals(nvtt_surface_copy); // [-1; 1] -> [0; 1]
            } else if !is_srgb && !is_hdr {
                nvttSurfaceToSrgb(nvtt_surface_copy);
            }

            nvtt_success = nvttContextCompress(nvtt_context, nvtt_surface_copy, 0, it, nvtt_compression_options, nvtt_output_options);
            if nvtt_success == .False return false;

            if it < texture_file_header.mips_count - 1 {
                if !is_normal_map && has_alpha == .True {
                    nvttSurfacePremultiplyAlpha(nvtt_surface);
                }

                nvtt_success = nvttSurfaceBuildNextMipmapDefaults(nvtt_surface, .Kaiser, 4);
                if nvtt_success == .False return false;

                if is_normal_map {
                    nvttSurfaceNormalizeNormalMap(nvtt_surface);
                } else if has_alpha == .True {
                    nvttSurfaceDemultiplyAlpha(nvtt_surface);
                }
            }
        }
    }

    infoMessage("\"%.texture\" has been converted", name);
    return true;
}

outputHandler :: (data : *void, size : s32) -> NvttBoolean #c_call {
    push_context, defer_pop g_contextForOutputHandler;

    if context.pet.converter.last_data != data {
        context.pet.converter.last_data = data;
        appendTextureFileData(context.pet.converter.texture_file, .{ count = size, data = data });
    }

    return .True;
}

// @Cleanup: #TextureLoader.
g_contextForOutputHandler : *#Context;

#load "obj_mesh.jai";

#import "nvtt";
