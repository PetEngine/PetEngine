#scope_export

File :: struct {
    Flags :: enum_flags u16 {
        // Access (required)
        READ;
        WRITE;

        // Shared (across processes) access (optional)
        SHARED_READ;
        SHARED_WRITE;
        SHARED_DELETE;
        SHARED_MOVE :: SHARED_DELETE;

        // Open behaviour (optional)
        EXISTS;   // A file will be opened only if it exists.   (There is no sense to combine it with NEW flag)
        NEW;      // Creates a file only if it does not exists. (There is no sense to open a file with this flag, but without WRITE flag).
        TRUNCATE; // Truncate a file on open. Must be combined with WRITE flag.

        // Internal OS behaviour (optional)
        RAND;     // Optimized for a random access (no prefetch). There is no sence to combine it with SEQ flag.
        SEQ;      // Optimized for a sequential access (prefetch 2 times more data than without). There is no sence to combine it with RAND flag.
        TEMP;     // File will be deleted on close.
        FLUSH;    // Flush data immediatly to disk after writing it to system cache.
    }

    Error :: enum u8 {
        NONE      :: 0;
        UNHANDLED :: 1;

        FILE_NOT_FOUND;
        PATH_NOT_FOUND;
        ALREADY_EXISTS;
        SHARED_ACCESS_VIOLATION;
    }

    Info :: struct(path_kind : PathKind = .ABSOLUTE) {
        path             : string;
        creation_time    : Basic.Apollo_Time;
        last_access_time : Basic.Apollo_Time;
        last_write_time  : Basic.Apollo_Time;
        size             : u64;
        attributes       : enum_flags u8 {
            READ_ONLY;
            HIDDEN;
            SYSTEM;
            ARCHIVE;
            DIRECTORY;
            DEVICE;
            TEMPORARY;
            SYMLINK;
        };
    }

    #if OS == .WINDOWS {
        handle : HANDLE = INVALID_HANDLE_VALUE;
    }
}

PathKind :: enum u8 {
    RELATIVE;
    ABSOLUTE;
}

// create_path_if_does_not_exist have sense only if you do NOT specify EXISTS flag.
openFile :: (filename : string, flags : File.Flags, $create_path_if_does_not_exist := false) -> (File, File.Error) {
    #if OS == .WINDOWS {
        file, error := openWindowsFile(filename, flags, create_path_if_does_not_exist);
    } else {
        notImplemented();
    }

    return file, error;
}

closeFile :: (file : *File) {
    #if OS == .WINDOWS {
        closeWindowsFile(file);
    } else {
        notImplemented();
    }
}

readFile :: (file : File, buffer : *void, bytes : s64) {
    #if OS == .WINDOWS {
        readWindowsFile(file, buffer, bytes);
    } else {
        notImplemented();
    }
}

readFile :: inline (file : File, buffer : string) {
    readFile(file, buffer.data, buffer.count);
}

readFile :: inline (file : File, buffer : [] $T) {
    readFile(file, buffer.data, buffer.count * size_of(T));
}

readFile :: inline (file : File, data : *$T) {
    readFile(file, data, size_of(T));
}

readEntireFile :: (
    filename  : string,
    allocate  : (user_data : *$T, bytes : s64, alignment : s64) -> *void,
    user_data : *T
) -> (string, File.Error) {
    buffer : string;

    file, error := openFile(filename, .READ | .SHARED_READ | .EXISTS | .SEQ);

    if error == .NONE {
        buffer.count = getFileSize(file);

        if buffer.count > 0 {
            buffer.data = allocate(user_data, buffer.count, DEFAULT_CACHE_LINE_SIZE);
            readFile(file, buffer);
        }

        closeFile(*file);
    }

    return buffer, error;
}

writeFile :: (file : File, data : *void, bytes : s64) {
    #if OS == .WINDOWS {
        writeWindowsFile(file, data, bytes);
    } else {
        notImplemented();
    }
}

writeFile :: inline (file : File, data : string) {
    writeFile(file, data.data, data.count);
}

writeFile :: inline (file : File, data : [] $T) {
    writeFile(file, data.data, data.count * size_of(T));
}

writeFile :: inline (file : File, data : *$T) {
    writeFile(file, data, size_of(T));
}

writeFile :: (file : File, builder : *Basic.String_Builder, $reset := true) {
    buffer := Basic.get_base_buffer(builder);
    while buffer {
        writeFile(file, Basic.get_buffer_data(buffer), buffer.count);
        buffer = buffer.next;
    }

    #if reset {
        Basic.reset(builder);
    }
}

getFileSize :: (file : File) -> s64 {
    file_size : s64;

    #if OS == .WINDOWS {
        file_size = getWindowsFileSize(file);
    } else {
        notImplemented();
    }

    return file_size;
}

getFileCursorPosition :: (file : File) -> s64 {
    position : s64;

    #if OS == .WINDOWS {
        position = getWindowsFileCursorPosition(file);
    } else {
        notImplemented();
    }

    return position;
}

FileOffset :: enum u32 #specified {
    BEGIN   :: 0;
    CURRENT :: 1;
    END     :: 2;
}

setFileCursorPosition :: (file : File, offset : FileOffset, position : s64) -> s64 {
    new_position : s64;

    #if OS == .WINDOWS {
        #assert FileOffset.BEGIN   == FILE_BEGIN
             && FileOffset.CURRENT == FILE_CURRENT
             && FileOffset.END     == FILE_END;

        new_position = setWindowsFileCursorPosition(file, cast(u32) offset, position);
    } else {
        notImplemented();
    }

    return new_position;
}

EnumerateFilesCallbackResult :: enum u8 {
    CONTINUE;
    BREAK;
}

enumerateFiles :: inline (
    directory         : string,
    callback          : (user_data : *$T, file_info : File.Info(.RELATIVE)) -> EnumerateFilesCallbackResult,
    user_data         : *T = null,
    $recursively      := false,
    $skip_directories := true,
    $skip_symlinks    := true
) -> File.Error {
    #if OS == .WINDOWS {
        return enumerateWindowsFiles(directory, callback, user_data, recursively, skip_directories, skip_symlinks);
    } else {
        notImplemented();
    }
}

getFileInfo :: (filename : string) -> (File.Info(.ABSOLUTE), File.Error) {
    file_info : File.Info;
    file_info.path = filename;

    #if OS == .WINDOWS {
        error := getWindowsFileInfo(*file_info);
    } else {
        notImplemented();
    }

    return file_info, error;
}

getFileInfo :: (file : File) -> (File.Info(.ABSOLUTE), File.Error) {
    file_info : File.Info;

    #if OS == .WINDOWS {
        error := getWindowsFileInfo(file, *file_info);
    } else {
        notImplemented();
    }

    return file_info, error;
}

fileExists :: (filename : string) -> bool {
    exists : bool;

    #if OS == .WINDOWS {
        exists = windowsFileExists(filename);
    } else {
        notImplemented();
    }

    return exists;
}

getAbsolutePath :: (
    relative_path : string,
    allocate      : (user_data : *$T, bytes : s64, alignment : s64) -> *void,
    user_data     : *T
) -> string {
    if !relative_path || isAbsolutePath(relative_path) {
        return relative_path;
    }

    absolute_path : string;

    #if OS == .WINDOWS {
        absolute_path = getWindowsAbsolutePath(relative_path, allocate, user_data);
    } else {
        notImplemented();
    }

    return absolute_path;
}

isAbsolutePath :: (path : string) -> bool #no_context #no_abc {
    #if OS == .WINDOWS {
        DOS_PREFIX_1 : u16 : #char ":" | (#char "/"  << 8);
        DOS_PREFIX_2 : u16 : #char ":" | (#char "\\" << 8);

        is_dos := path.count >= 3
               && (   (cast,no_check(*u16) (path.data + 1)).* == DOS_PREFIX_1
                   || (cast,no_check(*u16) (path.data + 1)).* == DOS_PREFIX_2)
               && isAlpha(path[0]);

        UNC_PREFIX_1 : u16 : #char "\\" | (#char "\\" << 8);
        UNC_PREFIX_2 : u16 : #char "/"  | (#char "/"  << 8);

        is_unc := path.count >= 2
               && (   (cast,no_check(*u16) path.data).* == UNC_PREFIX_1
                   || (cast,no_check(*u16) path.data).* == UNC_PREFIX_2);

        return is_dos || is_unc;
    } else {
        return path.count >= 1 && path[0] == #char "/";
    }
}

createDirectory :: (filename : string) {
    #if OS == .WINDOWS {
        createWindowsDirectory(filename);
    } else {
        notImplemented();
    }
}

#scope_file

#if OS == .WINDOWS {
    #load "windows/file.jai";
} else {
    notImplemented();
}
