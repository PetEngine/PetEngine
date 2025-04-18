TextureFile :: struct {
    VERSION :: 1;

    Header :: struct {
        version         : u8 = VERSION;
        dimension       : Texture.Dimension;
        format          : Texture.Format;
        flags           : Texture.Flags;
        width           : u16;
        height          : u16;
        union {
            depth       : u16;
            array_size  : u16;
        }
        mips_count      : u8;
    } #no_padding

    file : File;

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
    closeFile(*texture_file.file);
}

writeTextureFileHeader :: (texture_file : *TextureFile, header : TextureFile.Header) {
    writeFile(texture_file.file, *header);
}

appendTextureFileData :: (texture_file : *TextureFile, data : [] u8) {
    writeFile(texture_file.file, data);
}
