#scope_export

// @TODO: #File.
//     1. Try more secure *FromAppW functions.
//     2. Remove MAX_PATH limit prepending \\?\ to the filename when filename.count >= MAX_PATH.

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

    #if OS == .WINDOWS {
        handle : HANDLE = INVALID_HANDLE_VALUE;
    }
}

// create_path_if_does_not_exist have sense only if you do NOT specify EXISTS flag.
openFile :: (filename : string, flags : File.Flags, $create_path_if_does_not_exist := false) -> (File #must, File.Error #must) {
    file : File;

    #if OS == .WINDOWS {
        assert(filename.count < MAX_PATH, "Too long filename (length = %), max allowed: %", filename.count, MAX_PATH - 1);

        wide_filename : [] WCHAR;
        wide_filename.data = pushToArena(*context.pet.per_frame_arena, WCHAR, filename.count + 1);
        asciiToWide(*wide_filename, filename, true);

        desired_access, shared_access, creation_disposition, flags_and_attributes := flagsToWin32Flags(flags);

        file.handle = CreateFileW(wide_filename.data, desired_access, shared_access, null, creation_disposition, flags_and_attributes, null);
        if file.handle == INVALID_HANDLE_VALUE {
            if GetLastError() == {
                case ERROR_FILE_NOT_FOUND;
                    assert(flags & .EXISTS);
                    errorMessage("File \"%\" was tried to be opened with flag EXISTS but it does not exist", filename);
                    return file, .FILE_NOT_FOUND;

                case ERROR_PATH_NOT_FOUND;
                    #if create_path_if_does_not_exist {
                        warningMessage("Path to file \"%\" does not exist, so it will be created", filename);

                        createPathForFilename(*wide_filename);

                        file.handle = CreateFileW(wide_filename.data, desired_access, shared_access, null, creation_disposition, flags_and_attributes, null);
                        if file.handle == INVALID_HANDLE_VALUE {
                            errorMessage("File \"%\" cannot be opened", filename, print_sys_error = true);
                            return file, .UNHANDLED;
                        }
                    } else {
                        return file, .PATH_NOT_FOUND;
                    }

                case ERROR_SHARING_VIOLATION;
                    return file, .SHARED_ACCESS_VIOLATION;

                case ERROR_FILE_EXISTS;
                    assert(flags & .NEW);
                    errorMessage("File \"%\" was tried to be opened with flag NEW which guarantees that file does not exist, but it does exist",
                                 filename);
                    return file, .ALREADY_EXISTS;

                case;
                    errorMessage("File \"%\" cannot be opened", filename, print_sys_error = true);
                    return file, .UNHANDLED;
            }
        }
    } else {
        notImplemented();
    }

    return file, .NONE;
}

closeFile :: (file : *File) {
    #if OS == .WINDOWS {
        debugCheck(CloseHandle(file.handle), print_sys_error = true);
        file.handle = INVALID_HANDLE_VALUE;
    } else {
        notImplemented();
    }
}

readFile :: (file : File, data : *void, bytes : s64) {
    #if OS == .WINDOWS {
        debugCheck(ReadFile(file.handle, data, cast(u32) bytes, null, null), print_sys_error = true);
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

readEntireFile :: (
    filename  : string,
    allocate  : (user_data : *$T, bytes : s64) -> *void,
    user_data : *T
) -> (string #must, File.Error #must) {
    buffer : string;

    file, error := openFile(filename, .READ | .SHARED_READ | .EXISTS | .SEQ);

    if error == .NONE {
        buffer.count = fileSize(file);

        if buffer.count > 0 {
            buffer.data = allocate(user_data, buffer.count);
            readFile(file, buffer);
        }

        closeFile(*file);
    }

    return buffer, error;
}

writeFile :: (file : File, data : *void, bytes : s64) {
    #if OS == .WINDOWS {
        debugCheck(WriteFile(file.handle, data, cast(u32) bytes, null, null), print_sys_error = true);
    } else {
        notImplemented();
    }
}

writeFile :: inline (file : File, buffer : string) {
    writeFile(file, buffer.data, buffer.count);
}

writeFile :: inline (file : File, buffer : [] $T) {
    writeFile(file, buffer.data, buffer.count * size_of(T));
}

fileSize :: (file : File) -> s64 {
    file_size : s64;

    #if OS == .WINDOWS {
        debugCheck(GetFileSizeEx(file.handle, cast(*LARGE_INTEGER) *file_size), print_sys_error = true);
    } else {
        notImplemented();
    }

    return file_size;
}

FileInfo :: struct {
    name             : string;
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

// @Cleanup: #Naming. Shorter name?
EnumerateFilesCallbackResult :: enum u8 {
    CONTINUE;
    BREAK;
}

enumerateFiles :: inline (
    $$directory       : string,
    callback          : (user_data : *$T, file_info : *FileInfo) -> EnumerateFilesCallbackResult,
    user_data         : *T,
    $case_sensitive   := true,
    $recursively      := false,
    $skip_directories := true,
    $skip_symlinks    := true
) {
    #if OS == .WINDOWS {
        enumerateWindowsFiles(directory, callback, user_data, case_sensitive, recursively, skip_directories, skip_symlinks);
    } else {
        notImplemented();
    }
}

// @TODO: getFileInfo :: (file : File) -> (FileInfo, File.Error);
getFileInfo :: (filename : string) -> (FileInfo, File.Error) {
    file_info := FileInfo.{ name = filename };

    #if OS == .WINDOWS {
        assert(filename.count < MAX_PATH, "Too long filename (length = %), max allowed: %", filename.count, MAX_PATH - 1);

        wide_filename : [MAX_PATH] WCHAR;
        asciiToWide(*wide_filename, filename, true);

        attribute_data : WIN32_FILE_ATTRIBUTE_DATA = ---;
        if !GetFileAttributesExW(wide_filename.data, .GetFileExInfoStandard, *attribute_data) {
            file_error : File.Error = ---;

            if GetLastError() == {
                case ERROR_FILE_NOT_FOUND;    file_error = .FILE_NOT_FOUND;
                case ERROR_PATH_NOT_FOUND;    file_error = .PATH_NOT_FOUND;
                case ERROR_SHARING_VIOLATION; file_error = .SHARED_ACCESS_VIOLATION;
                case;
                    errorMessage("GetFileAttributesExW failed for file \"%\"", filename, print_sys_error = true);
                    file_error = .UNHANDLED;
            }

            return file_info, file_error;
        }

        gatherFileInfo(*file_info, *attribute_data);
    } else {
        notImplemented();
    }

    return file_info, .NONE;
}

fileExists :: (filename : string) -> bool {
    #if OS == .WINDOWS {
        wide_filename : [] WCHAR;
        wide_filename.data = pushToArena(*context.pet.per_frame_arena, WCHAR, filename.count + 1);
        asciiToWide(*wide_filename, filename, true);

        // PathFileExists just does "return GetFileAttributes(filename) != INVALID_FILE_ATTRIBUTES;",
        // so we won't use it as it requires one more library to link
        return GetFileAttributesW(wide_filename.data) != INVALID_FILE_ATTRIBUTES;
    } else {
        notImplemented();
    }
}

#scope_file

#if OS == .WINDOWS {
    flagsToWin32Flags :: (flags : File.Flags) -> (
        desired_access       : u32,
        shared_access        : u32,
        creation_disposition : u32,
        flags_and_attributes : u32
    ) {
        assert(flags & (.READ | .WRITE), "A file must be opened with READ and/or WRITE flags");

        desired_access       : u32;
        shared_access        : u32;
        creation_disposition : u32;
        flags_and_attributes : u32 = FILE_ATTRIBUTE_NORMAL;

        // @Important: Until we do not use remote files we are good, but when we will, we should use GENERIC_READ | GENERIC_WRITE
        //             instead of just GENERIC_WRITE:
        //             https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilew#:~:text=When%20an%20application%20creates,occasionally%20return%20ERROR_ACCESS_DENIED.&text=When%20an%20application%20creates,occasionally%20return%20ERROR_ACCESS_DENIED.
        if flags & .READ  desired_access |= GENERIC_READ;
        if flags & .WRITE desired_access |= GENERIC_WRITE;

        if flags & .SHARED_READ   shared_access |= FILE_SHARE_READ;
        if flags & .SHARED_WRITE  shared_access |= FILE_SHARE_WRITE;
        if flags & .SHARED_DELETE shared_access |= FILE_SHARE_DELETE;

        // CREATE_NEW        - if (exists) fails,     ERROR_FILE_EXISTS    else creates
        // CREATE_ALWAYS     - if (exists) truncates, ERROR_ALREADY_EXISTS else creates
        // OPEN_EXISTING     - if (exists) succeeds                        else fails,  ERROR_FILE_NOT_FOUND
        // OPEN_ALWAYS       - if (exists) succeeds,  ERROR_ALREADY_EXISTS else creates
        // TRUNCATE_EXISTING - if (exists) truncates                       else fails,  ERROR_FILE_NOT_FOUND. Must have GENERIC_WRITE.
        if flags & .EXISTS {
            if flags & .TRUNCATE {
                assert(flags & .WRITE, "For truncating an existing file, you have to open it with the write access");
                creation_disposition = TRUNCATE_EXISTING;
            } else {
                creation_disposition = OPEN_EXISTING;
            }
        } else if flags & .NEW {
            if !(flags & .WRITE) {
                warningMessage("You are going to create a new file, but without write access to it. Is that on purpose?");
            }
            creation_disposition = CREATE_NEW;
        } else if flags & .TRUNCATE {
            creation_disposition = CREATE_ALWAYS;
        } else {
            creation_disposition = OPEN_ALWAYS;
        }

        if flags & .RAND {
            flags_and_attributes |= FILE_FLAG_RANDOM_ACCESS;
        } else if flags & .SEQ {
            flags_and_attributes |= FILE_FLAG_SEQUENTIAL_SCAN;
        }

        if flags & .TEMP {
            assert(flags & .SHARED_DELETE, "For temporary files shared delete access is required");
            flags_and_attributes |= FILE_ATTRIBUTE_TEMPORARY
                                 |  FILE_FLAG_DELETE_ON_CLOSE;
        }

        if flags & .FLUSH {
            flags_and_attributes |= FILE_FLAG_WRITE_THROUGH;
        }

        // FILE_ATTRIBUTE_NORMAL is valid only when used alone
        if flags_and_attributes & ~FILE_ATTRIBUTE_NORMAL {
            flags_and_attributes &= ~FILE_ATTRIBUTE_NORMAL;
        }

        return desired_access, shared_access, creation_disposition, flags_and_attributes;
    }

    createPathForFilename :: (wide_filename : *[] WCHAR) {
        for * < wide_filename.* {
            if it.* == #char "/" || it.* == #char "\\" {
                old_symbol := it.*;
                old_length := wide_filename.count;

                it.*                = 0;
                wide_filename.count = it_index;

                if CreateDirectoryW(wide_filename.data, null) {
                    wide_filename.count = old_length;
                    it.*                = old_symbol;
                } else {
                    assert(GetLastError() == ERROR_PATH_NOT_FOUND, print_sys_error = true);

                    createPathForFilename(wide_filename);

                    wide_filename.count = old_length;
                    it.*                = old_symbol;

                    debugCheck(CreateDirectoryW(wide_filename.data, null), print_sys_error = true);
                }

                break;
            }
        }
    }

    enumerateWindowsFiles :: (
        $$directory       : string,
        callback          : (user_data : *$T, file_info : *FileInfo) -> EnumerateFilesCallbackResult,
        user_data         : *T,
        $case_sensitive   : bool,
        $recursively      : bool,
        $skip_directories : bool,
        $skip_symlinks    : bool
    ) -> EnumerateFilesCallbackResult {
        #if is_constant(directory) {
            wide_wildcard : [directory.count + "/*\0".count] WCHAR;
            asciiToWide(*wide_wildcard, directory, false);
        } else {
            wide_wildcard : [] WCHAR;
            wide_wildcard.data = pushToArena(*context.pet.per_frame_arena, WCHAR, directory.count + "/*\0".count);
            asciiToWide(*wide_wildcard, directory, false);

            wide_wildcard.count += "/*\0".count;
        }

        wide_wildcard[directory.count + 0] = #char "/";
        wide_wildcard[directory.count + 1] = #char "*";
        wide_wildcard[directory.count + 2] = 0;

        additional_flags := FIND_FIRST_EX_LARGE_FETCH;
        #if case_sensitive additional_flags |= FIND_FIRST_EX_CASE_SENSITIVE;

        find_data : WIN32_FIND_DATAW;
        find_file := FindFirstFileExW(wide_wildcard.data, .FindExInfoBasic, *find_data, .FindExSearchNameMatch, null, additional_flags);
        assert(find_file != INVALID_HANDLE_VALUE, print_sys_error = true);

        filename_buffer : [MAX_PATH] u8;

        file_info : FileInfo;
        file_info.name.data = filename_buffer.data;

        result : EnumerateFilesCallbackResult = .CONTINUE;
        while true {
            wideToAscii(*file_info.name, filename_buffer.count, find_data.cFileName.data, wideLength(find_data.cFileName));

            // Make file_info.name "<directory>/<relative_name>"
            assert(directory.count + 1 + file_info.name.count <= filename_buffer.count);
            memcpy(file_info.name.data + directory.count + 1, file_info.name.data, file_info.name.count);
            memcpy(file_info.name.data, directory.data, directory.count);
            file_info.name.count += directory.count + 1;
            #no_abc { file_info.name[directory.count] = #char "/"; }

            relative_name := string.{ file_info.name.count - (directory.count + 1), *file_info.name[directory.count + 1] };

            if find_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY {
                if relative_name != "." && relative_name != ".." {
                    #if !skip_directories {
                        gatherFileInfo(*file_info, *find_data, true);

                        #if skip_symlinks {
                            if !(file_info.attributes & .SYMLINK) {
                                result = callback(user_data, *file_info);
                                if result == .BREAK break;
                            }
                        } else {
                            result = callback(user_data, *file_info);
                            if result == .BREAK break;
                        }
                    }

                    #if recursively {
                        result = enumerateWindowsFiles(file_info.name,
                                                       callback,
                                                       user_data,
                                                       case_sensitive,
                                                       recursively,
                                                       skip_directories,
                                                       skip_symlinks);
                        if result == .BREAK break;
                    }
                }
            } else {
                gatherFileInfo(*file_info, *find_data, false);

                #if skip_symlinks {
                    if !(file_info.attributes & .SYMLINK) {
                        result = callback(user_data, *file_info);
                        if result == .BREAK break;
                    }
                } else {
                    result = callback(user_data, *file_info);
                    if result == .BREAK break;
                }
            }

            if !FindNextFileW(find_file, *find_data) {
                assert(GetLastError() == ERROR_NO_MORE_FILES, print_sys_error = true);
                break;
            }
        }

        debugCheck(FindClose(find_file), print_sys_error = true);
        return result;
    }

    gatherFileInfo :: (file_info : *FileInfo, find_data : *WIN32_FIND_DATAW, $is_directory : bool) {
        file_info.creation_time    = Basic.filetime_to_apollo(xx find_data.ftCreationTime);
        file_info.last_access_time = Basic.filetime_to_apollo(xx find_data.ftLastAccessTime);
        file_info.last_write_time  = Basic.filetime_to_apollo(xx find_data.ftLastWriteTime);

        file_info.size = (cast(u64) find_data.nFileSizeHigh << 32) | find_data.nFileSizeLow;

        file_info.attributes = 0;
        if find_data.dwFileAttributes & FILE_ATTRIBUTE_READONLY then file_info.attributes |= .READ_ONLY;
        if find_data.dwFileAttributes & FILE_ATTRIBUTE_HIDDEN   then file_info.attributes |= .HIDDEN;
        if find_data.dwFileAttributes & FILE_ATTRIBUTE_SYSTEM   then file_info.attributes |= .SYSTEM;
        if find_data.dwFileAttributes & FILE_ATTRIBUTE_ARCHIVE  then file_info.attributes |= .ARCHIVE;

        #if is_directory {
            file_info.attributes |= .DIRECTORY;
        }

        if find_data.dwFileAttributes & FILE_ATTRIBUTE_DEVICE    then file_info.attributes |= .DEVICE;
        if find_data.dwFileAttributes & FILE_ATTRIBUTE_TEMPORARY then file_info.attributes |= .TEMPORARY;

        if (find_data.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) && find_data.dwReserved0 == IO_REPARSE_TAG_SYMLINK {
            file_info.attributes |= .SYMLINK;
        }
    }

    gatherFileInfo :: (file_info : *FileInfo, attribute_data : *WIN32_FILE_ATTRIBUTE_DATA) {
        file_info.creation_time    = Basic.filetime_to_apollo(xx attribute_data.ftCreationTime);
        file_info.last_access_time = Basic.filetime_to_apollo(xx attribute_data.ftLastAccessTime);
        file_info.last_write_time  = Basic.filetime_to_apollo(xx attribute_data.ftLastWriteTime);

        file_info.size = (cast(u64) attribute_data.nFileSizeHigh << 32) | attribute_data.nFileSizeLow;

        file_info.attributes = 0;
        if attribute_data.dwFileAttributes & FILE_ATTRIBUTE_READONLY  then file_info.attributes |= .READ_ONLY;
        if attribute_data.dwFileAttributes & FILE_ATTRIBUTE_HIDDEN    then file_info.attributes |= .HIDDEN;
        if attribute_data.dwFileAttributes & FILE_ATTRIBUTE_SYSTEM    then file_info.attributes |= .SYSTEM;
        if attribute_data.dwFileAttributes & FILE_ATTRIBUTE_ARCHIVE   then file_info.attributes |= .ARCHIVE;
        if attribute_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY then file_info.attributes |= .DIRECTORY;
        if attribute_data.dwFileAttributes & FILE_ATTRIBUTE_DEVICE    then file_info.attributes |= .DEVICE;
        if attribute_data.dwFileAttributes & FILE_ATTRIBUTE_TEMPORARY then file_info.attributes |= .TEMPORARY;

        if attribute_data.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT {
            file_info.attributes |= .SYMLINK;
        }
    }
}
