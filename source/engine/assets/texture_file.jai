// File structure: [header|offsets|data]
// offsets are written only if total number of surfaces > 1
TextureFile :: struct {
    VERSION :: 1;

    Header :: struct {
        version        : u8 = VERSION;
        format         : Texture.Format;
        flags          : Texture.Flags;
        mips_count     : u8;
        width          : u16;
        height         : u16;
        union {
            depth      : u16;
            array_size : u16;
        }
    } #no_padding

    file            : File;
    surface_cursor  : s64;
    surface_offsets : [] u64;

    getHeader :: inline (file_data : string) -> *Header {
        return cast(*Header) file_data.data;
    }
}

beginTextureFileSerialization :: (name : string) -> TextureFile, bool {
    filename := makeRuntimeTextureFilename(name);

    file, error := openFile(filename, .WRITE | .TRUNCATE | .SEQ, true);
    if error != .NONE {
        errorMessage("Failed to open runtime texture file: \"%\". Error: %", filename, error);
        return .{}, false;
    }

    return .{ file = file }, true;
}

endTextureFileSerialization :: (texture_file : *TextureFile) {
    if texture_file.surface_offsets.count > 0 {
        setFileCursorPosition(texture_file.file, .BEGIN, size_of(TextureFile.Header));
        writeFile(texture_file.file, texture_file.surface_offsets);
    }
    closeFile(*texture_file.file);
}

writeTextureFileHeader :: (texture_file : *TextureFile, header : TextureFile.Header) {
    writeFile(texture_file.file, *header);

    surfaces_count : s64 = header.mips_count;
    if header.flags & .ARRAY then surfaces_count *= header.array_size;
    if header.flags & .CUBE  then surfaces_count *= 6;

    if surfaces_count > 1 {
        texture_file.surface_offsets.count = surfaces_count - 1;
        texture_file.surface_offsets.data  = pushToArena(*context.pet.arenas.per_frame, u64, texture_file.surface_offsets.count);

        setFileCursorPosition(texture_file.file, .CURRENT, texture_file.surface_offsets.count * size_of(u64));
    } else {
        assert(surfaces_count == 1);
    }
}

appendTextureFileData :: (texture_file : *TextureFile, data : [] u8) {
    writeFile(texture_file.file, data);

    if !texture_file.surface_offsets {
        return;
    }

    if texture_file.surface_cursor == 0 {
        texture_offset      := size_of(TextureFile.Header) + texture_file.surface_offsets.count * size_of(u64);
        next_surface_offset := texture_offset + data.count;
        texture_file.surface_offsets[0] = cast(u64) next_surface_offset;
    } else if texture_file.surface_cursor < texture_file.surface_offsets.count {
        assert(texture_file.surface_cursor > 0);

        this_surface_offset := texture_file.surface_offsets[texture_file.surface_cursor - 1];
        next_surface_offset := this_surface_offset + cast(u64) data.count;
        texture_file.surface_offsets[texture_file.surface_cursor] = next_surface_offset;
    }

    texture_file.surface_cursor += 1;
}
