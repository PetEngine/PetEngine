convertGLTFModel :: (
    exchange_filename        : string,
    name                     : string,
    texture_conversion_rules : *Hash_Table.Table(string, TextureConversionRule)
) -> bool {
    FAILURE_CODE :: #code { `return false; };

    file_data, error := readEntireFile(exchange_filename);
    gltfCheck(error == .NONE, FAILURE_CODE);

    success, parsed_data := json_parse_string(file_data);
    if !success return false;
    defer json_free(parsed_data);

    gltf:, success = getAs(parsed_data, *JSON_Object);
    gltfCheck(success, FAILURE_CODE);

    // Check GLTF version
    {
        gltf_asset, status := getChild(gltf, "asset", *JSON_Object);
        if status != .SUCCESS return false;

        version:, status = getChild(gltf_asset, "version", string);
        if status != .SUCCESS return false;
        gltfCheck(version == "2.0", FAILURE_CODE, "Model \"%\" is a GLTF v% model, we support only GLTF v2.0", version);
    }

    textures:, success = parseTextures(gltf, name);
    defer if textures.data then Basic.array_reset(*textures);
    if !success return false;

    materials:, success = parseMaterials(gltf);
    defer if materials.data then Basic.array_reset(*materials);
    if !success return false;

    // Make texture convertion rules
    for materials {
        if it.texture_index_normal == ModelFile.INVALID_INDEX {
            continue;
        }

        filename := textures[it.texture_index_normal];

        if Hash_Table.table_contains(texture_conversion_rules, filename) {
            continue;
        }

        rule := TextureConversionRule.{ normal_map = true };
        Hash_Table.table_add(texture_conversion_rules, Basic.copy_string(filename), rule);
    }

    buffers:, success = parseBuffers(gltf, exchange_filename);
    if !success return false;

    gltf_meshes:, success = parseMeshes(gltf);
    defer if gltf_meshes.data then Basic.array_reset(*gltf_meshes);
    if !success return false;

    vertices:, indices:, meshes:, success = uniteBuffersAndRemapMeshes(buffers, gltf_meshes);
    defer {
        if vertices.data then Basic.array_reset(*vertices);
        if indices.data  then Basic.array_reset(*indices);
    }
    if !success return false;

    if !serializeModel(name, textures, materials, meshes, vertices, indices) {
        return false;
    }

    return true;
}

#scope_file

GLTF_Buffer  :: [] u8;
GLTF_Buffers :: StaticArray(GLTF_Buffer, 255);

GLTF_Mesh :: struct {
    Stream :: enum u8 {
        INDEX;    // optional
        POSITION; // required
        NORMAL;   // optional
        TEXCOORD; // optional
    }
    MAX_STREAMS :: #run Basic.enum_highest_value(Stream) + 1;

    count_by_stream           : [MAX_STREAMS] s64;
    offset_in_bytes_by_stream : [MAX_STREAMS] s64;
    type_by_stream            : [MAX_STREAMS] Type;
    buffer_index_by_stream    : [MAX_STREAMS] u8;
    read_stride_by_stream     : [MAX_STREAMS] u8;

    material_index : u16 = ModelFile.INVALID_INDEX;

    mesh_to_model : m3x4 = IDENTITY_3X4;
    model_to_mesh : m3x4 = IDENTITY_3X4;
}
#assert GLTF_Buffers.capacity <= maxOf(type_of(GLTF_Mesh.buffer_index_by_stream[0]));

gltfCheck :: (
    $expression            : Code,
    $what_to_do_on_failure : Code,
    $format                := "",
    args                   : ..Any,
    location               := #caller_location
) #expand #no_debug {
    if !(#insert expression) {
        absolute_path := getAbsolutePath(location.fully_pathed_filename);

        #if format.count > 0 {
            if args.count > 0 {
                builder := Basic.String_Builder.{ allocator = Basic.temp };
                Basic.print(*builder, format, ..args);

                message := Basic.builder_to_string(*builder,, allocator = Basic.temp);
                errorMessage("%(%,%): %", absolute_path, location.line_number, location.character_number, message);
            } else {
                errorMessage("%(%,%): %", absolute_path, location.line_number, location.character_number, format);
            }
        } else {
            EXPRESSION :: #run codeToString(expression);
            errorMessage("%(%,%): % has failed", absolute_path, location.line_number, location.character_number, EXPRESSION);
        }

        #insert what_to_do_on_failure;
    }
}

ParseStatus :: enum u8 {
    FAIL;
    SUCCESS;
    CHILD_NOT_FOUND;
}

getChild :: (parent : *JSON_Object, name : string, $type : Type, $optional := false) -> type, ParseStatus {
    result       : type;
    FAILURE_CODE :: #code { `return result, .FAIL; };

    child := Hash_Table.table_find_pointer(parent, name);

    #if optional {
        if !child return result, .CHILD_NOT_FOUND;
    } else {
        gltfCheck(child, FAILURE_CODE, "% is not found", name);
    }

    result=, success := getAs(child.*, type);
    return result, ifx success then .SUCCESS else .FAIL;
}

getAs :: (child : JSON_Value, $type : Type) -> type, bool {
    result       : type;
    FAILURE_CODE :: #code { `return result, false; };

    #if type == {
        case bool;
            gltfCheck(child.type == .BOOLEAN, FAILURE_CODE);
            result = child.boolean;

        case u8;
            gltfCheck(child.type == .NUMBER, FAILURE_CODE);
            gltfCheck(cast(f64) minOf(type) <= child.number && child.number <= cast(f64) maxOf(type), FAILURE_CODE);
            result = cast(type) child.number;

        case s8;
            gltfCheck(child.type == .NUMBER, FAILURE_CODE);
            gltfCheck(cast(f64) minOf(type) <= child.number && child.number <= cast(f64) maxOf(type), FAILURE_CODE);
            result = cast(type) child.number;

        case u16;
            gltfCheck(child.type == .NUMBER, FAILURE_CODE);
            gltfCheck(cast(f64) minOf(type) <= child.number && child.number <= cast(f64) maxOf(type), FAILURE_CODE);
            result = cast(type) child.number;

        case s16;
            gltfCheck(child.type == .NUMBER, FAILURE_CODE);
            gltfCheck(cast(f64) minOf(type) <= child.number && child.number <= cast(f64) maxOf(type), FAILURE_CODE);
            result = cast(type) child.number;

        case u32;
            gltfCheck(child.type == .NUMBER, FAILURE_CODE);
            gltfCheck(cast(f64) minOf(type) <= child.number && child.number <= cast(f64) maxOf(type), FAILURE_CODE);
            result = cast(type) child.number;

        case s32;
            gltfCheck(child.type == .NUMBER, FAILURE_CODE);
            gltfCheck(cast(f64) minOf(type) <= child.number && child.number <= cast(f64) maxOf(type), FAILURE_CODE);
            result = cast(type) child.number;

        case u64;
            gltfCheck(child.type == .NUMBER, FAILURE_CODE);
            gltfCheck(cast(f64) minOf(type) <= child.number && child.number <= cast(f64) maxOf(type), FAILURE_CODE);
            result = cast(type) child.number;

        case s64;
            gltfCheck(child.type == .NUMBER, FAILURE_CODE);
            gltfCheck(cast(f64) minOf(type) <= child.number && child.number <= cast(f64) maxOf(type), FAILURE_CODE);
            result = cast(type) child.number;

        case f32;
            gltfCheck(child.type == .NUMBER, FAILURE_CODE);
            gltfCheck(cast(f64) minOf(type) <= child.number && child.number <= cast(f64) maxOf(type), FAILURE_CODE);
            result = cast(type) child.number;

        case f64;
            gltfCheck(child.type == .NUMBER, FAILURE_CODE);
            gltfCheck(minOf(type) <= child.number && child.number <= maxOf(type), FAILURE_CODE);
            result = child.number;

        case string;
            gltfCheck(child.type == .STRING, FAILURE_CODE);
            result = child.str;

        case [] JSON_Value;
            gltfCheck(child.type == .ARRAY, FAILURE_CODE);
            result = child.array;

        case *JSON_Object;
            gltfCheck(child.type == .OBJECT, FAILURE_CODE);
            result = child.object;

        //
        // Vectors are stored as arrays
        //

        case v2f;
            gltfCheck(child.type == .ARRAY, FAILURE_CODE);
            gltfCheck(child.array.count == result.e.count, FAILURE_CODE);
            for child.array {
                gltfCheck(it.type == .NUMBER, FAILURE_CODE);
                result.e[it_index] = cast(f32) it.number;
            }

        case v2s;
            gltfCheck(child.type == .ARRAY, FAILURE_CODE);
            gltfCheck(child.array.count == result.e.count, FAILURE_CODE);
            for child.array {
                gltfCheck(it.type == .NUMBER, FAILURE_CODE);
                result.e[it_index] = cast(s32) it.number;
            }

        case v2u;
            gltfCheck(child.type == .ARRAY, FAILURE_CODE);
            gltfCheck(child.array.count == result.e.count, FAILURE_CODE);
            for child.array {
                gltfCheck(it.type == .NUMBER, FAILURE_CODE);
                result.e[it_index] = cast(u32) it.number;
            }

        case v3f;
            gltfCheck(child.type == .ARRAY, FAILURE_CODE);
            gltfCheck(child.array.count == result.e.count, FAILURE_CODE);
            for child.array {
                gltfCheck(it.type == .NUMBER, FAILURE_CODE);
                result.e[it_index] = cast(f32) it.number;
            }

        case v3s;
            gltfCheck(child.type == .ARRAY, FAILURE_CODE);
            gltfCheck(child.array.count == result.e.count, FAILURE_CODE);
            for child.array {
                gltfCheck(it.type == .NUMBER, FAILURE_CODE);
                result.e[it_index] = cast(s32) it.number;
            }

        case v3u;
            gltfCheck(child.type == .ARRAY, FAILURE_CODE);
            gltfCheck(child.array.count == result.e.count, FAILURE_CODE);
            for child.array {
                gltfCheck(it.type == .NUMBER, FAILURE_CODE);
                result.e[it_index] = cast(u32) it.number;
            }

        case v4f;
            gltfCheck(child.type == .ARRAY, FAILURE_CODE);
            gltfCheck(child.array.count == result.e.count, FAILURE_CODE);
            for child.array {
                gltfCheck(it.type == .NUMBER, FAILURE_CODE);
                result.e[it_index] = cast(f32) it.number;
            }

        case v4s;
            gltfCheck(child.type == .ARRAY, FAILURE_CODE);
            gltfCheck(child.array.count == result.e.count, FAILURE_CODE);
            for child.array {
                gltfCheck(it.type == .NUMBER, FAILURE_CODE);
                result.e[it_index] = cast(s32) it.number;
            }

        case v4u;
            gltfCheck(child.type == .ARRAY, FAILURE_CODE);
            gltfCheck(child.array.count == result.e.count, FAILURE_CODE);
            for child.array {
                gltfCheck(it.type == .NUMBER, FAILURE_CODE);
                result.e[it_index] = cast(u32) it.number;
            }

        //
        // Matrices are stored as arrays in column-major order
        //

        case m2x2;
            gltfCheck(child.type == .ARRAY, FAILURE_CODE);
            gltfCheck(child.array.count == result.flat.count, FAILURE_CODE);
            for child.array { gltfCheck(it.type == .NUMBER, FAILURE_CODE); }
            result.e00 = cast(f32) child.array[0].number;
            result.e10 = cast(f32) child.array[1].number;
            result.e01 = cast(f32) child.array[2].number;
            result.e11 = cast(f32) child.array[3].number;

        case m3x3;
            gltfCheck(child.type == .ARRAY, FAILURE_CODE);
            gltfCheck(child.array.count == result.flat.count, FAILURE_CODE);
            for child.array { gltfCheck(it.type == .NUMBER, FAILURE_CODE); }
            result.e00 = cast(f32) child.array[0].number;
            result.e10 = cast(f32) child.array[1].number;
            result.e20 = cast(f32) child.array[2].number;
            result.e01 = cast(f32) child.array[3].number;
            result.e11 = cast(f32) child.array[4].number;
            result.e21 = cast(f32) child.array[5].number;
            result.e02 = cast(f32) child.array[6].number;
            result.e12 = cast(f32) child.array[7].number;
            result.e22 = cast(f32) child.array[8].number;

        case m3x4;
            gltfCheck(child.type == .ARRAY, FAILURE_CODE);
            gltfCheck(child.array.count == result.flat.count, FAILURE_CODE);
            for child.array { gltfCheck(it.type == .NUMBER, FAILURE_CODE); }
            result.e00 = cast(f32) child.array[ 0].number;
            result.e10 = cast(f32) child.array[ 1].number;
            result.e20 = cast(f32) child.array[ 2].number;
            result.e01 = cast(f32) child.array[ 3].number;
            result.e11 = cast(f32) child.array[ 4].number;
            result.e21 = cast(f32) child.array[ 5].number;
            result.e02 = cast(f32) child.array[ 6].number;
            result.e12 = cast(f32) child.array[ 7].number;
            result.e22 = cast(f32) child.array[ 8].number;
            result.e03 = cast(f32) child.array[ 9].number;
            result.e13 = cast(f32) child.array[10].number;
            result.e23 = cast(f32) child.array[11].number;

        case m4x3;
            gltfCheck(child.type == .ARRAY, FAILURE_CODE);
            gltfCheck(child.array.count == result.flat.count, FAILURE_CODE);
            for child.array { gltfCheck(it.type == .NUMBER, FAILURE_CODE); }
            result.e00 = cast(f32) child.array[ 0].number;
            result.e10 = cast(f32) child.array[ 1].number;
            result.e20 = cast(f32) child.array[ 2].number;
            result.e30 = cast(f32) child.array[ 3].number;
            result.e01 = cast(f32) child.array[ 4].number;
            result.e11 = cast(f32) child.array[ 5].number;
            result.e21 = cast(f32) child.array[ 6].number;
            result.e31 = cast(f32) child.array[ 7].number;
            result.e02 = cast(f32) child.array[ 8].number;
            result.e12 = cast(f32) child.array[ 9].number;
            result.e22 = cast(f32) child.array[10].number;
            result.e32 = cast(f32) child.array[11].number;

        case m4x4;
            gltfCheck(child.type == .ARRAY, FAILURE_CODE);
            gltfCheck(child.array.count == result.flat.count, FAILURE_CODE);
            for child.array { gltfCheck(it.type == .NUMBER, FAILURE_CODE); }
            result.e00 = cast(f32) child.array[ 0].number;
            result.e10 = cast(f32) child.array[ 1].number;
            result.e20 = cast(f32) child.array[ 2].number;
            result.e30 = cast(f32) child.array[ 3].number;
            result.e01 = cast(f32) child.array[ 4].number;
            result.e11 = cast(f32) child.array[ 5].number;
            result.e21 = cast(f32) child.array[ 6].number;
            result.e31 = cast(f32) child.array[ 7].number;
            result.e02 = cast(f32) child.array[ 8].number;
            result.e12 = cast(f32) child.array[ 9].number;
            result.e22 = cast(f32) child.array[10].number;
            result.e32 = cast(f32) child.array[11].number;
            result.e03 = cast(f32) child.array[12].number;
            result.e13 = cast(f32) child.array[13].number;
            result.e23 = cast(f32) child.array[14].number;
            result.e33 = cast(f32) child.array[15].number;

        case;
            #assert false "Unhandled type";
    }

    return result, true;
}

// We ignore samplers. But is it ok? I hope so...
parseTextures :: (gltf : *JSON_Object, model_name : string) -> [..] string, bool {
    textures : [..] string;
    FAILURE_CODE :: #code { `return textures, false; };

    gltf_textures, status := getChild(gltf, "textures", [] JSON_Value, true);
    if status != .SUCCESS return textures, status == .CHILD_NOT_FOUND;

    gltf_images:, status = getChild(gltf, "images", [] JSON_Value, true);
    gltfCheck(status == .SUCCESS, FAILURE_CODE, "If textures are presented (as they are) then we require images also be presented");

    model_textures_folder := model_name;
    slash_index := String.find_index_from_right(model_name, #char "/");
    if slash_index != -1 then model_textures_folder.count = slash_index;

    Basic.array_reserve(*textures, gltf_textures.count);
    for gltf_textures {
        gltfCheck(it.type == .OBJECT, FAILURE_CODE);

        image_index:, status = getChild(it.object, "source", s64, true);
        gltfCheck(status == .SUCCESS, FAILURE_CODE, "We support referencing images only by \"source\" property");

        gltfCheck(image_index < gltf_images.count, FAILURE_CODE);

        gltf_image := gltf_images[image_index];
        gltfCheck(gltf_image.type == .OBJECT, FAILURE_CODE);

        uri:, status = getChild(gltf_image.object, "uri", string, true);
        gltfCheck(status == .SUCCESS, FAILURE_CODE, "We support defining images with URI only");

        extension, extension_found := String.path_extension(uri);

        texture_name := string.{
            count = uri.count - extension.count - cast(s64) extension_found, // if found == true then we have dot
            data  = uri.data
        };

        capacity := model_textures_folder.count + "/".count + texture_name.count;

        texture := Basic.array_add(*textures);
        texture.data = pushToArena(*context.pet.arenas.per_frame, capacity);
        appendToString(texture, capacity, model_textures_folder, "/", texture_name);
    }

    return textures, true;
}

// @TODO: #GLTF. Support alpha stuff
// @TODO: #GLTF. Support "texCoord" property in "*Texture" descriptors
parseMaterials :: (gltf : *JSON_Object) -> [..] ModelFile.Material, bool {
    materials    : [..] ModelFile.Material;
    FAILURE_CODE :: #code { `return materials, false; };

    gltf_materials, status := getChild(gltf, "materials", [] JSON_Value, true);
    if status != .SUCCESS return materials, status == .CHILD_NOT_FOUND;

    Basic.array_reserve(*materials, gltf_materials.count);

    for gltf_materials {
        gltfCheck(it.type == .OBJECT, FAILURE_CODE);

        material := Basic.array_add(*materials);

        gltf_texture_normal:, status = getChild(it.object, "normalTexture", *JSON_Object, true);
        if status == .SUCCESS {
            material.texture_index_normal, status = getChild(gltf_texture_normal, "index", u16);
            if status != .SUCCESS return materials, false;

            _, status = getChild(gltf_texture_normal, "texCoord", s64, true);
            gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE, "We do not support \"texCoord\" property yet");
        } else {
            gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE);
        }

        gltf_texture_occlusion:, status = getChild(it.object, "occlusionTexture", *JSON_Object, true);
        if status == .SUCCESS {
            material.texture_index_occlusion, status = getChild(gltf_texture_occlusion, "index", u16);
            if status != .SUCCESS return materials, false;

            _, status = getChild(gltf_texture_occlusion, "texCoord", s64, true);
            gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE, "We do not support \"texCoord\" property yet");
        } else {
            gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE);
        }

        gltf_texture_emissive:, status = getChild(it.object, "emissiveTexture", *JSON_Object, true);
        if status == .SUCCESS {
            material.texture_index_emissive, status = getChild(gltf_texture_emissive, "index", u16);
            if status != .SUCCESS return materials, false;

            _, status = getChild(gltf_texture_emissive, "texCoord", s64, true);
            gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE, "We do not support \"texCoord\" property yet");
        } else {
            gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE);
        }

        factor_emissive:, status = getChild(it.object, "emissiveFactor", v3f, true);
        if status == .SUCCESS {
            gltfCheck(0.0 <= factor_emissive.x && factor_emissive.x <= 1.0, FAILURE_CODE);
            gltfCheck(0.0 <= factor_emissive.y && factor_emissive.y <= 1.0, FAILURE_CODE);
            gltfCheck(0.0 <= factor_emissive.z && factor_emissive.z <= 1.0, FAILURE_CODE);
            material.factor_emissive = factor_emissive;
        } else {
            gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE);
        }

        extensions:, status = getChild(it.object, "extensions", *JSON_Object, true);
        if status == .SUCCESS {
            extension:, status = getChild(extensions, "KHR_materials_emissive_strength", *JSON_Object, true);
            if status == .SUCCESS {
                emissive_strength:, status = getChild(extensions, "emissiveStrength", f32, true);
                if status == .SUCCESS {
                    material.factor_emissive *= emissive_strength;
                } else {
                    // default is 1.0
                    gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE);
                }
            } else {
                gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE);
            }
        } else {
            gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE);
        }

        gltf_pbr:, status = getChild(it.object, "pbrMetallicRoughness", *JSON_Object, true);
        if status == .SUCCESS {
            factor_albedo:, status = getChild(gltf_pbr, "baseColorFactor", v4f, true);
            if status == .SUCCESS {
                gltfCheck(0.0 <= factor_albedo.x && factor_albedo.x <= 1.0, FAILURE_CODE);
                gltfCheck(0.0 <= factor_albedo.y && factor_albedo.y <= 1.0, FAILURE_CODE);
                gltfCheck(0.0 <= factor_albedo.z && factor_albedo.z <= 1.0, FAILURE_CODE);
                gltfCheck(0.0 <= factor_albedo.w && factor_albedo.w <= 1.0, FAILURE_CODE);
                material.factor_albedo = factor_albedo;
            } else {
                gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE);
            }

            gltf_texture_albedo:, status = getChild(gltf_pbr, "baseColorTexture", *JSON_Object, true);
            if status == .SUCCESS {
                material.texture_index_albedo, status = getChild(gltf_texture_albedo, "index", u16);
                if status != .SUCCESS return materials, false;

                _, status = getChild(gltf_texture_albedo, "texCoord", s64, true);
                gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE, "We do not support \"texCoord\" property yet");
            } else {
                gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE);
            }

            factor_metallic:, status = getChild(gltf_pbr, "metallicFactor", f32, true);
            if status == .SUCCESS {
                gltfCheck(0.0 <= factor_metallic && factor_metallic <= 1.0, FAILURE_CODE);
                material.factor_metallic = factor_metallic;
            } else {
                gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE);
            }

            factor_roughness:, status = getChild(gltf_pbr, "roughnessFactor", f32, true);
            if status == .SUCCESS {
                gltfCheck(0.0 <= factor_roughness && factor_roughness <= 1.0, FAILURE_CODE);
                material.factor_roughness = factor_roughness;
            } else {
                gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE);
            }

            gltf_texture_metallic_roughness:, status = getChild(gltf_pbr, "metallicRoughnessTexture", *JSON_Object, true);
            if status == .SUCCESS {
                material.texture_index_metallic_roughness, status = getChild(gltf_texture_metallic_roughness, "index", u16);
                if status != .SUCCESS return materials, false;

                _, status = getChild(gltf_texture_metallic_roughness, "texCoord", s64, true);
                gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE, "We do not support \"texCoord\" property yet");
            } else {
                gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE);
            }
        } else {
            gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE);
        }
    }

    return materials, true;
}

parseBuffers :: (gltf : *JSON_Object, exchange_filename : string) -> GLTF_Buffers, bool {
    buffers : GLTF_Buffers;
    FAILURE_CODE :: #code { `return buffers, false; };

    gltf_buffers, status := getChild(gltf, "buffers", [] JSON_Value);
    if status != .SUCCESS return buffers, false;

    slash_index := String.find_index_from_right(exchange_filename, #char "/");
    assert(slash_index != -1);

    folder_path_with_slash := string.{
        count = slash_index + 1,
        data  = exchange_filename.data
    };

    for gltf_buffers {
        gltfCheck(it.type == .OBJECT, FAILURE_CODE);

        uri:, status = getChild(it.object, "uri", string, true);
        gltfCheck(status == .SUCCESS, FAILURE_CODE, "We support defining buffers with URI only");

        buffer_filename_capacity := folder_path_with_slash.count + uri.count;
        buffer_filename := string.{ data = pushToArena(*context.pet.arenas.per_frame, buffer_filename_capacity) };
        appendToString(*buffer_filename, buffer_filename_capacity, folder_path_with_slash, uri);

        file_data, error := readEntireFile(buffer_filename);
        gltfCheck(error == .NONE, FAILURE_CODE);

        buffer_size:, status = getChild(it.object, "byteLength", s64, true);
        if status == .SUCCESS {
            gltfCheck(buffer_size == file_data.count, FAILURE_CODE);
        } else {
            gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE);
        }

        pushBack(*buffers).* = cast(GLTF_Buffer) file_data;
    }

    return buffers, true;
}

// @TODO: #GLTF. Support cameras
// @TODO: #GLTF. Support node graph
// @TODO: #GLTF. Support animations
parseMeshes :: (gltf : *JSON_Object) -> [..] GLTF_Mesh, bool {
    meshes    : [..] GLTF_Mesh;
    FAILURE_CODE :: #code { `return meshes, false; };

    gltf_scenes, status := getChild(gltf, "scenes", [] JSON_Value);
    if status != .SUCCESS return meshes, false;

    scene_index:, status = getChild(gltf, "scene", s64);
    if status != .SUCCESS return meshes, false;

    gltf_scene := gltf_scenes[scene_index];
    gltfCheck(gltf_scene.type == .OBJECT, FAILURE_CODE);

    gltf_scene_nodes:, status = getChild(gltf_scene.object, "nodes", [] JSON_Value);
    if status != .SUCCESS return meshes, false;

    gltf_nodes:, status = getChild(gltf, "nodes", [] JSON_Value);
    if status != .SUCCESS return meshes, false;

    gltf_meshes:, status = getChild(gltf, "meshes", [] JSON_Value);
    if status != .SUCCESS return meshes, false;

    gltf_accessors:, status = getChild(gltf, "accessors", [] JSON_Value);
    if status != .SUCCESS return meshes, false;

    gltf_buffer_views:, status = getChild(gltf, "bufferViews", [] JSON_Value);
    if status != .SUCCESS return meshes, false;

    Basic.array_reserve(*meshes, gltf_scene_nodes.count);

    for gltf_scene_nodes {
        node_index, success := getAs(it, s64);
        if !success return meshes, false;

        gltf_node := gltf_nodes[node_index];
        gltfCheck(gltf_node.type == .OBJECT, FAILURE_CODE);

        gltf_mesh_index:, status = getChild(gltf_node.object, "mesh", s64, true);
        gltfCheck(status == .SUCCESS, FAILURE_CODE, "Nodes without meshes are not supported yet");

        mesh := Basic.array_add(*meshes);

        mesh.mesh_to_model, mesh.model_to_mesh, status = parseMatrix(gltf_node.object);
        if status != .SUCCESS return meshes, false;

        gltf_mesh := gltf_meshes[gltf_mesh_index];
        gltfCheck(gltf_mesh.type == .OBJECT, FAILURE_CODE);

        gltf_primitives:, status = getChild(gltf_mesh.object, "primitives", [] JSON_Value);
        if status != .SUCCESS return meshes, false;

        for gltf_primitives {
            gltfCheck(it.type == .OBJECT, FAILURE_CODE);

            if it_index {
                new_mesh := Basic.array_add(*meshes);
                new_mesh.mesh_to_model = mesh.mesh_to_model;
                new_mesh.model_to_mesh = mesh.model_to_mesh;
                mesh = new_mesh;
            }

            gl_mode:, status = getChild(it.object, "mode", u16, true);
            if status == .SUCCESS {
                GL_POINTS         :: 0x0000;
                GL_LINES          :: 0x0001;
                GL_LINE_LOOP      :: 0x0002;
                GL_LINE_STRIP     :: 0x0003;
                GL_TRIANGLES      :: 0x0004;
                GL_TRIANGLE_STRIP :: 0x0005;
                GL_TRIANGLE_FAN   :: 0x0006;
                GL_QUADS          :: 0x0007;
                GL_QUAD_STRIP     :: 0x0008;
                GL_POLYGON        :: 0x0009;

                gltfCheck(gl_mode == GL_TRIANGLES, FAILURE_CODE, "Only GL_TRIANGLES mode is supported");
            } else {
                gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE);
            }

            material_index:, status = getChild(it.object, "material", u16, true);
            if status == .SUCCESS {
                mesh.material_index = material_index;
            } else {
                gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE);
            }

            accessor_index:, status = getChild(it.object, "indices", s64, true);
            if status == .SUCCESS {
                success = parseAccessor(mesh, gltf_accessors, accessor_index, gltf_buffer_views, .INDEX);
                if !success return meshes, false;
            } else {
                gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE);
            }

            gltf_attributes:, status = getChild(it.object, "attributes", *JSON_Object);
            if status != .SUCCESS return meshes, false;

            accessor_index, status = getChild(gltf_attributes, "POSITION", s64);
            if status != .SUCCESS return meshes, false;

            success = parseAccessor(mesh, gltf_accessors, accessor_index, gltf_buffer_views, .POSITION);
            if !success return meshes, false;

            accessor_index, status = getChild(gltf_attributes, "NORMAL", s64, true);
            if status == .SUCCESS {
                success = parseAccessor(mesh, gltf_accessors, accessor_index, gltf_buffer_views, .NORMAL);
                if !success return meshes, false;
            } else {
                gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE);
            }

            accessor_index, status = getChild(gltf_attributes, "TEXCOORD", s64, true);
            if status == .SUCCESS {
                success = parseAccessor(mesh, gltf_accessors, accessor_index, gltf_buffer_views, .TEXCOORD);
                if !success return meshes, false;
            } else {
                gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE);
            }
        }
    }

    return meshes, true;
}

// @TODO: #GLTF. Support "matrix" property
parseMatrix :: (gltf_node : *JSON_Object) -> (matrix : m3x4, inv_matrix : m3x4, status : ParseStatus) {
    FAILURE_CODE :: #code { `return IDENTITY_3X4, IDENTITY_3X4, .FAIL; };

    gltf_matrix, status := getChild(gltf_node, "matrix", m4x4, true);
    gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE, "matrix is not supported in nodes yet");

    matrix     : m3x4 = ---;
    inv_matrix : m3x4 = ---;

    q:, status = getChild(gltf_node, "rotation", v4f, true);
    if status == .SUCCESS {
        q.xy *= -1.0; // #RHtoLH.

        matrix = .{
            1.0 - 2.0 * (q.y * q.y + q.z * q.z),       2.0 * (q.x * q.y - q.z * q.w),       2.0 * (q.x * q.z + q.y * q.w), 0.0,
                  2.0 * (q.x * q.y + q.z * q.w), 1.0 - 2.0 * (q.x * q.x + q.z * q.z),       2.0 * (q.y * q.z - q.x * q.w), 0.0,
                  2.0 * (q.x * q.z - q.y * q.w),       2.0 * (q.y * q.z + q.x * q.w), 1.0 - 2.0 * (q.x * q.x + q.y * q.y), 0.0,
        };

        inv_matrix = .{
            matrix.e00, matrix.e10, matrix.e20, 0.0,
            matrix.e01, matrix.e11, matrix.e21, 0.0,
            matrix.e02, matrix.e12, matrix.e22, 0.0,
        };
    } else {
        gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE);
        matrix     = IDENTITY_3X4;
        inv_matrix = IDENTITY_3X4;
    }

    inv_scale : v3f = ---;

    scale:, status = getChild(gltf_node, "scale", v3f, true);
    if status == .SUCCESS {
        // Pre scale
        matrix[0].xyz *= scale;
        matrix[1].xyz *= scale;
        matrix[2].xyz *= scale;

        inv_scale = 1.0 / scale;
    } else {
        gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE);
        inv_scale = v3f.{ 1.0, 1.0, 1.0 };
    }

    translation:, status = getChild(gltf_node, "translation", v3f, true);
    if status == .SUCCESS {
        translation.z *= -1.0; // #RHtoLH.

        // Post translate
        matrix.e03 = translation.x;
        matrix.e13 = translation.y;
        matrix.e23 = translation.z;

        inv_matrix.e03 = -dot(inv_matrix[0].xyz, translation);
        inv_matrix.e13 = -dot(inv_matrix[1].xyz, translation);
        inv_matrix.e23 = -dot(inv_matrix[2].xyz, translation);
    } else {
        gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE);
    }

    inv_matrix[0] *= inv_scale.x;
    inv_matrix[1] *= inv_scale.y;
    inv_matrix[2] *= inv_scale.z;

    for matrix.flat     { assert(isFinite(it)); }
    for inv_matrix.flat { assert(isFinite(it)); }

    return matrix, inv_matrix, .SUCCESS;
}

parseAccessor :: (
    mesh                : *GLTF_Mesh,
    gltf_accessors      : [] JSON_Value,
    gltf_accessor_index : s64,
    gltf_buffer_views   : [] JSON_Value,
    $stream             : GLTF_Mesh.Stream
) -> bool {
    FAILURE_CODE :: #code { `return false; };

    gltf_accessor := gltf_accessors[gltf_accessor_index];
    gltfCheck(gltf_accessor.type == .OBJECT, FAILURE_CODE);

    accessor_type, status := getChild(gltf_accessor.object, "type", string);
    if status != .SUCCESS return false;

    gl_component_type:, status = getChild(gltf_accessor.object, "componentType", u16);
    if status != .SUCCESS return false;

    type := accessorTypeAndComponentTypeToType(accessor_type, gl_component_type);
    if type == void return false;
    #if #complete stream == {
        case .INDEX;    gltfCheck(type == u8 || type == u16 || type == u32, FAILURE_CODE);
        case .POSITION; gltfCheck(type == v3f || type == v4f, FAILURE_CODE);
        case .NORMAL;   gltfCheck(type == v3f || type == v4f, FAILURE_CODE);
        case .TEXCOORD; gltfCheck(type == f32 || type == v2f || type == v3f, FAILURE_CODE);
    }
    mesh.type_by_stream[stream] = type;

    mesh.count_by_stream[stream], status = getChild(gltf_accessor.object, "count", s64);
    if status != .SUCCESS return false;
    gltfCheck(mesh.count_by_stream[stream] >= 0, FAILURE_CODE);

    #if stream == .POSITION {
        gltfCheck(mesh.count_by_stream[stream],
                  FAILURE_CODE,
                  "% stream is required. It exists, but number of entires is %",
                  stream,
                  mesh.count_by_stream[stream]);
    } else #if stream != .INDEX {
        gltfCheck(mesh.count_by_stream[stream] == mesh.count_by_stream[GLTF_Mesh.Stream.POSITION],
                  FAILURE_CODE,
                  "% count (%) != % count (%)",
                  stream,
                  mesh.count_by_stream[stream],
                  GLTF_Mesh.Stream.POSITION,
                  mesh.count_by_stream[GLTF_Mesh.Stream.POSITION]);
    }

    buffer_view_index:, status = getChild(gltf_accessor.object, "bufferView", s64);
    if status != .SUCCESS return false;

    gltf_buffer_view := gltf_buffer_views[buffer_view_index];
    gltfCheck(gltf_buffer_view.type == .OBJECT, FAILURE_CODE);

    mesh.buffer_index_by_stream[stream], status = getChild(gltf_buffer_view.object, "buffer", u8);
    if status != .SUCCESS return false;

    {
        mesh.offset_in_bytes_by_stream[stream], status = getChild(gltf_accessor.object, "byteOffset", s64, true);
        if status == .FAIL return false;

        temp:, status = getChild(gltf_buffer_view.object, "byteOffset", s64, true);
        if status == .FAIL return false;
        mesh.offset_in_bytes_by_stream[stream] += temp;
    }

    byte_stride:, status = getChild(gltf_buffer_view.object, "byteStride", u8, true);
    if status == .SUCCESS {
        mesh.read_stride_by_stream[stream] = byte_stride;
    } else {
        gltfCheck(status == .CHILD_NOT_FOUND, FAILURE_CODE);
        mesh.read_stride_by_stream[stream] = cast(u8) cast(*Type_Info, type).runtime_size;
    }

    return true;
}

accessorTypeAndComponentTypeToType :: (accessor_type : string, component_type : u16) -> Type {
    FAILURE_CODE :: #code { `return void; };

    GL_BYTE           : u16 : 0x1400;
    GL_UNSIGNED_BYTE  : u16 : 0x1401;
    GL_SHORT          : u16 : 0x1402;
    GL_UNSIGNED_SHORT : u16 : 0x1403;
    GL_INT            : u16 : 0x1404;
    GL_UNSIGNED_INT   : u16 : 0x1405;
    GL_FLOAT          : u16 : 0x1406;

    if accessor_type == {
        case "SCALAR";
            if component_type == {
                case GL_BYTE;           return s8;
                case GL_UNSIGNED_BYTE;  return u8;
                case GL_SHORT;          return s16;
                case GL_UNSIGNED_SHORT; return u16;
                case GL_INT;            return s32;
                case GL_UNSIGNED_INT;   return u32;
                case GL_FLOAT;          return f32;
                case;
                    gltfCheck(false, FAILURE_CODE, "Unhandled componentType value: 0x%", formatHex(component_type));
            }

        case "VEC2";
            if component_type == {
                case GL_INT;          return v2s;
                case GL_UNSIGNED_INT; return v2u;
                case GL_FLOAT;        return v2f;
                case;
                    gltfCheck(false, FAILURE_CODE, "Unhandled componentType value: 0x%", formatHex(component_type));
            }

        case "VEC3";
            if component_type == {
                case GL_INT;          return v3s;
                case GL_UNSIGNED_INT; return v3u;
                case GL_FLOAT;        return v3f;
                case;
                    gltfCheck(false, FAILURE_CODE, "Unhandled componentType value: 0x%", formatHex(component_type));
            }

        case "VEC4";
            if component_type == {
                case GL_INT;          return v4s;
                case GL_UNSIGNED_INT; return v4u;
                case GL_FLOAT;        return v4f;
                case;
                    gltfCheck(false, FAILURE_CODE, "Unhandled componentType value: 0x%", formatHex(component_type));
            }

        case "MAT2";
            gltfCheck(component_type == GL_FLOAT, FAILURE_CODE, "Unhandled componentType value: 0x%", formatHex(component_type));
            return m2x2;

        case "MAT3";
            gltfCheck(component_type == GL_FLOAT, FAILURE_CODE, "Unhandled componentType value: 0x%", formatHex(component_type));
            return m3x3;

        case "MAT4";
            gltfCheck(component_type == GL_FLOAT, FAILURE_CODE, "Unhandled componentType value: 0x%", formatHex(component_type));
            return m4x4;

        case;
            gltfCheck(false, FAILURE_CODE, "Unhandled accessor type value: %", accessor_type);
    }

    return void;
}

uniteBuffersAndRemapMeshes :: (buffers : GLTF_Buffers, gltf_meshes : [..] GLTF_Mesh) -> (
    vertices : [..] VertexTypes.Default,
    indices  : [..] u32,
    meshes   : [] ModelFile.Mesh,
    success  : bool
) {
    vertices     : [..] VertexTypes.Default;
    indices      : [..] u32;
    meshes       : [] ModelFile.Mesh;
    FAILURE_CODE :: #code { `return vertices, indices, meshes, false; };

    Basic.array_reserve(*vertices, 1_000_000);
    Basic.array_reserve(*indices,  1_000_000);
    meshes.count = gltf_meshes.count;
    meshes.data  = pushToArena(*context.pet.arenas.per_frame, ModelFile.Mesh, meshes.count);

    for gltf_mesh : gltf_meshes {
        mesh := *meshes[it_index];
        mesh.mesh_to_model       = gltf_mesh.mesh_to_model;
        mesh.model_to_mesh       = gltf_mesh.model_to_mesh;
        mesh.material_index      = gltf_mesh.material_index;
        mesh.indices_start       = cast(u32) indices.count;
        defer mesh.indices_count = cast(u32, indices.count) - mesh.indices_start;

        this_mesh_vertices_offset := cast(u32) vertices.count;

        gltf_indices_count := gltf_mesh.count_by_stream[GLTF_Mesh.Stream.INDEX];
        if gltf_indices_count > 0 {
            buffer      := buffers[gltf_mesh.buffer_index_by_stream[GLTF_Mesh.Stream.INDEX]];
            offset      := gltf_mesh.offset_in_bytes_by_stream[GLTF_Mesh.Stream.INDEX];
            read_stride := gltf_mesh.read_stride_by_stream[GLTF_Mesh.Stream.INDEX];
            type        := gltf_mesh.type_by_stream[GLTF_Mesh.Stream.INDEX];

            for 0 .. gltf_indices_count - 1 {
                raw_data : *u8 = *buffer[offset + it * read_stride];

                index := this_mesh_vertices_offset;
                if type == {
                    case u8;  index += cast(*u8,  raw_data).*;
                    case u16; index += cast(*u16, raw_data).*;
                    case u32; index += cast(*u32, raw_data).*;
                }

                Basic.array_add(*indices, index);
            }
        }

        vertices_count := gltf_mesh.count_by_stream[GLTF_Mesh.Stream.POSITION];
        for 0 .. vertices_count - 1 {
            vertex, success := makeDefaultVertex(buffers, gltf_mesh, it);
            if !success return vertices, indices, meshes, false;

            Basic.array_add(*vertices, vertex);

            if gltf_indices_count <= 0 {
                index := this_mesh_vertices_offset + cast(u32) it;
                Basic.array_add(*indices, index);
            }
        }
    }

    return vertices, indices, meshes, true;
}

makeDefaultVertex :: (buffers : GLTF_Buffers, mesh : GLTF_Mesh, vertex_index : s64) -> VertexTypes.Default, bool {
    vertex       : VertexTypes.Default;
    FAILURE_CODE :: #code { `return vertex, false; };

    count := mesh.count_by_stream[GLTF_Mesh.Stream.POSITION];
    {
        gltfCheck(vertex_index < count, FAILURE_CODE);

        STREAM :: GLTF_Mesh.Stream.POSITION;

        buffer      := buffers[mesh.buffer_index_by_stream[STREAM]];
        offset      := mesh.offset_in_bytes_by_stream[STREAM];
        read_stride := mesh.read_stride_by_stream[STREAM];
        type        := mesh.type_by_stream[STREAM];

        floats := cast(*f32) *buffer[offset + vertex_index * read_stride];

        position : v3f = ---;
        position.x =  floats[0];
        position.y =  floats[1];
        position.z = -floats[2]; // #RHtoLH.

        if type == v4f {
            w := floats[3];
            gltfCheck(almostZero(w) || almostEquals(w, 1.0), FAILURE_CODE);
        }

        vertex.position_u.xyz = position;
    }

    count = mesh.count_by_stream[GLTF_Mesh.Stream.NORMAL];
    if count > 0 {
        gltfCheck(vertex_index < count, FAILURE_CODE);

        STREAM :: GLTF_Mesh.Stream.NORMAL;

        buffer      := buffers[mesh.buffer_index_by_stream[STREAM]];
        offset      := mesh.offset_in_bytes_by_stream[STREAM];
        read_stride := mesh.read_stride_by_stream[STREAM];
        type        := mesh.type_by_stream[STREAM];

        floats := cast(*f32) *buffer[offset + vertex_index * read_stride];

        normal : v3f = ---;
        normal.x =  floats[0];
        normal.y =  floats[1];
        normal.z = -floats[2]; // #RHtoLH.

        if type == v4f {
            w := floats[3];
            gltfCheck(almostZero(w) || almostEquals(w, 1.0), FAILURE_CODE);
        }

        assertNormalized(normal);
        vertex.normal_v.xyz = normal;
    }

    count = mesh.count_by_stream[GLTF_Mesh.Stream.TEXCOORD];
    if count > 0 {
        gltfCheck(vertex_index < count, FAILURE_CODE);

        STREAM :: GLTF_Mesh.Stream.TEXCOORD;

        buffer      := buffers[mesh.buffer_index_by_stream[STREAM]];
        offset      := mesh.offset_in_bytes_by_stream[STREAM];
        read_stride := mesh.read_stride_by_stream[STREAM];
        type        := mesh.type_by_stream[STREAM];

        floats := cast(*f32) *buffer[offset + vertex_index * read_stride];

        if type == {
            case f32;
                vertex.position_u.w = floats[0];

            case v2f;
                vertex.position_u.w = floats[0];
                vertex.normal_v.w   = floats[1];

            case v3f;
                gltfCheck(false, FAILURE_CODE, "3-dimensional texture coordinates are not fully supported yet");
        }
    }

    return vertex, true;
}

#import "jaison";
