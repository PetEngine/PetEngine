AssetConverter :: struct {
    VERSION :: 1;

    EXCHANGE_MODELS_FOLDER :: "../../../source/assets/exchange/models";
    RUNTIME_MODELS_FOLDER  :: "../../../source/assets/runtime/models";

    EXCHANGE_TEXTURES_FOLDER :: "../../../source/assets/exchange/textures";
    RUNTIME_TEXTURES_FOLDER  :: "../../../source/assets/runtime/textures";
}

// @TODO: #ConversionRules.
TextureConversionRule :: struct {
    Flags :: enum_flags u8 {
        SOURCE_SRGB; // Cannot be combined with NORMAL_MAP
        DEST_SRGB;   // Cannot be combined with NORMAL_MAP

        SOURCE_HDR;  // Cannot be combined with NORMAL_MAP and ALPHA_BLEND. Must be used with DEST_HDR.
        DEST_HDR;    // Cannot be combined with NORMAL_MAP and ALPHA_BLEND

        NORMAL_MAP;  // Cannot be combined with SOURCE_SRGB, DEST_SRGB, SOURCE_HDR, DEST_HDR and ALPHA_BLEND

        ALPHA_BLEND; // Cannot be combined with NORMAL_MAP, SOURCE_HDR and DEST_HDR
    }

    max_texture_width  : u16 = 4096;
    max_texture_height : u16 = 4096;
    max_texture_depth  : u16 = 2048;

    min_texture_width  : u16 = 4;
    min_texture_height : u16 = 4;
    min_texture_depth  : u16 = 2;

    flags : Flags;
}

convertExchangeAssetsToRuntime :: () {
    models_context : ModelsContext;
    defer if models_context.texture_conversion_rules.entries.data {
        for models_context.texture_conversion_rules {
            Basic.free(it_index);
        }
        Hash_Table.deinit(*models_context.texture_conversion_rules);
    }
    {
        models_begin := Basic.current_time_monotonic();
        defer models_context.duration = Basic.to_float64_seconds(Basic.current_time_monotonic() - models_begin);

        error := enumerateFiles(AssetConverter.EXCHANGE_MODELS_FOLDER, convertModelsCallback, *models_context, recursively = true);
        if error == {
            case .FILE_NOT_FOUND; #through;
            case .PATH_NOT_FOUND;
                verboseMessage("Exchange models folder is not found: %", AssetConverter.EXCHANGE_MODELS_FOLDER);
            case .NONE;
                // everything is good
            case;
                assertMessage("enumerateFiles(%) has failed", AssetConverter.EXCHANGE_MODELS_FOLDER);
        }
    }

    textures_context := TexturesContext.{
        conversion_rules = *models_context.texture_conversion_rules
    };
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

        error := enumerateFiles(AssetConverter.EXCHANGE_TEXTURES_FOLDER, convertTexturesCallback, *textures_context, recursively = true);
        if error == {
            case .FILE_NOT_FOUND; #through;
            case .PATH_NOT_FOUND;
                verboseMessage("Exchange textures folder is not found: %", AssetConverter.EXCHANGE_TEXTURES_FOLDER);
            case .NONE;
                // everything is good
            case;
                assertMessage("enumerateFiles(%) has failed", AssetConverter.EXCHANGE_TEXTURES_FOLDER);
        }
    } else {
        verboseMessage("Exchange textures folder is not found: %", AssetConverter.EXCHANGE_TEXTURES_FOLDER);
    }

    formatStatisticsInt :: inline (value : Any) -> Basic.FormatInt {
        assert(value.type.type == .INTEGER);
        assert(!cast(*Type_Info_Integer, value.type).signed);
        format := context.print_style.default_format_int;
        format.value          = value;
        format.minimum_digits = 4;
        format.padding        = #char " ";
        if cast(*u64, value.value_pointer).* < 1000 {
            format.comma_string = "";
        }
        return format;
    }

    formatStatisticsFloat :: inline (value : Any) -> Basic.FormatFloat {
        assert(value.type.type == .FLOAT);
        format := context.print_style.default_format_float;
        format.value          = value;
        format.width          = 11;
        format.trailing_width = 6;
        return format;
    }

    infoMessage(#string END
AssetConverter statistics:
    | Models   | total: % | converted: % | failed: % | skipped: % | duration (s): % |
    | Textures | total: % | converted: % | failed: % | skipped: % | duration (s): % |
END,
                formatStatisticsInt(models_context.total + models_context.skipped),
                formatStatisticsInt(models_context.converted),
                formatStatisticsInt(models_context.total - models_context.converted),
                formatStatisticsInt(models_context.skipped),
                formatStatisticsFloat(models_context.duration),

                formatStatisticsInt(textures_context.total + textures_context.skipped),
                formatStatisticsInt(textures_context.converted),
                formatStatisticsInt(textures_context.total - textures_context.converted),
                formatStatisticsInt(textures_context.skipped),
                formatStatisticsFloat(textures_context.duration)
    );
}

makeRuntimeModelFilename :: (name : string) -> string {
    capacity := AssetConverter.RUNTIME_MODELS_FOLDER.count + "/".count + name.count + ".model".count;

    filename := string.{ data = pushToArena(*context.pet.arenas.per_frame, capacity) };
    appendToString(*filename, capacity, AssetConverter.RUNTIME_MODELS_FOLDER, "/", name, ".model");

    return filename;
}

makeRuntimeTextureFilename :: (name : string) -> string {
    capacity := AssetConverter.RUNTIME_TEXTURES_FOLDER.count + "/".count + name.count + ".texture".count;

    filename := string.{ data = pushToArena(*context.pet.arenas.per_frame, capacity) };
    appendToString(*filename, capacity, AssetConverter.RUNTIME_TEXTURES_FOLDER, "/", name, ".texture");

    return filename;
}

#load "model_file.jai";
#load "texture_file.jai";

#scope_file

TEST_TEXTURES :: false;

TexturesContext :: struct {
    nvtt_context        : *NvttContext;
    nvtt_output_options : *NvttOutputOptions;
    cuda_supported      : NvttBoolean;

    conversion_rules : *Hash_Table.Table(string, TextureConversionRule);

    using statistics : Statistics;
}

ModelsContext :: struct {
    texture_conversion_rules : Hash_Table.Table(string, TextureConversionRule);
    using statistics : Statistics;
}

Statistics :: struct {
    converted : u64;
    skipped   : u64;
    duration  : f64;
    total     : u64;
}

SurfaceInfo :: struct {
    surface     : *NvttSurface;
    array_layer : u16;
    face        : u8;
    mip         : u8;
}
SurfaceInfoArray :: StaticArray(SurfaceInfo, 6 * Texture.MAX_MIPS_SUPPORTED);

//
// Models
//

convertModelsCallback :: (models_context : *ModelsContext, exchange_file_info : File.Info(.RELATIVE)) -> EnumerateFilesCallbackResult {
    VALID_EXCHANGE_EXTENSIONS :: string.[
        "gltf",
        "obj",
    ];

    SILENTLY_IGNORE_EXTENSIONS :: string.[
        "bin"
    ];

    extension, found := String.path_extension(exchange_file_info.path);
    if !found || !Basic.array_find(VALID_EXCHANGE_EXTENSIONS, extension) {
        if !Basic.array_find(SILENTLY_IGNORE_EXTENSIONS, extension) {
            errorMessage("Model \"%\" is not supported by AssetConverter: invalid extension. Valid extensions are: %",
                         exchange_file_info.path,
                         VALID_EXCHANGE_EXTENSIONS);
        }
        return .CONTINUE;
    }

    autoResetPerFrameArenas();

    model_name := string.{
        exchange_file_info.path.count - (".".count + extension.count),
        exchange_file_info.path.data
    };

    runtime_filename := makeRuntimeModelFilename(model_name);

    runtime_file_info, error := getFileInfo(runtime_filename);
    assert(error == .NONE || error == .FILE_NOT_FOUND || error == .PATH_NOT_FOUND);

    if runtime_file_info.last_write_time >= exchange_file_info.last_write_time {
        runtime_file:, error = openFile(runtime_filename, .READ | .SHARED_READ | .EXISTS);
        assert(error == .NONE);
        defer closeFile(*runtime_file);

        header : ModelFile.Header = ---;
        readFile(runtime_file, *header);
        if header.version == ModelFile.VERSION {
            models_context.skipped += 1;
            return .CONTINUE;
        }
    }

    models_context.total += 1;

    exchange_filename := makeExchangeModelFilename(exchange_file_info.path);

    time_begin := Basic.current_time_monotonic();
    success : bool;
    if extension == {
        case "gltf"; success = convertGLTFModel(exchange_filename, model_name, *models_context.texture_conversion_rules);
        case "obj";  success = convertObjModel(exchange_filename, model_name);
        case;        notImplemented(true);
    }
    duration := Basic.to_float64_seconds(Basic.current_time_monotonic() - time_begin);

    if success {
        models_context.converted += 1;
        infoMessage("\"%1.%2\" has been converted to \"%1.model\" in %3 seconds", model_name, extension, duration);
    } else {
        errorMessage("Failed to convert \"%1.%2\" to \"%1.model\"", model_name, extension);
    }

    return .CONTINUE;
}

//
// Textures
//

convertTexturesCallback :: (textures_context : *TexturesContext, exchange_file_info : File.Info(.RELATIVE)) -> EnumerateFilesCallbackResult {
    VALID_EXCHANGE_EXTENSIONS :: string.[
        "png",
        "dds",
        "jpg",
        "jpeg",
    ];

    extension, found := String.path_extension(exchange_file_info.path);
    if !found || !Basic.array_find(VALID_EXCHANGE_EXTENSIONS, extension) {
        errorMessage("Texture \"%\" is not supported by AssetConverter: invalid extension. Valid extensions are: %",
                     exchange_file_info.path,
                     VALID_EXCHANGE_EXTENSIONS);
        return .CONTINUE;
    }

    autoResetPerFrameArenas();

    texture_name := string.{
        exchange_file_info.path.count - (".".count + extension.count),
        exchange_file_info.path.data
    };

    #if TEST_TEXTURES {
        test_filename := makeTestTextureFilename(texture_name);

        test_file_info, error := getFileInfo(test_filename);
        assert(error == .NONE || error == .FILE_NOT_FOUND || error == .PATH_NOT_FOUND);

        if test_file_info.last_write_time >= exchange_file_info.last_write_time {
            return .CONTINUE;
        }

        if error == .PATH_NOT_FOUND {
            createDirectoryFor(test_filename);
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

    exchange_filename := makeExchangeTextureFilename(exchange_file_info.path);

    rule := TextureConversionRule.{};
    {
        ptr := Hash_Table.table_find_pointer(textures_context.conversion_rules, texture_name);
        if ptr then rule = ptr.*;
    }
    validateRule(rule);

    time_begin := Basic.current_time_monotonic();
    success := convertTextureNVTT(textures_context.*, *rule, exchange_filename, texture_name, extension);
    duration := Basic.to_float64_seconds(Basic.current_time_monotonic() - time_begin);

    if success {
        textures_context.converted += 1;
        #if TEST_TEXTURES {
            infoMessage("\"%1.%2\" has been converted to \"%1.dds\" in %3 seconds", texture_name, extension, duration);
        } else {
            infoMessage("\"%1.%2\" has been converted to \"%1.texture\" in %3 seconds", texture_name, extension, duration);
        }
    } else #if TEST_TEXTURES {
        errorMessage("Failed to convert \"%1.%2\" to \"%1.dds\"", texture_name, extension);
    } else {
        errorMessage("Failed to convert \"%1.%2\" to \"%1.texture\"", texture_name, extension);
    }

    return .CONTINUE;
}

convertTextureNVTT :: (
    textures_context  : TexturesContext,
    rule              : *TextureConversionRule,
    exchange_filename : string,
    name              : string,
    extension         : string
) -> bool {
    file_data, error := readEntireFile(exchange_filename);
    assert(error == .NONE);

    array_size := adjustRuleFlags(file_data, name, extension, rule);
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
                                              *has_alpha);
    if nvtt_success == .False {
        errorMessage("nvttSurfaceLoadFromMemory has failed");
        return false;
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
    min_texture_depth  := min(source_depth,  rule.min_texture_depth);

    tail_mips_count_to_drop := maxMipsCount(min_texture_width, min_texture_height, min_texture_depth) - 1;

    texture_file_header.mips_count = maxMipsCount(texture_file_header.width, texture_file_header.height, texture_file_header.depth);
    texture_file_header.mips_count = max(texture_file_header.mips_count - tail_mips_count_to_drop, 1);

    nvtt_compression_options := nvttCreateCompressionOptions();
    defer nvttDestroyCompressionOptions(nvtt_compression_options);
    if rule.flags & .DEST_HDR {
        texture_file_header.format = .BC6H_UFLOAT;
        nvttSetCompressionOptionsFormat(nvtt_compression_options, .BC6U);
        nvttSetCompressionOptionsQuality(nvtt_compression_options, .Normal);
    } else {
        if has_alpha == .True && (rule.flags & .NORMAL_MAP) {
            warningMessage("Normal map \"%\" contains alpha channel. Is it intended?", name);
        }
        texture_file_header.format = ifx rule.flags & .DEST_SRGB then .BC7_SRGB else .BC7_UNORM;
        nvttSetCompressionOptionsFormat(nvtt_compression_options, .BC7);
        nvttSetCompressionOptionsQuality(nvtt_compression_options, .Normal);
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

    min_texture_dimension := min(min_texture_width, min_texture_height, min_texture_depth);

    if texture_file_header.flags & .CUBE {
        for 0 .. 5 {
            face := nvttCubeSurfaceFace(nvtt_cube_surface, cast(s32) it);
            if !generateMips(face,
                             cast(u8) it,
                             rule.*,
                             has_alpha,
                             head_mips_count_to_drop,
                             texture_file_header.mips_count,
                             min_texture_dimension,
                             *surface_info_array) {
                return false;
            }
        }
    } else {
        if !generateMips(nvtt_surface,
                         0,
                         rule.*,
                         has_alpha,
                         head_mips_count_to_drop,
                         texture_file_header.mips_count,
                         min_texture_dimension,
                         *surface_info_array) {
            return false;
        }
    }

    for surface_info_array {
        if rule.flags & .NORMAL_MAP {
            nvttSurfacePackNormals(it.surface);
        } else {
            if has_alpha == .True && (rule.flags & .ALPHA_BLEND) {
                nvttSurfaceDemultiplyAlpha(it.surface);
            }

            if rule.flags & .DEST_SRGB {
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
        nvttSetSurfaceNormalMap(nvtt_surface,                              ifx rule.flags & .NORMAL_MAP then .True else .False);
        nvttSetOutputOptionsSrgbFlag(textures_context.nvtt_output_options, ifx rule.flags & .DEST_SRGB  then .True else .False);

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

    return true;
}

generateMips :: (
    nvtt_surface            : *NvttSurface,
    face_index              : u8,
    rule                    : TextureConversionRule,
    has_alpha               : NvttBoolean,
    head_mips_count_to_drop : u8,
    mips_count_to_generate  : u8,
    min_texture_dimension   : u16,
    surface_info_array      : *SurfaceInfoArray
) -> bool {
    if rule.flags & .NORMAL_MAP {
        nvttSurfaceExpandNormals(nvtt_surface);
        nvttSurfaceNormalizeNormalMap(nvtt_surface);
    } else {
        if rule.flags & .SOURCE_SRGB {
            nvttSurfaceToLinearFromSrgb(nvtt_surface);
        }

        if has_alpha == .True && (rule.flags & .ALPHA_BLEND) {
            nvttSurfacePremultiplyAlpha(nvtt_surface);
        }
    }

    for 1 .. head_mips_count_to_drop {
        nvtt_success := nvttSurfaceBuildNextMipmapDefaults(nvtt_surface, .Kaiser, min_texture_dimension);
        if nvtt_success == .False {
            errorMessage("nvttSurfaceBuildNextMipmapDefaults has failed");
            return false;
        }

        if rule.flags & .NORMAL_MAP {
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

        nvtt_success := nvttSurfaceBuildNextMipmapDefaults(nvtt_surface_copy, .Kaiser, min_texture_dimension);
        if nvtt_success == .False {
            errorMessage("nvttSurfaceBuildNextMipmapDefaults has failed");
            return false;
        }

        if rule.flags & .NORMAL_MAP {
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

adjustRuleFlags :: (file_data : string, name : string, extension : string, rule : *TextureConversionRule) -> (array_size : u16) {
    array_size : u16;

    if extension == "dds" {
        assert((cast(*u32) file_data.data).* == DDS_MAGIC);

        dds_header := cast(*DDS_HEADER) (file_data.data + size_of(u32));
        assert(dds_header.dwSize == size_of(DDS_HEADER));
        assert(dds_header.ddspf.dwSize == size_of(DDS_PIXELFORMAT));

        if dds_header.dwReserved1[9] == NVTT_FOURCC {
            if dds_header.ddspf.dwFlags & DDPF_SRGB   then rule.flags |= .SOURCE_SRGB;
            if dds_header.ddspf.dwFlags & DDPF_NORMAL then rule.flags |= .NORMAL_MAP;
        }

        if dds_header.ddspf.dwFourCC == DXT10_FOURCC {
            dxt10_header := cast(*DDS_HEADER_DXT10) (dds_header + 1);

            if !(rule.flags & .SOURCE_SRGB) {
                if dxt10_header.dxgiFormat == {
                    case .R8G8B8A8_UNORM_SRGB; #through;
                    case .BC1_UNORM_SRGB;      #through;
                    case .BC2_UNORM_SRGB;      #through;
                    case .BC3_UNORM_SRGB;      #through;
                    case .B8G8R8A8_UNORM_SRGB; #through;
                    case .B8G8R8X8_UNORM_SRGB; #through;
                    case .BC7_UNORM_SRGB;
                        rule.flags |= .SOURCE_SRGB;

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
                        rule.flags |= .SOURCE_HDR;
                }
            }

            if dxt10_header.resourceDimension != .TEXTURE3D {
                array_size = cast(u16) dxt10_header.arraySize;
            }
        }
    }

    // heuristics
    if !(rule.flags & .NORMAL_MAP) {
        if String.ends_with(name, "_n")
        || String.ends_with(name, "_norm")
        || String.ends_with(name, "_normal")
        || String.ends_with(name, "_normals") {
            rule.flags |= .NORMAL_MAP;
        }
    }

    // heuristics
    if !(rule.flags & (.SOURCE_SRGB | .SOURCE_HDR)) {
        if String.ends_with(name, "_color")
        || String.ends_with(name, "_a") || String.ends_with(name, "_albedo")
        || String.ends_with(name, "_e") || String.ends_with(name, "_emissive") {
            rule.flags |= .SOURCE_SRGB;
        }
    }

    validateRule(rule.*);
    assert(!array_size || extension == "dds", "It is expected that only DDS files support texture arrays");
    return array_size;
}

validateRule :: (rule : TextureConversionRule) {
    assert(rule.flags & (.NORMAL_MAP | .SOURCE_SRGB) != (.NORMAL_MAP | .SOURCE_SRGB));
    assert(rule.flags & (.NORMAL_MAP | .DEST_SRGB) != (.NORMAL_MAP | .DEST_SRGB));
    assert(rule.flags & (.NORMAL_MAP | .SOURCE_HDR) != (.NORMAL_MAP | .SOURCE_HDR));
    assert(rule.flags & (.NORMAL_MAP | .DEST_HDR) != (.NORMAL_MAP | .DEST_HDR));
    assert(rule.flags & (.NORMAL_MAP | .ALPHA_BLEND) != (.NORMAL_MAP | .ALPHA_BLEND));

    assert(rule.flags & (.SOURCE_SRGB | .SOURCE_HDR) != (.SOURCE_SRGB | .SOURCE_HDR));
    assert(rule.flags & (.DEST_SRGB | .DEST_HDR) != (.DEST_SRGB | .DEST_HDR));

    assert(rule.flags & (.ALPHA_BLEND | .SOURCE_HDR) != (.ALPHA_BLEND | .SOURCE_HDR));
    assert(rule.flags & (.ALPHA_BLEND | .DEST_HDR) != (.ALPHA_BLEND | .DEST_HDR));

    assert((rule.flags & .DEST_HDR) || !(rule.flags & .SOURCE_HDR));
}

//
// Paths
//

#if TEST_TEXTURES {
    TEST_TEXTURES_FOLDER :: "../../../source/assets/test/textures/";

    makeTestTextureFilename :: (name : string) -> string {
        capacity := TEST_TEXTURES_FOLDER.count + name.count + ".dds\0".count;

        filename := string.{ data = pushToArena(*context.pet.arenas.per_frame, capacity) };
        appendToString(*filename, capacity, TEST_TEXTURES_FOLDER, name, ".dds\0");

        return filename;
    }
}

makeExchangeModelFilename :: (relative_filename : string) -> string {
    capacity := AssetConverter.EXCHANGE_MODELS_FOLDER.count + "/".count + relative_filename.count;

    filename := string.{ data = pushToArena(*context.pet.arenas.per_frame, capacity) };
    appendToString(*filename, capacity, AssetConverter.EXCHANGE_MODELS_FOLDER, "/", relative_filename);

    return filename;
}

makeExchangeTextureFilename :: (relative_filename : string) -> string {
    capacity := AssetConverter.EXCHANGE_TEXTURES_FOLDER.count + "/".count + relative_filename.count;

    filename := string.{ data = pushToArena(*context.pet.arenas.per_frame, capacity) };
    appendToString(*filename, capacity, AssetConverter.EXCHANGE_TEXTURES_FOLDER, "/", relative_filename);

    return filename;
}

// @Cleanup: #TextureLoader.
g_contextForOutputHandler : *#Context;

#load "obj_model.jai";
#load "gltf_model.jai";

#import "nvtt";
