convertObjMesh :: (exchange_filename : string, name : string) -> bool {
    infoMessage("Converting \"%.obj\"...", name);

    data, error := readEntireFile(exchange_filename, pushToArena, *context.pet.arenas.per_frame);
    assert(error == .NONE, "The error must be NONE because we know that the file exists");

    obj_mesh : ObjMesh;
    if !parseObjFile(data, *obj_mesh, name) {
        return false;
    }
    defer destroyObjMesh(*obj_mesh);

    vertices : [Mesh.MAX_SUBMESHES][..] VertexTypes.Default;
    indices  : [Mesh.MAX_SUBMESHES][..] u32;
    defer {
        for indices  if it Basic.array_free(it);
        for vertices if it Basic.array_free(it);
    }

    submeshes_count : u8 = ---;
    if obj_mesh.face_groups.count > 0 {
        submeshes_count = remapTriplets(*obj_mesh, *vertices, *indices);
    } else {
        submeshes_count = convertVertices(*obj_mesh, *vertices);
    }

    if !serializeMesh(*vertices, *indices, submeshes_count, name) {
        return false;
    }

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

parseObjFile :: (stream : string, mesh : *ObjMesh, name : string) -> bool {
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
"%.obj": We do not support different number of vertex and face groups except when number of vertex groups is 1 or number of face groups is 0.
    Number of vertex groups: %
    Number of face groups:   %
END;
    if mesh.vertex_groups.count != mesh.face_groups.count && mesh.face_groups.count > 0 && mesh.vertex_groups.count > 1 {
        errorMessage(GROUPS_COUNT_ERROR_STRING, name, mesh.vertex_groups.count, mesh.face_groups.count);
        return false;
    }

    for mesh.face_groups {
        if it.triplets.count % 3 {
            errorMessage("\"%.obj\": Expected triplets count be multiple of 3. Face group '%' (#%), triplets count: %",
                         it.name,
                         it_index,
                         it.triplets.count);
            return false;
        }
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
                advance(line);
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
                advance(line);
            }

            it.* = index;

            if !line.* break;
            if line.*[0] == #char "/" {
                advance(line);
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

remapTriplets :: (
    obj_mesh : *ObjMesh,
    vertices : *[Mesh.MAX_SUBMESHES][..] VertexTypes.Default,
    indices  : *[Mesh.MAX_SUBMESHES][..] u32
) -> u8 {
    triplet_to_index : Hash_Table.Table(ObjMesh.Triplet, u32, given_compare_function = (a : ObjMesh.Triplet, b : ObjMesh.Triplet) -> bool {
        return !memcmp(a.data, b.data, size_of(ObjMesh.Triplet));
    });

    Hash_Table.init(*triplet_to_index);
    defer Hash_Table.deinit(*triplet_to_index);

    for face_group, group_index : obj_mesh.face_groups {
        assert(face_group.triplets.count > 0);

        Hash_Table.table_reset(*triplet_to_index);

        vertex_group := ifx  obj_mesh.vertex_groups.count == 1
                        then *obj_mesh.vertex_groups[0]
                        else *obj_mesh.vertex_groups[group_index];

        vertex_positions := *vertex_group.attributes[ObjMesh.Attribute.POSITION];
        vertex_texcoords := *vertex_group.attributes[ObjMesh.Attribute.TEXCOORD];
        vertex_normals   := *vertex_group.attributes[ObjMesh.Attribute.NORMAL];

        submesh_vertices := *vertices.*[group_index];
        submesh_indices  := *indices.*[group_index];

        max_vertices := max(vertex_positions.count, vertex_texcoords.count, vertex_normals.count);
        assert(max_vertices > 0);

        Basic.array_reserve(submesh_vertices, max_vertices);
        Basic.array_reserve(submesh_indices, face_group.triplets.count);

        next_vertex_index : u32;

        for triplet : face_group.triplets {
            vertex_index_ptr := Hash_Table.table_find_pointer(*triplet_to_index, triplet);

            if !vertex_index_ptr {
                vertex_index_ptr = Hash_Table.table_add(*triplet_to_index, triplet, next_vertex_index);

                position_index := triplet[ObjMesh.Attribute.POSITION];
                texcoord_index := triplet[ObjMesh.Attribute.TEXCOORD];
                normal_index   := triplet[ObjMesh.Attribute.NORMAL];

                assert(position_index > 0, "Obj files store indices starting with 1");
                assert(texcoord_index > 0, "Obj files store indices starting with 1");
                assert(normal_index   > 0, "Obj files store indices starting with 1");

                position_index -= 1;
                texcoord_index -= 1;
                normal_index   -= 1;

                texcoord := vertex_texcoords.*[texcoord_index];

                new_vertex := Basic.array_add(submesh_vertices);
                new_vertex.position_u.xyz = vertex_positions.*[position_index];
                new_vertex.position_u.w   = texcoord.x;
                new_vertex.normal_v.xyz   = vertex_normals.*[normal_index];
                new_vertex.normal_v.w     = texcoord.y;

                next_vertex_index += 1;
            }

            assert(vertex_index_ptr);
            Basic.array_add(submesh_indices, vertex_index_ptr.*);
        }
    }

    return cast(u8) obj_mesh.face_groups.count;
}

convertVertices :: (obj_mesh : *ObjMesh, vertices : *[Mesh.MAX_SUBMESHES][..] VertexTypes.Default) -> u8 {
    for obj_mesh.vertex_groups {
        vertex_positions := *it.attributes[ObjMesh.Attribute.POSITION];
        vertex_texcoords := *it.attributes[ObjMesh.Attribute.TEXCOORD];
        vertex_normals   := *it.attributes[ObjMesh.Attribute.NORMAL];

        submesh_vertices := *vertices.*[it_index];

        assert(vertex_positions.count == vertex_texcoords.count && vertex_positions.count == vertex_normals.count);

        Basic.array_reserve(submesh_vertices, vertex_positions.count);

        vertex_texcoords_it := vertex_texcoords.data;
        vertex_normals_it   := vertex_normals.data;

        for vertex_positions.* {
            new_vertex := Basic.array_add(submesh_vertices);
            new_vertex.position_u.xyz = it;
            new_vertex.position_u.w   = vertex_texcoords_it.x;
            new_vertex.normal_v.xyz   = vertex_normals_it.*;
            new_vertex.normal_v.w     = vertex_texcoords_it.y;

            vertex_texcoords_it += 1;
            vertex_normals_it   += 1;
        }
    }

    return cast(u8) obj_mesh.vertex_groups.count;
}

Hash_Table :: #import "Hash_Table";
