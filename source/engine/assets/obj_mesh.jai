convertObjMesh :: (exchange_filename : string, name : string) -> bool {
    infoMessage("Converting \"%.obj\"...", name);

    data, error := readEntireFile(exchange_filename, pushToArena, *context.pet.per_frame_arena);
    assert(error == .NONE, "The error must be NONE because we know that the file exists");

    obj_mesh : ObjMesh;
    // @TODO, @Continue: ...

    infoMessage("\"%.obj\" has been converted", name);
    return true;
}

#scope_file

ObjMesh :: struct {
}
