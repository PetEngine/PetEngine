AssetConverter :: struct {
    VERSION :: 1;

    EXCHANGE_MESHES_FOLDER :: "../../../source/assets/meshes/exchange";
    RUNTIME_MESHES_FOLDER  :: "../../../source/assets/meshes/runtime";

    EXCHANGE_TEXTURES_FOLDER :: "../../../source/assets/textures/exchange";
    RUNTIME_TEXTURES_FOLDER  :: "../../../source/assets/textures/runtime";
}

convertExchangeAssetsToRuntime :: () {
    meshes_context : MeshesContext;
    if fileExists(AssetConverter.EXCHANGE_MESHES_FOLDER) {
        meshes_begin := Basic.current_time_monotonic();
        enumerateFiles(AssetConverter.EXCHANGE_MESHES_FOLDER, convertMeshesCallback, *meshes_context, recursively = true);
        meshes_end := Basic.current_time_monotonic();

        meshes_context.duration = Basic.to_float64_seconds(meshes_end - meshes_begin);
    } else {
        verboseMessage("Exchange meshes folder is not found: %", AssetConverter.EXCHANGE_MESHES_FOLDER);
    }

    textures_context : TexturesContext;
    if fileExists(AssetConverter.EXCHANGE_TEXTURES_FOLDER) {
        autoResetPerFrameArenas();

        textures_begin := Basic.current_time_monotonic();
        defer textures_context.duration = Basic.to_float64_seconds(Basic.current_time_monotonic() - textures_begin);

        messageCallback :: (severity : NvttSeverity, error : NvttError, message : *u8, userData : *void) #c_call {
            push_context,defer_pop cast(*#Context) userData;

            if severity == {
                case .Info;    infoMessage("%", to_string(message));
                case .Warning; warningMessage("%", to_string(message));
                case .Error;   errorMessage("%", to_string(message));
            }
        }

        nvtt_success := nvttSetMessageCallback(messageCallback, *context);
        assert(nvtt_success == .True);

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

        if cuda_supported == .True {
            assert(nvttContextIsCudaAccelerationEnabled(nvtt_context) == .True);
        }

        textures_context.nvtt_context        = nvtt_context;
        textures_context.nvtt_output_options = nvtt_output_options;
        textures_context.cuda_supported      = cuda_supported;

        enumerateFiles(AssetConverter.EXCHANGE_TEXTURES_FOLDER, convertTexturesCallback, *textures_context, recursively = true);
    } else {
        verboseMessage("Exchange textures folder is not found: %", AssetConverter.EXCHANGE_TEXTURES_FOLDER);
    }

    formatStatisticsInt   :: inline (value : $T) -> Basic.FormatInt   { return .{ value = value, minimum_digits = 4, padding = #char " " }; }
    formatStatisticsFloat :: inline (value : $T) -> Basic.FormatFloat { return .{ value = value, width = 11, trailing_width = 6 }; }

    infoMessage(#string END
AssetConverter statistics:
    Meshes:   total: %, converted: %, failed: %, skipped: %, duration: % seconds
    Textures: total: %, converted: %, failed: %, skipped: %, duration: % seconds
END,
                formatStatisticsInt(meshes_context.total + meshes_context.skipped),
                formatStatisticsInt(meshes_context.converted),
                formatStatisticsInt(meshes_context.total - meshes_context.converted),
                formatStatisticsInt(meshes_context.skipped),
                formatStatisticsFloat(meshes_context.duration),
                formatStatisticsInt(textures_context.total + textures_context.skipped),
                formatStatisticsInt(textures_context.converted),
                formatStatisticsInt(textures_context.total - textures_context.converted),
                formatStatisticsInt(textures_context.skipped),
                formatStatisticsFloat(textures_context.duration));
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

MeshesContext :: struct {
    converted : s64;
    skipped   : s64;
    duration  : f64;

    total : s64; // #Temp.
}

TexturesContext :: struct {
    nvtt_context        : *NvttContext;
    nvtt_output_options : *NvttOutputOptions;
    cuda_supported      : NvttBoolean;

    converted : s64;
    skipped   : s64;
    duration  : f64;
    total     : s64;
}

convertMeshesCallback :: (meshes_context : *MeshesContext, exchange_file_info : *File.Info) -> EnumerateFilesCallbackResult {
    VALID_EXCHANGE_EXTENSIONS :: string.[
        "obj"
    ];

    extension, found := String.path_extension(exchange_file_info.name);
    if !found || !Basic.array_find(VALID_EXCHANGE_EXTENSIONS, extension) {
        errorMessage("Mesh \"%\" is not supported by AssetConverter: invalid extension. Valid extensions are: %",
                     exchange_file_info.name,
                     VALID_EXCHANGE_EXTENSIONS);
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

    if runtime_file_info.last_write_time >= exchange_file_info.last_write_time {
        runtime_file:, error = openFile(runtime_filename, .READ | .SHARED_READ | .EXISTS);
        assert(error == .NONE);
        defer closeFile(*runtime_file);

        header : MeshFile.Header = ---;
        readFile(runtime_file, *header);
        if header.version == MeshFile.VERSION {
            meshes_context.skipped += 1;
            return .CONTINUE;
        }
    }

    meshes_context.total += 1;

    success : bool;
    if extension == {
        case "obj"; success = convertObjMesh(exchange_file_info.name, mesh_name);
        case;       notImplemented(true);
    }

    if success {
        meshes_context.converted += 1;
    } else {
        errorMessage("Failed to convert \"%1.%2\" to \"%1.mesh\"", mesh_name, extension);
    }

    return .CONTINUE;
}

convertTexturesCallback :: (textures_context : *TexturesContext, exchange_file_info : *File.Info) -> EnumerateFilesCallbackResult {
    VALID_EXCHANGE_EXTENSIONS :: string.[
        "png",
        "dds",
        "jpg",
        "jpeg",
    ];

    extension, found := String.path_extension(exchange_file_info.name);
    if !found || !Basic.array_find(VALID_EXCHANGE_EXTENSIONS, extension) {
        errorMessage("Texture \"%\" is not supported by AssetConverter: invalid extension. Valid extensions are: %",
                     exchange_file_info.name,
                     VALID_EXCHANGE_EXTENSIONS);
        return .CONTINUE;
    }

    texture_name := string.{
        exchange_file_info.name.count - (AssetConverter.EXCHANGE_TEXTURES_FOLDER.count + "/".count) - (".".count + extension.count),
        exchange_file_info.name.data  + (AssetConverter.EXCHANGE_TEXTURES_FOLDER.count + "/".count)
    };

    runtime_filename := makeRuntimeTextureFilename(texture_name);

    runtime_file_info, error := getFileInfo(runtime_filename);
    assert(error == .NONE || error == .FILE_NOT_FOUND || error == .PATH_NOT_FOUND);

    if runtime_file_info.last_write_time >= exchange_file_info.last_write_time {
        runtime_file:, error = openFile(runtime_filename, .READ | .SHARED_READ | .EXISTS);
        assert(error == .NONE);
        defer closeFile(*runtime_file);

        header : TextureFile.Header = ---;
        readFile(runtime_file, *header);
        if header.version == TextureFile.VERSION {
            textures_context.skipped += 1;
            return .CONTINUE;
        }
    }

    textures_context.total += 1;

    if convertTextureNVTT(textures_context, exchange_file_info.name, texture_name, extension) {
        textures_context.converted += 1;
    } else {
        errorMessage("Failed to convert \"%1.%2\" to \"%1.texture\"", texture_name, extension);
    }

    return .CONTINUE;
}

convertTextureNVTT :: (textures_context : *TexturesContext, exchange_filename : string, name : string, extension : string) -> bool {
    infoMessage("Converting \"%.%\"...", name, extension);

    file_data, error := readEntireFile(exchange_filename, pushToArena, *context.pet.arenas.per_frame);
    assert(error == .NONE);

    is_srgb       := false; // @TODO: #TextureLoader. Detect sRGB.
    is_hdr        := false; // @TODO: #TextureLoader. Detect HDR.
    is_normal_map := String.ends_with(name, "_normals");
    assert(!(is_normal_map && is_srgb), "Normals cannot be stored in sRGB");
    assert(!(is_normal_map && is_hdr), "Normals cannot be stored in HDR");
    assert(!(is_srgb && is_hdr), "Texture cannot be stored in HDR and sRGB at the same time");

    nvtt_surface := nvttCreateSurface();
    defer nvttDestroySurface(nvtt_surface);

    has_alpha : NvttBoolean;
    nvtt_success := nvttSurfaceLoadFromMemory(nvtt_surface,
                                              file_data.data,
                                              cast(u64) file_data.count,
                                              *has_alpha,
                                              cast(NvttBoolean) is_normal_map);
    if nvtt_success == .False return false;

    MIN_TEXTURE_SIDE_SIZE :: 2;

    texture_file_header := TextureFile.Header.{
        width      = cast(u16) nvttSurfaceWidth(nvtt_surface),
        height     = cast(u16) nvttSurfaceHeight(nvtt_surface),
        depth      = cast(u16) nvttSurfaceDepth(nvtt_surface),
        mips_count = cast(u8)  nvttSurfaceCountMipmaps(nvtt_surface, MIN_TEXTURE_SIDE_SIZE),
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

    if textures_context.cuda_supported {
        nvttSurfaceToGPU(nvtt_surface);
    }

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

    nvtt_surfaces : StaticArray(*NvttSurface, Texture.MAX_MIPS_SUPPORTED);
    defer for nvtt_surfaces {
        if it_index > 0 nvttDestroySurface(it); // see: nvttDestroySurface(nvtt_surface)
    }

    //
    // Generate mips and prepare surfaces
    //

    pushBack(*nvtt_surfaces, nvtt_surface);

    for 1 .. texture_file_header.mips_count - 1 {
        nvtt_surface_copy := nvttSurfaceClone(nvtt_surfaces[it - 1]);
        pushBack(*nvtt_surfaces, nvtt_surface_copy);

        if !is_normal_map && has_alpha == .True {
            nvttSurfacePremultiplyAlpha(nvtt_surface_copy);
        }

        nvtt_success = nvttSurfaceBuildNextMipmapDefaults(nvtt_surface_copy, .Kaiser, MIN_TEXTURE_SIDE_SIZE);
        if nvtt_success == .False return false;

        if is_normal_map {
            nvttSurfaceNormalizeNormalMap(nvtt_surface_copy);
            nvttSurfacePackNormals(nvtt_surface_copy); // [-1; 1] -> [0; 1]
        } else {
            if has_alpha == .True {
                nvttSurfaceDemultiplyAlpha(nvtt_surface_copy);
            }
            if !is_srgb && !is_hdr {
                nvttSurfaceToSrgb(nvtt_surface_copy);
            }
        }
    }

    if is_normal_map {
        nvttSurfacePackNormals(nvtt_surface); // [-1; 1] -> [0; 1]
    } else if !is_srgb && !is_hdr {
        nvttSurfaceToSrgb(nvtt_surface);
    }

    //
    // Fill batch list
    //

    batch_list := nvttCreateBatchList();
    defer nvttDestroyBatchList(batch_list);

    for nvtt_surfaces {
        nvttBatchListAppend(batch_list, it, 0, cast(s32) it_index, textures_context.nvtt_output_options);
    }

    //
    // Compress batch
    //

    texture_file := beginTextureFileSerialization(name);
    defer endTextureFileSerialization(*texture_file);
    writeTextureFileHeader(*texture_file, texture_file_header);

    context.pet.converter.texture_file = *texture_file;
    defer context.pet.converter = .{};
    g_contextForOutputHandler = *context;

    nvtt_success = nvttContextCompressBatch(textures_context.nvtt_context, batch_list, nvtt_compression_options);
    if nvtt_success == .False return false;

    infoMessage("\"%.texture\" has been converted", name);
    return true;
}

outputHandler :: (data : *void, size : s32) -> NvttBoolean #c_call {
    push_context, defer_pop g_contextForOutputHandler;
    appendTextureFileData(context.pet.converter.texture_file, .{ count = size, data = data });
    return .True;
}

// @Cleanup: #TextureLoader.
g_contextForOutputHandler : *#Context;

#load "obj_mesh.jai";

#import "nvtt";
