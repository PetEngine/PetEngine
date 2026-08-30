convertObjModel :: (exchange_filename : string, name : string) -> bool {
    data, error := readEntireFile(exchange_filename);
    assert(error == .NONE);

    obj_model : ObjModel;
    if !parseObjFile(data, *obj_model, name) {
        return false;
    }
    defer destroyObjModel(*obj_model);

    vertices : [..] VertexTypes.PNTUV; // @TODO: #SpecializationConstants.
    indices  : [..] u32;
    defer {
        if vertices.data then Basic.array_free(vertices);
        if indices.data  then Basic.array_free(indices);
    }

    if obj_model.face_groups.count > 0 {
        vertices, indices = remapTriplets(obj_model);
    } else {
        vertices, indices = convertVertices(obj_model, name);
    }

    materials : [1] ModelFile.Material = .[
        .{}
    ];

    meshes : [1] ModelFile.Mesh = .[
        .{ indices_count = cast(u32) indices.count, material_index = 0 },
    ];

    // #RHtoLH.
    for * meshes {
        it.mesh_to_model.e20 *= -1.0;
        it.mesh_to_model.e21 *= -1.0;
        it.mesh_to_model.e22 *= -1.0;
        it.mesh_to_model.e23 *= -1.0;

        it.model_to_mesh.e02 *= -1.0;
        it.model_to_mesh.e12 *= -1.0;
        it.model_to_mesh.e22 *= -1.0;
    }

    return serializeModel(name, .{}, materials, meshes, vertices, indices);
}

#scope_file

ObjModel :: struct {
    MAX_ATTRIBUTES :: #run Basic.enum_highest_value(Attribute) + 1;
    INVALID_INDEX  :: 0;

    Triplet :: [MAX_ATTRIBUTES] u32; // indices to attributes

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

    vertex_groups : [..] VertexGroup;
    face_groups   : [..] FaceGroup;
}

destroyObjModel :: (model : *ObjModel) {
    for model.vertex_groups {
        for it.attributes {
            if it.data {
                Basic.array_free(it);
            }
        }
    }
    if model.vertex_groups.data {
        Basic.array_reset(*model.vertex_groups);
    }

    for model.face_groups {
        if it.triplets.data {
            Basic.array_free(it.triplets);
        }
    }
    if model.face_groups.data {
        Basic.array_reset(*model.face_groups);
    }
}

parseObjFile :: (stream : string, model : *ObjModel, name : string) -> bool {
    new_group_name : string;

    while stream {
        line := getLine(*stream);

        // Skip an empty line or a comment
        if !line || line[0] == #char "#" {
            continue;
        }

        if line[line.count - 1] == #char "\\" {
            errorMessage("\"%.obj\": We do not support joining lines in .obj files", name);
            return false;
        }

        if String.starts_with(line, "g ") {
            advance(*line, "g ".count);
            trimLeft(*line);

            new_group_name = line;
        } else if String.starts_with(line, "v ") {
            advance(*line, "v ".count);
            trimLeft(*line);

            if !line {
                errorMessage("\"%.obj\": Line with vertex position does not have any data", name);
                return false;
            }

            group := getVertexGroup(model, new_group_name);
            new_group_name = "";

            if !getVertexAttribute(*line, group, .POSITION, name) {
                return false;
            }
        } else if String.starts_with(line, "vt ") {
            advance(*line, "vt ".count);
            trimLeft(*line);

            if !line {
                errorMessage("\"%.obj\": Line with vertex texture coordinate does not have any data", name);
                return false;
            }

            group := getVertexGroup(model, new_group_name);
            new_group_name = "";

            if !getVertexAttribute(*line, group, .TEXCOORD, name) {
                return false;
            }
        } else if String.starts_with(line, "vn ") {
            advance(*line, "vn ".count);
            trimLeft(*line);

            if !line {
                errorMessage("\"%.obj\": Line with vertex normal does not have any data", name);
                return false;
            }

            group := getVertexGroup(model, new_group_name);
            new_group_name = "";

            if !getVertexAttribute(*line, group, .NORMAL, name) {
                return false;
            }
        } else if String.starts_with(line, "f ") {
            advance(*line, "f ".count);
            trimLeft(*line);

            if !line {
                errorMessage("\"%.obj\": Line with face does not have any data", name);
                return false;
            }

            group := getFaceGroup(model, new_group_name);
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

    if model.vertex_groups.count <= 0 {
        errorMessage("\"%.obj\": No vertex data found in file", name);
        return false;
    }

GROUPS_COUNT_ERROR_STRING :: #string END
"%.obj": We do not support different number of vertex and face groups except when number of vertex groups is 1 or number of face groups is 0.
    Number of vertex groups: %
    Number of face groups:   %
END;
    if model.vertex_groups.count != model.face_groups.count && model.face_groups.count > 0 && model.vertex_groups.count > 1 {
        errorMessage(GROUPS_COUNT_ERROR_STRING, name, model.vertex_groups.count, model.face_groups.count);
        return false;
    }

    for model.face_groups {
        if it.triplets.count % 3 {
            errorMessage("\"%.obj\": Expected triplets count be multiple of 3. Face group '%' (#%), triplets count: %",
                         name,
                         it_index,
                         it.triplets.count);
            return false;
        }
    }

    return true;
}

getVertexAttribute :: (line : *string, group : *ObjModel.VertexGroup, attribute : ObjModel.Attribute, name : string) -> bool {
    if !line.* return true;

    attribute_data : v3f;
    for * attribute_data.e {
        if !line.* break;

        it.*, success:, line.* = Basic.string_to_float(line.*);
        if !success {
            errorMessage("\"%.obj\": Failed to parse #% component of vertex % attribute", name, it_index, attribute);
            return false;
        }
        trimLeft(line);
    }

    Basic.array_add(*group.attributes[attribute], attribute_data);
    return true;
}

getTriplets :: (line : *string, group : *ObjModel.FaceGroup, name : string) -> bool {
    triplets       : [4] ObjModel.Triplet;
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
                errorMessage("\"%.obj\": We do not support negative indices yet (index for % attribute)", name, cast(ObjModel.Attribute) it_index);
                return false;
            }

            index : u32;
            while line.* {
                char := line.*[0];

                if char < #char "0" || char > #char "9" {
                    if index break;

                    errorMessage("\"%.obj\": Failed to parse index for % attribute: unexpected character '%', expected digit",
                                 name,
                                 cast(ObjModel.Attribute) it_index,
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

        trimLeft(line);
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

getVertexGroup :: (obj_model : *ObjModel, group_name : string) -> *ObjModel.VertexGroup {
    if obj_model.vertex_groups.count <= 0 {
        group := Basic.array_add(*obj_model.vertex_groups);
        group.name = group_name;

        return group;
    }

    if group_name {
        for * obj_model.vertex_groups {
            if it.name == group_name {
                return it;
            }
        }

        group := Basic.array_add(*obj_model.vertex_groups);
        group.name = group_name;

        return group;
    }

    return *obj_model.vertex_groups[obj_model.vertex_groups.count - 1];
}

getFaceGroup :: (obj_model : *ObjModel, group_name : string) -> *ObjModel.FaceGroup {
    if obj_model.face_groups.count <= 0 {
        group := Basic.array_add(*obj_model.face_groups);
        group.name = group_name;

        return group;
    }

    if group_name {
        for * obj_model.face_groups {
            if it.name == group_name {
                return it;
            }
        }

        group := Basic.array_add(*obj_model.face_groups);
        group.name = group_name;

        return group;
    }

    return *obj_model.face_groups[obj_model.face_groups.count - 1];
}

remapTriplets :: (obj_model : ObjModel) -> (
    vertices : [..] VertexTypes.PNTUV,
    indices  : [..] u32
) {
    triplet_to_index : Hash_Table.Table(ObjModel.Triplet, u32, given_compare_function = (a : ObjModel.Triplet, b : ObjModel.Triplet) -> bool {
        return !memcmp(a.data, b.data, size_of(ObjModel.Triplet));
    });
    defer Hash_Table.deinit(*triplet_to_index);

    vertices : [..] VertexTypes.PNTUV;
    indices  : [..] u32;

    Basic.array_reserve(*vertices, 1_000_000);
    Basic.array_reserve(*indices,  1_000_000);

    for face_group, group_index : obj_model.face_groups {
        assert(face_group.triplets.count > 0);

        Hash_Table.table_reset(*triplet_to_index);

        vertex_group := ifx  obj_model.vertex_groups.count == 1
                        then *obj_model.vertex_groups[0]
                        else *obj_model.vertex_groups[group_index];

        vertex_positions := *vertex_group.attributes[ObjModel.Attribute.POSITION];
        vertex_texcoords := *vertex_group.attributes[ObjModel.Attribute.TEXCOORD];
        vertex_normals   := *vertex_group.attributes[ObjModel.Attribute.NORMAL];

        for triplet : face_group.triplets {
            vertex_index_ptr := Hash_Table.table_find_pointer(*triplet_to_index, triplet);

            if !vertex_index_ptr {
                vertex_index_ptr = Hash_Table.table_add(*triplet_to_index, triplet, cast(u32) vertices.count);

                position_index := triplet[ObjModel.Attribute.POSITION];
                texcoord_index := triplet[ObjModel.Attribute.TEXCOORD];
                normal_index   := triplet[ObjModel.Attribute.NORMAL];

                assert(position_index > 0, "Obj files store indices starting with 1");
                assert(texcoord_index > 0, "Obj files store indices starting with 1");
                assert(normal_index   > 0, "Obj files store indices starting with 1");

                position_index -= 1;
                texcoord_index -= 1;
                normal_index   -= 1;

                texcoord := vertex_texcoords.*[texcoord_index];

                new_vertex := Basic.array_add(*vertices);
                new_vertex.position_u.xyz = vertex_positions.*[position_index];
                new_vertex.position_u.w   = texcoord.x;
                new_vertex.normal_v.xyz   = vertex_normals.*[normal_index];
                new_vertex.normal_v.w     = texcoord.y;
            }

            assert(vertex_index_ptr);
            Basic.array_add(*indices, vertex_index_ptr.*);
        }
    }

    return vertices, indices;
}

convertVertices :: (obj_model : ObjModel, name : string) -> (vertices : [..] VertexTypes.PNTUV, indices : [..] u32) {
    vertices : [..] VertexTypes.PNTUV;
    indices  : [..] u32;

    Basic.array_reserve(*vertices, 1_000_000);
    Basic.array_reserve(*indices,  1_000_000);

    for obj_model.vertex_groups {
        vertex_positions := *it.attributes[ObjModel.Attribute.POSITION];
        vertex_texcoords := *it.attributes[ObjModel.Attribute.TEXCOORD];
        vertex_normals   := *it.attributes[ObjModel.Attribute.NORMAL];

        vertex_texcoords_it := vertex_texcoords.data;
        vertex_normals_it   := vertex_normals.data;

        assert(vertex_positions.count == vertex_texcoords.count && vertex_positions.count == vertex_normals.count,
               "\"%.obj\": Number of elements in streams are not the same. Vertex group #%: \"%\"",
               name, it_index, it.name);

        for vertex_positions.* {
            // @TODO: #ModelIndices.
            Basic.array_add(*indices, cast(u32) vertices.count);

            new_vertex := Basic.array_add(*vertices);
            new_vertex.position_u.xyz = it;
            new_vertex.position_u.w   = vertex_texcoords_it.x;
            new_vertex.normal_v.xyz   = vertex_normals_it.*;
            new_vertex.normal_v.w     = vertex_texcoords_it.y;

            vertex_texcoords_it += 1;
            vertex_normals_it   += 1;
        }
    }

    return vertices, indices;
}
