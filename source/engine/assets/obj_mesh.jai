convertObjMesh :: (exchange_filename : string, name : string) -> bool {
    infoMessage("Converting \"%.obj\"...", name);

    data, error := readEntireFile(exchange_filename, pushToArena, *context.pet.per_frame_arena);
    assert(error == .NONE, "The error must be NONE because we know that the file exists");

    obj_mesh : ObjMesh;
    if !parseObjFile(data, *obj_mesh, name, true) {
        return false;
    }
    defer destroyObjMesh(*obj_mesh);

    // @Continue:
    //     - Remap triplets to linear indices
    //     - Unite N vertex attribute streams to 1 position and 1 varying streams
    //     - Convert to our vertex format

    infoMessage("\"%.obj\" has been converted", name);
    return true;
}

#scope_file

ObjMesh :: struct {
    MAX_ATTRIBUTES :: #run Basic.enum_highest_value(Attribute) + 1;
    INVALID_INDEX  :: 0;

    Triplet :: [MAX_ATTRIBUTES] u32;

    Attribute :: enum u8 {
        POSITION;
        TEXCOORD;
        NORMAL;
    }

    VertexGroup :: struct {
        attributes : [MAX_ATTRIBUTES][..] v3f;
        name       : string;
    }

    FaceGroup :: struct {
        triplets : [..] Triplet;
        name     : string;
    }

    vertex_groups : StaticArray(VertexGroup, Mesh.MAX_SUBMESHES);
    face_groups   : StaticArray(FaceGroup,   Mesh.MAX_SUBMESHES);
}

destroyObjMesh :: (mesh : *ObjMesh) {
    for mesh.vertex_groups {
        for it.attributes {
            if it {
                Basic.array_free(it);
            }
        }
    }
    reset(*mesh.vertex_groups);

    for mesh.face_groups {
        if it.triplets {
            Basic.array_free(it.triplets);
        }
    }
    reset(*mesh.face_groups);
}

parseObjFile :: (stream : string, mesh : *ObjMesh, name : string, $collect_statistics := false) -> bool {
    #if collect_statistics {
        file_size_mb := bytesToMegaBytes(stream.count);
        time_start   := Basic.current_time_monotonic();
        defer {
            duration := Basic.to_float64_seconds(Basic.current_time_monotonic() - time_start);

            builder := Basic.String_Builder.{ allocator = Basic.temp };
            Basic.print(*builder, "File \"%.obj\" is parsed:\n", name);
            Basic.print(*builder, "    Size:     % MB\n", file_size_mb);
            Basic.print(*builder, "    Duration: % s\n", duration);
            Basic.print(*builder, "    Speed:    % MB/s\n", file_size_mb / duration);

            Basic.print(*builder, "    Vertex groups (%):\n", mesh.vertex_groups.count);
            for mesh.vertex_groups {
                Basic.print(*builder, "        [%] \"%\":\n", it_index, it.name);
                for it.attributes {
                    Basic.print(*builder, "            %s: %\n", cast(ObjMesh.Attribute) it_index, it.count);
                }
            }

            Basic.print(*builder, "    Face groups (%):\n", mesh.face_groups.count);
            for mesh.face_groups {
                Basic.print(*builder, "        [%] \"%\":\n", it_index, it.name);
                Basic.print(*builder, "            triplets: %\n", it.triplets.count);
            }

            infoMessage("%", Basic.builder_to_string(*builder,, allocator = Basic.temp));
        }
    }

    new_group_name : string;

    while stream {
        line, success := getLine(*stream, name);
        if !success return false;

        // Skip an empty line or a comment
        if !line || line[0] == #char "#" {
            continue;
        }

        if String.starts_with(line, "g ") {
            advance(*line, "g ".count);
            line = Basic.eat_spaces(line);
            new_group_name = line;
        } else if String.starts_with(line, "v ") {
            advance(*line, "v ".count);
            line = Basic.eat_spaces(line);

            if !line {
                errorMessage("\"%.obj\": Line with vertex position does not have any data", name);
                return false;
            }

            group := getVertexGroup(mesh, new_group_name);
            new_group_name = "";

            if !getVertexAttribute(*line, group, .POSITION, name) {
                return false;
            }
        } else if String.starts_with(line, "vt ") {
            advance(*line, "vt ".count);
            line = Basic.eat_spaces(line);

            if !line {
                errorMessage("\"%.obj\": Line with vertex texture coordinate does not have any data", name);
                return false;
            }

            group := getVertexGroup(mesh, new_group_name);
            new_group_name = "";

            if !getVertexAttribute(*line, group, .TEXCOORD, name) {
                return false;
            }
        } else if String.starts_with(line, "vn ") {
            advance(*line, "vn ".count);
            line = Basic.eat_spaces(line);

            if !line {
                errorMessage("\"%.obj\": Line with vertex normal does not have any data", name);
                return false;
            }

            group := getVertexGroup(mesh, new_group_name);
            new_group_name = "";

            if !getVertexAttribute(*line, group, .NORMAL, name) {
                return false;
            }
        } else if String.starts_with(line, "f ") {
            advance(*line, "f ".count);
            line = Basic.eat_spaces(line);

            if !line {
                errorMessage("\"%.obj\": Line with face does not have any data", name);
                return false;
            }

            group := getFaceGroup(mesh, new_group_name);
            new_group_name = "";

            if !getTriplets(*line, group, name) {
                return false;
            }
        } else if String.starts_with(line, "vp ") {
            errorMessage("\"%.obj\": We do not support parameter space in .obj files", name);
            return false;
        } else if String.starts_with(line, "l ") {
            errorMessage("\"%.obj\": We do not support polylines in .obj files", name);
            return false;
        }
    }

    if mesh.vertex_groups.count <= 0 {
        errorMessage("\"%.obj\": No vertex data found in file", name);
        return false;
    }

GROUPS_COUNT_ERROR_STRING :: #string END
"%.obj\: We do not support different number of vertex and face groups except when number of vertex groups is 1.
    Number of vertex groups: %
    Number of face groups:   %
END;
    if mesh.vertex_groups.count != mesh.face_groups.count && mesh.face_groups.count > 0 && mesh.vertex_groups.count > 1 {
        errorMessage(GROUPS_COUNT_ERROR_STRING, name, mesh.vertex_groups.count, mesh.face_groups.count);
        return false;
    }

    return true;
}

getLine :: (stream : *string, name : string) -> (string, bool) {
    line := string.{ data = stream.data };

    while stream.* && stream.*[0] != #char "\n" && stream.*[0] != #char "\r" {
        advance(stream);
    }

    line.count = cast(s64) (stream.data - line.data);

    if line && line[line.count - 1] == #char "\\" {
        errorMessage("\"%.obj\": We do not support joining lines in .obj files", name);
        return "", false;
    }

    if stream.* {
        if stream.*[0] == {
            case #char "\n"; advance(stream, "\n".count);
            case #char "\r"; advance(stream, "\r\n".count);
            case;            assert(false);
        }
    }

    return line, true;
}

getVertexAttribute :: (line : *string, group : *ObjMesh.VertexGroup, attribute : ObjMesh.Attribute, name : string) -> bool {
    if !line.* return true;

    attribute_data : v3f;
    for * attribute_data.e {
        if !line.* break;

        it.*, success:, line.* = Basic.string_to_float(line.*);
        if !success {
            errorMessage("\"%.obj\": Failed to parse #% component of vertex % attribute", name, it_index, attribute);
            return false;
        }
        line.* = Basic.eat_spaces(line.*);
    }

    Basic.array_add(*group.attributes[attribute], attribute_data);
    return true;
}

getTriplets :: (line : *string, group : *ObjMesh.FaceGroup, name : string) -> bool {
    triplets       : [4] ObjMesh.Triplet;
    triplets_count : u8;

    while line.* {
        if triplets_count > 4 {
            errorMessage("\"%.obj\": We do not support more than 4 triplets in a row", name);
            return false;
        }

        for * triplets[triplets_count] {
            assert(line.*);

            assert(line.*[0] != #char " " && line.*[0] != #char "\t",
                   "\"%.obj\": Spaces are allowed only between triplets",
                   name);

            // There is no index for 'it_index' attribute, go to the next one
            if line.*[0] == #char "/" {
                advance(line, "/".count);
                continue;
            }

            if line.*[0] == #char "-" {
                errorMessage("\"%.obj\": We do not support negative indices yet (index for % attribute)", name, cast(ObjMesh.Attribute) it_index);
                return false;
            }

            index : u32;
            while line.* {
                char := line.*[0];

                if char < #char "0" || char > #char "9" {
                    if index break;

                    errorMessage("\"%.obj\": Failed to parse index for % attribute: unexpected character '%', expected digit",
                                 name,
                                 cast(ObjMesh.Attribute) it_index,
                                 string.{ 1, *char });
                    return false;
                }

                digit := char - #char "0";
                assert(digit < 10);

                index = index * 10 + digit;
                advance(line, 1);
            }

            it.* = index;

            if !line.* break;
            if line.*[0] == #char "/" {
                advance(line, "/".count);
            }
        }

        line.* = Basic.eat_spaces(line.*);
        triplets_count += 1;
    }

    if triplets_count < 3 {
        errorMessage("\"%.obj\": We do not support less than 3 triplets in a row", name);
        return false;
    }

    Basic.array_add(*group.triplets, triplets[0], triplets[1], triplets[2]);

    // Triangulate quad into 2 triangles
    if triplets_count == 4 {
        Basic.array_add(*group.triplets, triplets[0], triplets[2], triplets[3]);
    }

    return true;
}

getVertexGroup :: (obj_mesh : *ObjMesh, group_name : string) -> *ObjMesh.VertexGroup {
    if obj_mesh.vertex_groups.count <= 0 {
        group := pushBack(*obj_mesh.vertex_groups);
        group.name = group_name;

        return group;
    }

    if group_name {
        for * obj_mesh.vertex_groups {
            if it.name == group_name {
                return it;
            }
        }

        group := pushBack(*obj_mesh.vertex_groups);
        group.name = group_name;

        return group;
    }

    return *obj_mesh.vertex_groups[obj_mesh.vertex_groups.count - 1];
}

getFaceGroup :: (obj_mesh : *ObjMesh, group_name : string) -> *ObjMesh.FaceGroup {
    if obj_mesh.face_groups.count <= 0 {
        group := pushBack(*obj_mesh.face_groups);
        group.name = group_name;

        return group;
    }

    if group_name {
        for * obj_mesh.face_groups {
            if it.name == group_name {
                return it;
            }
        }

        group := pushBack(*obj_mesh.face_groups);
        group.name = group_name;

        return group;
    }

    return *obj_mesh.face_groups[obj_mesh.face_groups.count - 1];
}
