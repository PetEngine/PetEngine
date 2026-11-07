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
        SOURCE_SRGB;   // Cannot be combined with NORMAL_MAP, MR_MAP, OCCLUSION_MAP
        DEST_SRGB;     // Cannot be combined with NORMAL_MAP, MR_MAP, OCCLUSION_MAP

        SOURCE_HDR;    // Cannot be combined with NORMAL_MAP, MR_MAP, OCCLUSION_MAP, ALPHA_BLEND. Must be used with DEST_HDR.
        DEST_HDR;      // Cannot be combined with NORMAL_MAP, MR_MAP, OCCLUSION_MAP, ALPHA_BLEND

        NORMAL_MAP;    // Cannot be combined with SOURCE_SRGB, DEST_SRGB, SOURCE_HDR, DEST_HDR, ALPHA_BLEND
        MR_MAP;        // Cannot be combined with SOURCE_SRGB, DEST_SRGB, SOURCE_HDR, DEST_HDR, ALPHA_BLEND, NORMAL_MAP, OCCLUSION_MAP
        OCCLUSION_MAP; // Cannot be combined with SOURCE_SRGB, DEST_SRGB, SOURCE_HDR, DEST_HDR, ALPHA_BLEND, NORMAL_MAP, MR_MAP

        ALPHA_BLEND;   // Cannot be combined with NORMAL_MAP, MR_MAP, OCCLUSION_MAP, SOURCE_HDR, DEST_HDR
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

        messageCallback :: (severity : nvtt.Severity, error : nvtt.Error, message : *u8, userData : *void) #c_call {
            push_context,defer_pop cast(*#Context) userData;

            if severity == {
                case .Info;    infoMessage("NVTT: %", to_string(message));
                case .Warning; warningMessage("NVTT: %", to_string(message));
                case .Error;   errorMessage("NVTT: %", to_string(message));
            }
        }
        debugCheck(nvtt.setMessageCallback(messageCallback, *context));

        nvtt.OutputOptions.Constructor(*textures_context.nvtt_output_options);
        defer nvtt.OutputOptions.Destructor(*textures_context.nvtt_output_options);

        nvtt_error_handler := PetNvttErrorHandler.{
            vtable      = *PET_NVTT_ERROR_HANDLER_VTABLE,
            jai_context = *context,
        };
        nvtt.OutputOptions.setErrorHandler(*textures_context.nvtt_output_options, *nvtt_error_handler);

        nvtt.OutputOptions.setOutputHeader(*textures_context.nvtt_output_options, TEST_TEXTURES);

        #if !TEST_TEXTURES {
            textures_context.nvtt_output_handler = PetNvttOutputHandler.{
                vtable      = *PET_NVTT_OUTPUT_HANDLER_VTABLE,
                jai_context = *context,
            };
            nvtt.OutputOptions.setOutputHandler(*textures_context.nvtt_output_options, *textures_context.nvtt_output_handler);
        }

        textures_context.cuda_supported = nvtt.isCudaSupported();
        if !textures_context.cuda_supported {
            warningMessage("CUDA is not supported. Conversion will take much more time since it will be done on CPU.");
        }

        nvtt.Context.Constructor(*textures_context.nvtt_context, textures_context.cuda_supported);
        defer nvtt.Context.Destructor(*textures_context.nvtt_context);

        assert(!textures_context.cuda_supported || nvtt.Context.isCudaAccelerationEnabled(*textures_context.nvtt_context));

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
    nvtt_context        : nvtt.Context;
    nvtt_output_options : nvtt.OutputOptions;
    #if !TEST_TEXTURES {
        nvtt_output_handler : PetNvttOutputHandler;
    }
    cuda_supported      : bool;

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
    surface     : nvtt.Surface;
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
        nvtt.OutputOptions.setFileName(*textures_context.nvtt_output_options, test_filename.data);
    }

    exchange_filename := makeExchangeTextureFilename(exchange_file_info.path);

    rule := TextureConversionRule.{};
    {
        ptr := Hash_Table.table_find_pointer(textures_context.conversion_rules, texture_name);
        if ptr then rule = ptr.*;
    }
    validateRule(rule);

    time_begin := Basic.current_time_monotonic();
    success := convertTextureNVTT(textures_context, *rule, exchange_filename, texture_name, extension);
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
    textures_context  : *TexturesContext,
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

    nvtt_surface : nvtt.Surface = ---;
    nvtt.Surface.Constructor(*nvtt_surface);
    defer nvtt.Surface.Destructor(*nvtt_surface);

    has_alpha : bool = ---;
    if !nvtt.Surface.loadFromMemory(*nvtt_surface, file_data.data, cast(u64) file_data.count, *has_alpha) {
        errorMessage("nvtt.Surface.loadFromMemory has failed");
        return false;
    }

    if textures_context.cuda_supported {
        nvtt.Surface.ToGPU(*nvtt_surface);
    }

    nvtt_cube_surface : nvtt.CubeSurface = ---;
    nvtt.CubeSurface.Constructor(*nvtt_cube_surface);
    defer nvtt.CubeSurface.Destructor(*nvtt_cube_surface);

    source_width  : u16;
    source_height : u16;
    source_depth  : u16;

    force_cube : bool; // @Cleanup: #ConversionRules.
    if nvtt.Surface.type(*nvtt_surface) == {
        case ._2D;
            source_width  = cast(u16) nvtt.Surface.width(*nvtt_surface);
            source_height = cast(u16) nvtt.Surface.height(*nvtt_surface);

            force_cube = String.starts_with(name, "skybox");

        case .Cube;
            force_cube = true;

        case ._3D;
            source_depth = cast(u16) nvtt.Surface.depth(*nvtt_surface);
            texture_file_header.depth = min(source_depth, rule.max_texture_depth);
            assert(!array_size, "Texture arrays cannot contain 3D textures");
    }

    if force_cube {
        texture_file_header.flags = .CUBE;

        nvtt.CubeSurface.fold(*nvtt_cube_surface, *nvtt_surface, .HorizontalCross);

        source_width  = cast(u16) nvtt.CubeSurface.edgeLength(*nvtt_cube_surface);
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

    nvtt_compression_options : nvtt.CompressionOptions = ---;
    nvtt.CompressionOptions.Constructor(*nvtt_compression_options);
    defer nvtt.CompressionOptions.Destructor(*nvtt_compression_options);

    if rule.flags & (.NORMAL_MAP | .MR_MAP) {
        // Converting normals from UNORM to SNORM introduces an extra quantization step which results in noticeable precision loss.
        // So we preserve them in UNORM format.
        texture_file_header.format = .BC5_UNORM;
        nvtt.CompressionOptions.setFormat(*nvtt_compression_options, .BC5);
        nvtt.CompressionOptions.setQuality(*nvtt_compression_options, .Normal);
    } else if rule.flags & .OCCLUSION_MAP {
        texture_file_header.format = .BC4_UNORM;
        nvtt.CompressionOptions.setFormat(*nvtt_compression_options, .BC4);
        nvtt.CompressionOptions.setQuality(*nvtt_compression_options, .Normal);
    } else if rule.flags & .DEST_HDR {
        texture_file_header.format = .BC6H_UFLOAT;
        nvtt.CompressionOptions.setFormat(*nvtt_compression_options, .BC6U);
        nvtt.CompressionOptions.setQuality(*nvtt_compression_options, .Normal);
    } else {
        texture_file_header.format = ifx rule.flags & .DEST_SRGB then .BC7_SRGB else .BC7_UNORM;
        nvtt.CompressionOptions.setFormat(*nvtt_compression_options, .BC7);
        nvtt.CompressionOptions.setQuality(*nvtt_compression_options, .Normal);
    }
    assert(texture_file_header.format != .UNKNOWN);

    surface_info_array : SurfaceInfoArray;
    defer for * surface_info_array {
        nvtt.Surface.Destructor(*it.surface);
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
            face := nvtt.CubeSurface.face(*nvtt_cube_surface, cast(s32) it);
            assert(face);

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
        if !generateMips(*nvtt_surface,
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

    if rule.flags & .NORMAL_MAP {
        for * surface_info_array {
            nvtt.Surface.packNormals(*it.surface);
        }
    } else if !(rule.flags & (.OCCLUSION_MAP | .MR_MAP)) {
        for * surface_info_array {
            if has_alpha && (rule.flags & .ALPHA_BLEND) {
                nvtt.Surface.demultiplyAlpha(*it.surface);
            }

            if rule.flags & .DEST_SRGB {
                nvtt.Surface.toSrgb(*it.surface);
            }
        }
    }

    //
    // Fill batch list
    //

    nvtt_batch_list : nvtt.BatchList = ---;
    nvtt.BatchList.Constructor(*nvtt_batch_list);
    defer nvtt.BatchList.Destructor(*nvtt_batch_list);

    for * surface_info_array {
        nvtt.BatchList.Append(*nvtt_batch_list, *it.surface, it.face, it.mip, *textures_context.nvtt_output_options);
    }

    //
    // Compress batch
    //

    #if TEST_TEXTURES {
        nvtt.Surface.setNormalMap(*nvtt_surface,                              rule.flags & .NORMAL_MAP);
        nvtt.OutputOptions.setSrgbFlag(*textures_context.nvtt_output_options, rule.flags & .DEST_SRGB);

        if texture_file_header.flags & .CUBE {
            if !nvtt.Context.outputHeader(*textures_context.nvtt_context,
                                          *nvtt_cube_surface,
                                          texture_file_header.mips_count,
                                          *nvtt_compression_options,
                                          *textures_context.nvtt_output_options) {
                errorMessage("nvtt.Context.outputHeader(CUBE) has failed");
                return false;
            }
        } else {
            if !nvtt.Context.outputHeader(*textures_context.nvtt_context,
                                          surface_info_array[0].surface,
                                          texture_file_header.mips_count,
                                          *nvtt_compression_options,
                                          *textures_context.nvtt_output_options) {
                errorMessage("nvtt.Context.outputHeader has failed");
                return false;
            }
        }
    } else {
        success : bool = ---;
        textures_context.nvtt_output_handler.texture_file, success = beginTextureFileSerialization(name);
        if !success return false;
        defer endTextureFileSerialization(*textures_context.nvtt_output_handler.texture_file);

        writeTextureFileHeader(*textures_context.nvtt_output_handler.texture_file, texture_file_header);
    }

    if !nvtt.Context.compress(*textures_context.nvtt_context, *nvtt_batch_list, *nvtt_compression_options) {
        errorMessage("nvtt.Context.compress(BatchList) has failed");
        return false;
    }

    return true;
}

generateMips :: (
    nvtt_surface            : *nvtt.Surface,
    face_index              : u8,
    rule                    : TextureConversionRule,
    has_alpha               : bool,
    head_mips_count_to_drop : u8,
    mips_count_to_generate  : u8,
    min_texture_dimension   : u16,
    surface_info_array      : *SurfaceInfoArray
) -> bool {
    if rule.flags & .NORMAL_MAP {
        nvtt.Surface.expandNormals(nvtt_surface, 2.0, -254.0 / 255.0); // https://www.ludicon.com/castano/blog/2026/02/normal-map-compression-revisited
        nvtt.Surface.normalizeNormalMap(nvtt_surface);
    } else if rule.flags & .MR_MAP {
        // https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#_material_pbrmetallicroughness_metallicroughnesstexture
        //
        // Swizzle:
        //     - metalness: B -> R
        //     - roughness: G -> G
        RED     :: 0;
        GREEN   :: 1;
        BLUE    :: 2;
        ALPHA   :: 3;
        ONE     :: 4;
        ZERO    :: 5;
        NEG_ONE :: 6;
        nvtt.Surface.swizzle(nvtt_surface, BLUE, GREEN, ZERO, ZERO);
    } else if !(rule.flags & .OCCLUSION_MAP) {
        if rule.flags & .SOURCE_SRGB {
            nvtt.Surface.toLinearFromSrgb(nvtt_surface);
        }

        if has_alpha && (rule.flags & .ALPHA_BLEND) {
            nvtt.Surface.premultiplyAlpha(nvtt_surface);
        }
    }

    for 1 .. head_mips_count_to_drop {
        if !nvtt.Surface.buildNextMipmap(nvtt_surface, .Kaiser, min_texture_dimension) {
            errorMessage("nvtt.Surface.buildNextMipmap has failed");
            return false;
        }

        if rule.flags & .NORMAL_MAP {
            nvtt.Surface.normalizeNormalMap(nvtt_surface);
        }
    }

    view := pushBack(surface_info_array, mips_count_to_generate);
    {
        nvtt.Surface.CopyConstructor(*view[0].surface, nvtt_surface);
        view[0].face = face_index;
    }

    for * toView(view.data + 1, view.count - 1) {
        it.face = face_index;
        it.mip  = cast(u8) (it_index + 1);

        {
            cloned_prev_surface := nvtt.Surface.clone(*it[-1].surface);
            defer nvtt.Surface.Destructor(*cloned_prev_surface);

            nvtt.Surface.CopyConstructor(*it.surface, *cloned_prev_surface);
        }

        if !nvtt.Surface.buildNextMipmap(*it.surface, .Kaiser, min_texture_dimension) {
            errorMessage("nvtt.Surface.buildNextMipmap has failed");
            return false;
        }

        if rule.flags & .NORMAL_MAP {
            nvtt.Surface.normalizeNormalMap(*it.surface);
        }
    }

    return true;
}

#if !TEST_TEXTURES {
    PetNvttOutputHandler :: struct {
        #as using base : nvtt.OutputHandler;
        jai_context    : *#Context;
        texture_file   : TextureFile;
    }

    PET_NVTT_OUTPUT_HANDLER_VTABLE :: nvtt.OutputHandler_VTable.{
        Destructor = (this : *nvtt.OutputHandler, flags : Msvc_Destructor_Flags = .NONE) #cpp_method {
        },

        beginImage = (this : *nvtt.OutputHandler, size : s32, width : s32, height : s32, depth : s32, face : s32, miplevel : s32) #cpp_method {
        },

        writeData = (this : *nvtt.OutputHandler, data : *void, size : s32) -> bool #cpp_method {
            handler := cast(*PetNvttOutputHandler, this);
            push_context,defer_pop handler.jai_context;
            appendTextureFileData(*handler.texture_file, .{ count = size, data = data });
            return true;
        },

        endImage = (this : *nvtt.OutputHandler) #cpp_method {
        },
    };
}

PetNvttErrorHandler :: struct {
    #as using base : nvtt.ErrorHandler;
    jai_context    : *#Context;
}

PET_NVTT_ERROR_HANDLER_VTABLE :: nvtt.ErrorHandler_VTable.{
    Destructor = (this : *nvtt.ErrorHandler, flags : Msvc_Destructor_Flags = .NONE) #cpp_method {
    },

    error = (this : *nvtt.ErrorHandler, e : nvtt.Error) #cpp_method {
        push_context,defer_pop cast(*PetNvttErrorHandler, this).jai_context;
        c_str := nvtt.errorString(e);
        errorMessage("%", to_string(c_str));
    },
};

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
    notSetTogether :: inline (flags : TextureConversionRule.Flags, subflags : TextureConversionRule.Flags) -> bool #no_context {
        return (flags & subflags) != subflags;
    }

    assert(notSetTogether(rule.flags, .NORMAL_MAP | .SOURCE_SRGB));
    assert(notSetTogether(rule.flags, .NORMAL_MAP | .DEST_SRGB));
    assert(notSetTogether(rule.flags, .NORMAL_MAP | .SOURCE_HDR));
    assert(notSetTogether(rule.flags, .NORMAL_MAP | .DEST_HDR));
    assert(notSetTogether(rule.flags, .NORMAL_MAP | .MR_MAP));
    assert(notSetTogether(rule.flags, .NORMAL_MAP | .OCCLUSION_MAP));
    assert(notSetTogether(rule.flags, .NORMAL_MAP | .ALPHA_BLEND));

    assert(notSetTogether(rule.flags, .MR_MAP | .SOURCE_SRGB));
    assert(notSetTogether(rule.flags, .MR_MAP | .DEST_SRGB));
    assert(notSetTogether(rule.flags, .MR_MAP | .SOURCE_HDR));
    assert(notSetTogether(rule.flags, .MR_MAP | .DEST_HDR));
    assert(notSetTogether(rule.flags, .MR_MAP | .OCCLUSION_MAP));
    assert(notSetTogether(rule.flags, .MR_MAP | .ALPHA_BLEND));

    assert(notSetTogether(rule.flags, .OCCLUSION_MAP | .SOURCE_SRGB));
    assert(notSetTogether(rule.flags, .OCCLUSION_MAP | .DEST_SRGB));
    assert(notSetTogether(rule.flags, .OCCLUSION_MAP | .SOURCE_HDR));
    assert(notSetTogether(rule.flags, .OCCLUSION_MAP | .DEST_HDR));
    assert(notSetTogether(rule.flags, .OCCLUSION_MAP | .ALPHA_BLEND));

    assert(notSetTogether(rule.flags, .SOURCE_SRGB | .SOURCE_HDR));
    assert(notSetTogether(rule.flags, .DEST_SRGB | .DEST_HDR));

    assert(notSetTogether(rule.flags, .ALPHA_BLEND | .SOURCE_HDR));
    assert(notSetTogether(rule.flags, .ALPHA_BLEND | .DEST_HDR));

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

#load "obj_model.jai";
#load "gltf_model.jai";

nvtt :: #import "nvtt";
#if !TEST_TEXTURES {
    using,only(Msvc_Destructor_Flags) Windows :: #import "Windows";
}
