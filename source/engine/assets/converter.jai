// @TODO: #AssetConverter.
//    - Materials
//    - #ThreadPool.

AssetConverter :: struct {
    VERSION :: 1;

    EXCHANGE_MESHES_FOLDER :: "../../../source/assets/meshes/exchange";
    RUNTIME_MESHES_FOLDER  :: "../../../source/assets/meshes/runtime";
}

convertExchangeAssetsToRuntime :: () {
    if fileExists(AssetConverter.EXCHANGE_MESHES_FOLDER) {
        enumerateFiles(AssetConverter.EXCHANGE_MESHES_FOLDER, convertMeshesCallback, null, recursively = true);
    } else {
        verboseMessage("Exchange meshes folder is not found: %", AssetConverter.EXCHANGE_MESHES_FOLDER);
    }
}

makeRuntimeMeshFilename :: (name : string) -> string {
    capacity := AssetConverter.RUNTIME_MESHES_FOLDER.count + "/".count + name.count + ".mesh".count;

    filename := string.{ data = pushToArena(*context.pet.per_frame_arena, capacity) };
    appendToString(*filename, capacity, AssetConverter.RUNTIME_MESHES_FOLDER, "/", name, ".mesh");

    return filename;
}

#load "mesh_file.jai";

#scope_file

convertMeshesCallback :: (user_data : *void, exchange_file_info : *FileInfo) -> EnumerateFilesCallbackResult {
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

    if !success {
        errorMessage("Failed to convert %1.%2 to %1.mesh", mesh_name, extension);
    }

    return .CONTINUE;
}

#load "obj_mesh.jai";
