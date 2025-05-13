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
        textures_begin := Basic.current_time_monotonic();
        defer textures_context.duration = Basic.to_float64_seconds(Basic.current_time_monotonic() - textures_begin);

        messageCallback :: (severity : NvttSeverity, error : NvttError, message : *u8, userData : *void) #c_call {
            push_context,defer_pop cast(*#Context) userData;

            if severity == {
                case .Info;    infoMessage("NVTT: %", to_string(message));
                case .Warning; warningMessage("NVTT: %", to_string(message));
                case .Error;   errorMessage("NVTT: %", to_string(message));
            }
        }

        nvtt_success := nvttSetMessageCallback(messageCallback, *context);
        assert(nvtt_success == .True);

        nvtt_output_options := nvttCreateOutputOptions();
        defer nvttDestroyOutputOptions(nvtt_output_options);

        #if TEST_TEXTURES {
            createDirectory(TEST_TEXTURES_FOLDER);
            nvttSetOutputOptionsOutputHeader(nvtt_output_options, .True);
        } else {
            nvttSetOutputOptionsOutputHandler(nvtt_output_options, null, outputHandler, null);
            nvttSetOutputOptionsOutputHeader(nvtt_output_options, .False);
        }

        cuda_supported := nvttIsCudaSupported();
        if cuda_supported == .False {
            warningMessage("CUDA is not supported. Conversion will take much more time since it will be done on CPU.");
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

TEST_TEXTURES :: false;

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

ExchangeTextureFlags :: enum_flags u8 {
    SRGB;
    HDR;
    NORMAL_MAP;
}

SurfaceInfo :: struct {
    surface     : *NvttSurface;
    array_layer : u16;
    face        : u8;
    mip         : u8;
}
SurfaceInfoArray :: StaticArray(SurfaceInfo, 6 * Texture.MAX_MIPS_SUPPORTED);

// @TODO: #ConversionRules.
TextureConversionRule :: struct {
    max_texture_width  : u16 = 4096;
    max_texture_height : u16 = 4096;
    max_texture_depth  : u16 = 2048;

    min_texture_width  : u16 = 4;
    min_texture_height : u16 = 4;
    min_texture_depth  : u16 = 2;
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

    autoResetPerFrameArenas();

    texture_name := string.{
        exchange_file_info.name.count - (AssetConverter.EXCHANGE_TEXTURES_FOLDER.count + "/".count) - (".".count + extension.count),
        exchange_file_info.name.data  + (AssetConverter.EXCHANGE_TEXTURES_FOLDER.count + "/".count)
    };

    #if TEST_TEXTURES {
        test_filename := makeTestTextureFilename(texture_name);

        test_file_info, error := getFileInfo(test_filename);
        assert(error == .NONE || error == .FILE_NOT_FOUND || error == .PATH_NOT_FOUND);

        if test_file_info.last_write_time >= exchange_file_info.last_write_time {
            return .CONTINUE;
        }
    } else {
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
    }

    textures_context.total += 1;

    #if TEST_TEXTURES {
        nvttSetOutputOptionsFileName(textures_context.nvtt_output_options, test_filename.data);
    }

    // @TODO: #ConversionRules.
    rule : TextureConversionRule;

    if convertTextureNVTT(textures_context.*, rule, exchange_file_info.name, texture_name, extension) {
        textures_context.converted += 1;
    } else #if TEST_TEXTURES {
        errorMessage("Failed to convert \"%1.%2\" to \"%1.dds\"", texture_name, extension);
    } else {
        errorMessage("Failed to convert \"%1.%2\" to \"%1.texture\"", texture_name, extension);
    }

    return .CONTINUE;
}

convertTextureNVTT :: (
    textures_context  : TexturesContext,
    rule              : TextureConversionRule,
    exchange_filename : string,
    name              : string,
    extension         : string
) -> bool {
    infoMessage("Converting \"%.%\"...", name, extension);

    file_data, error := readEntireFile(exchange_filename, pushToArena, *context.pet.arenas.per_frame);
    assert(error == .NONE);

    exchange_texture_flags, array_size := getExchangeTextureFlags(file_data, name, extension);
    if array_size {
        errorMessage("NVTT 3.0 has no support for texture arrays, so they are not supported yet");
        return false;
    }

    texture_file_header : TextureFile.Header;

    nvtt_surface := nvttCreateSurface();
    // Do not defer nvttDestroySurface for regular textures,
    // all the surfaces will be destroyed in the defered loop below
    defer if texture_file_header.flags & .CUBE {
        nvttDestroySurface(nvtt_surface);
    }

    has_alpha : NvttBoolean;
    nvtt_success := nvttSurfaceLoadFromMemory(nvtt_surface,
                                              file_data.data,
                                              cast(u64) file_data.count,
                                              *has_alpha,
                                              cast(NvttBoolean) (exchange_texture_flags & .NORMAL_MAP));
    if nvtt_success == .False {
        errorMessage("nvttSurfaceLoadFromMemory has failed");
        return false;
    }

    #if TEST_TEXTURES {
        if exchange_texture_flags & .NORMAL_MAP {
            nvttSetSurfaceNormalMap(nvtt_surface, .True);
            nvttSetOutputOptionsSrgbFlag(textures_context.nvtt_output_options, .False);
        } else if exchange_texture_flags & .HDR {
            nvttSetSurfaceNormalMap(nvtt_surface, .False);
            nvttSetOutputOptionsSrgbFlag(textures_context.nvtt_output_options, .False);
        } else {
            nvttSetSurfaceNormalMap(nvtt_surface, .False);
            nvttSetOutputOptionsSrgbFlag(textures_context.nvtt_output_options, .True);
        }
    }

    if textures_context.cuda_supported {
        nvttSurfaceToGPU(nvtt_surface);
    }

    nvtt_cube_surface : *NvttCubeSurface;
    defer if nvtt_cube_surface {
        nvttDestroyCubeSurface(nvtt_cube_surface);
    }

    source_width  : u16;
    source_height : u16;
    source_depth  : u16;

    force_cube : bool; // @Cleanup: #ConversionRules.
    if nvttSurfaceType(nvtt_surface) == {
        case ._2D;
            source_width  = cast(u16) nvttSurfaceWidth(nvtt_surface);
            source_height = cast(u16) nvttSurfaceHeight(nvtt_surface);

            force_cube = String.starts_with(name, "skybox");

        case ._Cube;
            force_cube = true;

        case ._3D;
            source_depth = cast(u16) nvttSurfaceDepth(nvtt_surface);
            texture_file_header.depth = min(source_depth, rule.max_texture_depth);
            assert(!array_size, "Texture arrays cannot contain 3D textures");
    }

    if force_cube {
        texture_file_header.flags = .CUBE;

        nvtt_cube_surface = nvttCreateCubeSurface();
        nvttCubeSurfaceFold(nvtt_cube_surface, nvtt_surface, .HorizontalCross);

        source_width  = cast(u16) nvttCubeSurfaceEdgeLength(nvtt_cube_surface);
        source_height = source_width;
    }

    texture_file_header.width  = min(source_width,  rule.max_texture_width);
    texture_file_header.height = min(source_height, rule.max_texture_height);

    min_texture_width  := min(source_width,  rule.min_texture_width);
    min_texture_height := min(source_height, rule.min_texture_height);

    tail_mips_count_to_drop := maxMipsCount(min_texture_width, min_texture_height, min(source_depth, rule.min_texture_depth)) - 1;

    texture_file_header.mips_count = maxMipsCount(texture_file_header.width, texture_file_header.height, texture_file_header.depth);
    texture_file_header.mips_count = max(texture_file_header.mips_count - tail_mips_count_to_drop, 1);

    nvtt_compression_options := nvttCreateCompressionOptions();
    defer nvttDestroyCompressionOptions(nvtt_compression_options);
    if exchange_texture_flags & .HDR {
        texture_file_header.format = .BC6H_UFLOAT;
        nvttSetCompressionOptionsFormat(nvtt_compression_options, .BC6U);
        nvttSetCompressionOptionsQuality(nvtt_compression_options, .Normal);
    } else if has_alpha == .False {
        texture_file_header.format = ifx exchange_texture_flags & .NORMAL_MAP then .BC1_UNORM else .BC1_SRGB;
        nvttSetCompressionOptionsFormat(nvtt_compression_options, .BC1);
        nvttSetCompressionOptionsQuality(nvtt_compression_options, .Highest);
    } else {
        if exchange_texture_flags & .NORMAL_MAP {
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

    surface_info_array : SurfaceInfoArray;
    defer {
        if texture_file_header.flags & .CUBE {
            for surface_info_array {
                if it.mip > 0 then nvttDestroySurface(it.surface);
            }
        } else {
            for surface_info_array {
                nvttDestroySurface(it.surface);
            }
        }
    }

    //
    // Generate mips and prepare surfaces
    //

    source_mips_count := maxMipsCount(source_width, source_height, source_depth);
    source_mips_count  = max(source_mips_count - tail_mips_count_to_drop, 1);

    assert(source_mips_count >= texture_file_header.mips_count);
    head_mips_count_to_drop := source_mips_count - texture_file_header.mips_count;

    min_texture_wh := min(min_texture_width, min_texture_height);

    if texture_file_header.flags & .CUBE {
        for 0 .. 5 {
            face := nvttCubeSurfaceFace(nvtt_cube_surface, cast(s32) it);
            if !generateMips(face,
                                cast(u8) it,
                                exchange_texture_flags,
                                has_alpha,
                                head_mips_count_to_drop,
                                texture_file_header.mips_count,
                                min_texture_wh,
                                *surface_info_array) {
                return false;
            }
        }
    } else {
        if !generateMips(nvtt_surface,
                            0,
                            exchange_texture_flags,
                            has_alpha,
                            head_mips_count_to_drop,
                            texture_file_header.mips_count,
                            min_texture_wh,
                            *surface_info_array) {
            return false;
        }
    }

    for surface_info_array {
        if exchange_texture_flags & .NORMAL_MAP {
            nvttSurfacePackNormals(it.surface); // [-1; 1] -> [0; 1]
        } else {
            if has_alpha == .True {
                nvttSurfaceDemultiplyAlpha(it.surface);
            }
            if !(exchange_texture_flags & .HDR) {
                nvttSurfaceToSrgb(it.surface);
            }
        }
    }

    //
    // Fill batch list
    //

    batch_list := nvttCreateBatchList();
    defer nvttDestroyBatchList(batch_list);

    for surface_info_array {
        nvttBatchListAppend(batch_list, it.surface, it.face, it.mip, textures_context.nvtt_output_options);
    }

    //
    // Compress batch
    //

    #if TEST_TEXTURES {
        if texture_file_header.flags & .CUBE {
            nvttContextOutputHeaderCube(textures_context.nvtt_context,
                                        nvtt_cube_surface,
                                        texture_file_header.mips_count,
                                        nvtt_compression_options,
                                        textures_context.nvtt_output_options);
        } else {
            nvttContextOutputHeader(textures_context.nvtt_context,
                                    surface_info_array[0].surface,
                                    texture_file_header.mips_count,
                                    nvtt_compression_options,
                                    textures_context.nvtt_output_options);
        }
    } else {
        texture_file := beginTextureFileSerialization(name);
        defer endTextureFileSerialization(*texture_file);
        writeTextureFileHeader(*texture_file, texture_file_header);

        context.pet.converter.texture_file = *texture_file;
        defer context.pet.converter = .{};
        g_contextForOutputHandler = *context;
    }

    nvtt_success = nvttContextCompressBatch(textures_context.nvtt_context, batch_list, nvtt_compression_options);
    if nvtt_success == .False {
        errorMessage("nvttContextCompressBatch has failed");
        return false;
    }

    #if TEST_TEXTURES {
        infoMessage("\"%.dds\" has been converted", name);
    } else {
        infoMessage("\"%.texture\" has been converted", name);
    }
    return true;
}

generateMips :: (
    nvtt_surface            : *NvttSurface,
    face_index              : u8,
    exchange_texture_flags  : ExchangeTextureFlags,
    has_alpha               : NvttBoolean,
    head_mips_count_to_drop : u8,
    mips_count_to_generate  : u8,
    min_texture_wh          : u16,
    surface_info_array      : *SurfaceInfoArray
) -> bool {
    if exchange_texture_flags & .SRGB {
        nvttSurfaceToLinearFromSrgb(nvtt_surface);
    }

    if exchange_texture_flags & .NORMAL_MAP {
        nvttSurfaceExpandNormals(nvtt_surface); // [0; 1] -> [-1; 1]
        nvttSurfaceNormalizeNormalMap(nvtt_surface);
    } else if has_alpha == .True {
        nvttSurfacePremultiplyAlpha(nvtt_surface);
    }

    for 1 .. head_mips_count_to_drop {
        nvtt_success := nvttSurfaceBuildNextMipmapDefaults(nvtt_surface, .Kaiser, min_texture_wh);
        if nvtt_success == .False {
            errorMessage("nvttSurfaceBuildNextMipmapDefaults has failed");
            return false;
        }

        if exchange_texture_flags & .NORMAL_MAP {
            nvttSurfaceNormalizeNormalMap(nvtt_surface);
        }
    }

    {
        surface_info := pushBack(surface_info_array);
        surface_info.surface = nvtt_surface;
        surface_info.face    = face_index;
    }

    for 1 .. mips_count_to_generate - 1 {
        nvtt_surface_copy := nvttSurfaceClone(surface_info_array.*[surface_info_array.count - 1].surface);

        surface_info := pushBack(surface_info_array);
        surface_info.surface = nvtt_surface_copy;
        surface_info.face    = face_index;
        surface_info.mip     = it;

        nvtt_success := nvttSurfaceBuildNextMipmapDefaults(nvtt_surface_copy, .Kaiser, min_texture_wh);
        if nvtt_success == .False {
            errorMessage("nvttSurfaceBuildNextMipmapDefaults has failed");
            return false;
        }

        if exchange_texture_flags & .NORMAL_MAP {
            nvttSurfaceNormalizeNormalMap(nvtt_surface_copy);
        }
    }

    return true;
}

#if !TEST_TEXTURES {
    outputHandler :: (data : *void, size : s32) -> NvttBoolean #c_call {
        push_context, defer_pop g_contextForOutputHandler;
        appendTextureFileData(context.pet.converter.texture_file, .{ count = size, data = data });
        return .True;
    }
}

DDS_HEADER :: struct {
    dwSize              : u32;
    dwFlags             : u32;
    dwHeight            : u32;
    dwWidth             : u32;
    dwPitchOrLinearSize : u32;
    dwDepth             : u32;
    dwMipMapCount       : u32;
    dwReserved1         : [11] u32;
    ddspf               : DDS_PIXELFORMAT;
    dwCaps              : u32;
    dwCaps2             : u32;
    dwCaps3             : u32;
    dwCaps4             : u32;
    dwReserved2         : u32;
}
#assert size_of(DDS_HEADER) == 124;

DDS_PIXELFORMAT :: struct {
    dwSize        : u32;
    dwFlags       : u32;
    dwFourCC      : u32;
    dwRGBBitCount : u32;
    dwRBitMask    : u32;
    dwGBitMask    : u32;
    dwBBitMask    : u32;
    dwABitMask    : u32;
};
#assert size_of(DDS_PIXELFORMAT) == 32;

DDS_HEADER_DXT10 :: struct {
    dxgiFormat        : DXGI_FORMAT;
    resourceDimension : DDS_DIMENSION;
    miscFlag          : u32;
    arraySize         : u32;
    miscFlags2        : u32;
}

DXGI_FORMAT :: enum u32 #specified {
    // sRGB
    R8G8B8A8_UNORM_SRGB :: 29;
    BC1_UNORM_SRGB      :: 72;
    BC2_UNORM_SRGB      :: 75;
    BC3_UNORM_SRGB      :: 78;
    B8G8R8A8_UNORM_SRGB :: 91;
    B8G8R8X8_UNORM_SRGB :: 93;
    BC7_UNORM_SRGB      :: 99;

    // HDR
    R32G32B32A32_FLOAT       :: 2;
    R32G32B32_FLOAT          :: 6;
    R16G16B16A16_FLOAT       :: 10;
    R32G32_FLOAT             :: 16;
    R32_FLOAT_X8X24_TYPELESS :: 21;
    R11G11B10_FLOAT          :: 26;
    R16G16_FLOAT             :: 34;
    R32_FLOAT                :: 41;
    R16_FLOAT                :: 54;
    R9G9B9E5_SHAREDEXP       :: 67;
    BC6H_TYPELESS            :: 94;
    BC6H_UF16                :: 95;
    BC6H_SF16                :: 96;
}

DDS_DIMENSION :: enum s32 #specified {
    TEXTURE1D :: 2;
    TEXTURE2D :: 3;
    TEXTURE3D :: 4;
}

DDS_MAGIC    : u32 : #char "D" | (#char "D" << 8) | (#char "S" << 16) | (#char " " << 24);
DXT10_FOURCC : u32 : #char "D" | (#char "X" << 8) | (#char "1" << 16) | (#char "0" << 24);
NVTT_FOURCC  : u32 : #char "N" | (#char "V" << 8) | (#char "T" << 16) | (#char "T" << 24);
DDPF_SRGB    : u32 : 0x4000_0000;
DDPF_NORMAL  : u32 : 0x8000_0000;

getExchangeTextureFlags :: (file_data : string, name : string, extension : string) -> (flags : ExchangeTextureFlags, array_size : u16) {
    flags      : ExchangeTextureFlags;
    array_size : u16;

    if extension == {
        case "png"; #through;
        case "jpg"; #through;
        case "jpeg";
            // All (most?) browsers assume that png images are stored in sRGB space,
            // so we do the same no matter if sRGB and iCCP chunks are presented or not.
            // The same for jpg. No HDR support, no texture array support.
            flags |= .SRGB;

        case "dds";
            assert((cast(*u32) file_data.data).* == DDS_MAGIC);

            dds_header := cast(*DDS_HEADER) (file_data.data + size_of(u32));
            assert(dds_header.dwSize == size_of(DDS_HEADER));
            assert(dds_header.ddspf.dwSize == size_of(DDS_PIXELFORMAT));

            if dds_header.dwReserved1[9] == NVTT_FOURCC {
                if dds_header.ddspf.dwFlags & DDPF_SRGB   then flags |= .SRGB;
                if dds_header.ddspf.dwFlags & DDPF_NORMAL then flags |= .NORMAL_MAP;
            }

            if dds_header.ddspf.dwFourCC == DXT10_FOURCC {
                dxt10_header := cast(*DDS_HEADER_DXT10) (dds_header + 1);

                if !(flags & .SRGB) {
                    if dxt10_header.dxgiFormat == {
                        case .R8G8B8A8_UNORM_SRGB; #through;
                        case .BC1_UNORM_SRGB;      #through;
                        case .BC2_UNORM_SRGB;      #through;
                        case .BC3_UNORM_SRGB;      #through;
                        case .B8G8R8A8_UNORM_SRGB; #through;
                        case .B8G8R8X8_UNORM_SRGB; #through;
                        case .BC7_UNORM_SRGB;
                            flags |= .SRGB;

                        case .R32G32B32A32_FLOAT;       #through;
                        case .R32G32B32_FLOAT;          #through;
                        case .R16G16B16A16_FLOAT;       #through;
                        case .R32G32_FLOAT;             #through;
                        case .R32_FLOAT_X8X24_TYPELESS; #through;
                        case .R11G11B10_FLOAT;          #through;
                        case .R16G16_FLOAT;             #through;
                        case .R32_FLOAT;                #through;
                        case .R16_FLOAT;                #through;
                        case .R9G9B9E5_SHAREDEXP;       #through;
                        case .BC6H_TYPELESS;            #through;
                        case .BC6H_UF16;                #through;
                        case .BC6H_SF16;
                            flags |= .HDR;
                    }
                }

                if dxt10_header.resourceDimension != .TEXTURE3D {
                    array_size = cast(u16) dxt10_header.arraySize;
                }
            }

        case;
            assertMessage("Unhandled extension: \"%\"", extension);
    }

    if !(flags & .NORMAL_MAP) {
        // heuristics
        if String.ends_with(name, "_n")
        || String.ends_with(name, "_norm")
        || String.ends_with(name, "_normal")
        || String.ends_with(name, "_normals") {
            flags |= .NORMAL_MAP;
        }
    }

    assert(flags & (.HDR | .NORMAL_MAP) != (.HDR | .NORMAL_MAP), "Normals cannot be stored in HDR format");
    assert(flags & (.SRGB | .HDR) != (.SRGB | .HDR), "Texture cannot be stored in HDR and sRGB formats at the same time");
    assert(!array_size || extension == "dds", "Expected that only DDS files support texture arrays");
    return flags, array_size;
}

#if TEST_TEXTURES {
    TEST_TEXTURES_FOLDER :: "../../../source/assets/textures/test/";

    makeTestTextureFilename :: (name : string) -> string {
        capacity := TEST_TEXTURES_FOLDER.count + name.count + ".dds\0".count;

        filename := string.{ data = pushToArena(*context.pet.arenas.per_frame, capacity) };
        appendToString(*filename, capacity, TEST_TEXTURES_FOLDER, name, ".dds\0");

        return filename;
    }
}

// @Cleanup: #TextureLoader.
g_contextForOutputHandler : *#Context;

#load "obj_mesh.jai";

#import "nvtt";
