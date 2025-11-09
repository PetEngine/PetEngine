#assert OS == .WINDOWS "This file should not be used anywhere except Windows builds";

openWindowsFile :: (filename : string, flags : File.Flags, $create_path_if_does_not_exist := false) -> (File, File.Error) {
    utf16_filename := makeUTF16Path(filename);

    desired_access, shared_access, creation_disposition, flags_and_attributes := flagsToWin32Flags(flags);

    file : File;
    file.handle = CreateFileW(utf16_filename.data, desired_access, shared_access, null, creation_disposition, flags_and_attributes, null);
    if file.handle == INVALID_HANDLE_VALUE {
        error := GetLastError();
        if error == {
            case ERROR_FILE_NOT_FOUND;
                assert(flags & .EXISTS);
                errorMessage("File \"%\" was tried to be opened with flag EXISTS but it does not exist", filename);
                return file, .FILE_NOT_FOUND;

            case ERROR_PATH_NOT_FOUND;
                #if create_path_if_does_not_exist {
                    warningMessage("Path to file \"%\" does not exist, so it will be created", filename);

                    createPathToFilename(*utf16_filename, false);

                    file.handle = CreateFileW(utf16_filename.data, desired_access, shared_access, null, creation_disposition, flags_and_attributes, null);
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
                errorMessage("File \"%\" cannot be opened", filename, print_sys_error = true, error);
                return file, .UNHANDLED;
        }
    }

    return file, .NONE;
}

closeWindowsFile :: (file : *File) {
    debugCheck(CloseHandle(file.handle), print_sys_error = true);
    file.handle = INVALID_HANDLE_VALUE;
}

readWindowsFile :: (file : File, buffer : *void, bytes : s64) {
    buffer_it       := buffer;
    remaining_bytes := bytes;

    while remaining_bytes > 0 {
        bytes_to_read := cast(u32) min(remaining_bytes, 0xFFFF_FFFF);

        bytes_read : u32;
        debugCheck(ReadFile(file.handle, buffer_it, bytes_to_read, *bytes_read, null), print_sys_error = true);

        buffer_it       += bytes_read;
        remaining_bytes -= bytes_read;
    }
}

writeWindowsFile :: (file : File, data : *void, bytes : s64) {
    data_it         := data;
    remaining_bytes := bytes;

    while remaining_bytes > 0 {
        bytes_to_write := cast(u32) min(remaining_bytes, 0xFFFF_FFFF);

        bytes_written : u32;
        debugCheck(WriteFile(file.handle, data_it, bytes_to_write, *bytes_written, null), print_sys_error = true);

        data_it         += bytes_written;
        remaining_bytes -= bytes_written;
    }
}

getWindowsFileSize :: (file : File) -> s64 {
    file_size : LARGE_INTEGER = ---;
    debugCheck(GetFileSizeEx(file.handle, *file_size), print_sys_error = true);
    return file_size.QuadPart;
}

getWindowsFileCursorPosition :: (file : File) -> s64 {
    cursor_position : LARGE_INTEGER = ---;
    debugCheck(SetFilePointerEx(file.handle, .{}, *cursor_position, FILE_CURRENT), print_sys_error = true);
    return cursor_position.QuadPart;
}

setWindowsFileCursorPosition :: (file : File, move_method : u32, position : s64) -> s64 {
    distance_to_move    := LARGE_INTEGER.{ QuadPart = position };
    new_cursor_position : LARGE_INTEGER = ---;
    debugCheck(SetFilePointerEx(file.handle, distance_to_move, *new_cursor_position, move_method), print_sys_error = true);
    return new_cursor_position.QuadPart;
}

enumerateWindowsFiles :: (
    directory         : string,
    callback          : (user_data : *$T, file_info : File.Info(.RELATIVE)) -> EnumerateFilesCallbackResult,
    user_data         : *T,
    $recursively      : bool,
    $skip_directories : bool,
    $skip_symlinks    : bool
) -> File.Error, EnumerateFilesCallbackResult {
    utf16_directory := makeUTF16Path(directory);

    root_directory_length := utf16_directory.count + "/".count;

    UTF16_LONG_PATH_PREFIX       :: WCHAR.[ #char "\\", #char "\\", #char "?", #char "\\" ];
    UTF16_LONG_PATH_PREFIX_BYTES :: UTF16_LONG_PATH_PREFIX.count * size_of(WCHAR);

    if utf16_directory.count >= UTF16_LONG_PATH_PREFIX.count
    && !memcmp(utf16_directory.data, UTF16_LONG_PATH_PREFIX.data, UTF16_LONG_PATH_PREFIX_BYTES) {
        root_directory_length -= UTF16_LONG_PATH_PREFIX.count;
    }

    error, result := enumerateWindowsFilesUTF16(utf16_directory,
                                                callback,
                                                user_data,
                                                root_directory_length,
                                                recursively,
                                                skip_directories,
                                                skip_symlinks);
    return error, result;
}

getWindowsFileInfo :: (file_info : *File.Info) -> File.Error {
    utf16_filename := makeUTF16Path(file_info.path);

    attribute_data : WIN32_FILE_ATTRIBUTE_DATA = ---;
    if !GetFileAttributesExW(utf16_filename.data, .GetFileExInfoStandard, *attribute_data) {
        if GetLastError() == {
            case ERROR_FILE_NOT_FOUND;    return .FILE_NOT_FOUND;
            case ERROR_PATH_NOT_FOUND;    return .PATH_NOT_FOUND;
            case ERROR_SHARING_VIOLATION; return .SHARED_ACCESS_VIOLATION;
            case;
                errorMessage("GetFileAttributesExW(\"%\") has failed", file_info.path, print_sys_error = true);
                return .UNHANDLED;
        }
    }

    translateFileInfo(file_info, attribute_data);
    return .NONE;
}

getWindowsFileInfo :: (file : File, file_info : *File.Info) -> File.Error {
    NAME_INFO_CAPACITY :: #run kiloBytes(32); // Max NTFS path length

    name_info : *FILE_NAME_INFO = pushToArena(*context.pet.arenas.per_frame, NAME_INFO_CAPACITY);
    if !GetFileInformationByHandleEx(file.handle, .FileNameInfo, name_info, NAME_INFO_CAPACITY) {
        error := GetLastError();
        if error == ERROR_SHARING_VIOLATION {
            return .SHARED_ACCESS_VIOLATION;
        } else {
            errorMessage("GetFileInformationByHandleEx(.FileNameInfo) has failed", print_sys_error = true, error);
            return .UNHANDLED;
        }
    }

    file_info.path = makeUTF8Path(.{ name_info.FileNameLength, name_info.FileName.data });

    by_handle_info : BY_HANDLE_FILE_INFORMATION = ---;
    if !GetFileInformationByHandle(file.handle, *by_handle_info) {
        error := GetLastError();
        if error == ERROR_SHARING_VIOLATION {
            return .SHARED_ACCESS_VIOLATION;
        } else {
            errorMessage("GetFileInformationByHandle(\"%\") has failed", file_info.path, print_sys_error = true, error);
            return .UNHANDLED;
        }
    }

    attribute_tag_info : FILE_ATTRIBUTE_TAG_INFO = ---;
    if !GetFileInformationByHandleEx(file.handle, .FileAttributeTagInfo, *attribute_tag_info, size_of(FILE_ATTRIBUTE_TAG_INFO)) {
        error := GetLastError();
        if error == ERROR_SHARING_VIOLATION {
            return .SHARED_ACCESS_VIOLATION;
        } else {
            errorMessage("GetFileInformationByHandleEx(\"%\", .FileAttributeTagInfo) has failed",
                         file_info.path,
                         print_sys_error = true,
                         error);
            return .UNHANDLED;
        }
    }

    translateFileInfo(file_info, by_handle_info, attribute_tag_info);
    return .NONE;
}

windowsFileExists :: (filename : string) -> bool {
    utf16_filename := makeUTF16Path(filename);

    // PathFileExists just does "return GetFileAttributes(filename) != INVALID_FILE_ATTRIBUTES;",
    // so we won't use it as it requires one more library to link
    return GetFileAttributesW(utf16_filename.data) != INVALID_FILE_ATTRIBUTES;
}

getWindowsAbsolutePath :: (relative_path : string) -> string {
    // We do not need to call `makeUTF16Path` because we know that `relative_path` is not absolute (is validated by the caller),
    // so we do not need all the functionality `makeUTF16Path` provides.
    utf16_relative_path := UTF8ToUTF16(relative_path);

    for * utf16_relative_path {
        if it.* == #char "/" {
            it.* = #char "\\";
        }
    }

    utf16_absolute_path : [] WCHAR = .{ count = GetFullPathNameW(utf16_relative_path.data, 0, null, null) };
    assert(utf16_absolute_path.count > 0, print_sys_error = true);

    utf16_absolute_path_capacity := cast(u32) utf16_absolute_path.count;

    utf16_absolute_path.data = pushToArena(*context.pet.arenas.per_frame, WCHAR, utf16_absolute_path_capacity);

    utf16_absolute_path.count = GetFullPathNameW(utf16_relative_path.data, utf16_absolute_path_capacity, utf16_absolute_path.data, null);
    assert(utf16_absolute_path.count > 0, print_sys_error = true);

    // We do not need to call `makeUTF8Path` since we know it will not be prefixed with "\\?\"
    utf8_absolute_path := UTF16ToUTF8(utf16_absolute_path);

    for * utf8_absolute_path {
        if it.* == #char "\\" {
            it.* = #char "/";
        }
    }

    return utf8_absolute_path;
}

createWindowsDirectory :: (filename : string) {
    utf16_filename := UTF8ToUTF16(filename);
    createPathToFilename(*utf16_filename, true);
}

#scope_file

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

createPathToFilename :: (filename : *[] WCHAR, $may_exist : bool) {
    directory_end := filename.data + filename.count - 1;
    while directory_end > filename.data {
        if directory_end.* == #char "\\" {
            break;
        }
        directory_end -= 1;
    }
    assert(directory_end > filename.data, "There is no slash in the path");

    old_symbol := directory_end.*;
    old_length := filename.count;

    directory_end.* = #char "\0";
    filename.count  = directory_end - filename.data;

    defer {
        directory_end.* = old_symbol;
        filename.count  = old_length;
    }

    if CreateDirectoryW(filename.data, null) {
        return;
    }

    error := GetLastError();
    if error == {
        case ERROR_PATH_NOT_FOUND;
            createPathToFilename(filename, may_exist);
            debugCheck(CreateDirectoryW(filename.data, null), print_sys_error = true);

        case ERROR_ALREADY_EXISTS;
            #if !may_exist {
                assertMessage("Directory \"%\" already exists (may_exist == false)", filename);
            }

        case;
            assertMessage("CreateDirectoryW(\"%\") has failed", filename, print_sys_error = true, error);
    }
}

translateFileInfo :: (file_info : *File.Info, attribute_data : WIN32_FILE_ATTRIBUTE_DATA) {
    file_info.creation_time    = Basic.filetime_to_apollo(xx,force attribute_data.ftCreationTime);
    file_info.last_access_time = Basic.filetime_to_apollo(xx,force attribute_data.ftLastAccessTime);
    file_info.last_write_time  = Basic.filetime_to_apollo(xx,force attribute_data.ftLastWriteTime);

    file_info.size = (cast(u64) attribute_data.nFileSizeHigh << 32) | attribute_data.nFileSizeLow;

    file_info.attributes = 0;
    if attribute_data.dwFileAttributes & FILE_ATTRIBUTE_READONLY      then file_info.attributes |= .READ_ONLY;
    if attribute_data.dwFileAttributes & FILE_ATTRIBUTE_HIDDEN        then file_info.attributes |= .HIDDEN;
    if attribute_data.dwFileAttributes & FILE_ATTRIBUTE_SYSTEM        then file_info.attributes |= .SYSTEM;
    if attribute_data.dwFileAttributes & FILE_ATTRIBUTE_ARCHIVE       then file_info.attributes |= .ARCHIVE;
    if attribute_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY     then file_info.attributes |= .DIRECTORY;
    if attribute_data.dwFileAttributes & FILE_ATTRIBUTE_DEVICE        then file_info.attributes |= .DEVICE;
    if attribute_data.dwFileAttributes & FILE_ATTRIBUTE_TEMPORARY     then file_info.attributes |= .TEMPORARY;
    if attribute_data.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT then file_info.attributes |= .SYMLINK;
}

translateFileInfo :: (file_info : *File.Info, by_handle_info : BY_HANDLE_FILE_INFORMATION, attribute_tag_info : FILE_ATTRIBUTE_TAG_INFO) {
    file_info.creation_time    = Basic.filetime_to_apollo(xx,force by_handle_info.ftCreationTime);
    file_info.last_access_time = Basic.filetime_to_apollo(xx,force by_handle_info.ftLastAccessTime);
    file_info.last_write_time  = Basic.filetime_to_apollo(xx,force by_handle_info.ftLastWriteTime);

    file_info.size = (cast(u64) by_handle_info.nFileSizeHigh << 32) | by_handle_info.nFileSizeLow;

    file_info.attributes = 0;
    if by_handle_info.dwFileAttributes & FILE_ATTRIBUTE_READONLY  then file_info.attributes |= .READ_ONLY;
    if by_handle_info.dwFileAttributes & FILE_ATTRIBUTE_HIDDEN    then file_info.attributes |= .HIDDEN;
    if by_handle_info.dwFileAttributes & FILE_ATTRIBUTE_SYSTEM    then file_info.attributes |= .SYSTEM;
    if by_handle_info.dwFileAttributes & FILE_ATTRIBUTE_ARCHIVE   then file_info.attributes |= .ARCHIVE;
    if by_handle_info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY then file_info.attributes |= .DIRECTORY;
    if by_handle_info.dwFileAttributes & FILE_ATTRIBUTE_DEVICE    then file_info.attributes |= .DEVICE;
    if by_handle_info.dwFileAttributes & FILE_ATTRIBUTE_TEMPORARY then file_info.attributes |= .TEMPORARY;

    if (by_handle_info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) && (attribute_tag_info.ReparseTag == IO_REPARSE_TAG_SYMLINK) {
        file_info.attributes |= .SYMLINK;
    }
}

translateFileInfo :: (file_info : *File.Info(.RELATIVE), info : *FILE_ID_EXTD_DIR_INFO) {
    file_info.creation_time    = Basic.filetime_to_apollo(xx,force info.CreationTime);
    file_info.last_access_time = Basic.filetime_to_apollo(xx,force info.LastAccessTime);
    file_info.last_write_time  = Basic.filetime_to_apollo(xx,force info.LastWriteTime);

    file_info.size = cast,no_check(u64) info.EndOfFile.QuadPart;

    file_info.attributes = 0;
    if info.FileAttributes & FILE_ATTRIBUTE_READONLY  then file_info.attributes |= .READ_ONLY;
    if info.FileAttributes & FILE_ATTRIBUTE_HIDDEN    then file_info.attributes |= .HIDDEN;
    if info.FileAttributes & FILE_ATTRIBUTE_SYSTEM    then file_info.attributes |= .SYSTEM;
    if info.FileAttributes & FILE_ATTRIBUTE_ARCHIVE   then file_info.attributes |= .ARCHIVE;
    if info.FileAttributes & FILE_ATTRIBUTE_DIRECTORY then file_info.attributes |= .DIRECTORY;
    if info.FileAttributes & FILE_ATTRIBUTE_DEVICE    then file_info.attributes |= .DEVICE;
    if info.FileAttributes & FILE_ATTRIBUTE_TEMPORARY then file_info.attributes |= .TEMPORARY;

    if (info.FileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) && (info.ReparsePointTag == IO_REPARSE_TAG_SYMLINK) {
        file_info.attributes |= .SYMLINK;
    }
}

makeUTF16Path :: (utf8_path : string) -> [] WCHAR {
    utf16_path : [] WCHAR = ---;

    UTF16_LONG_PATH_PREFIX       :: WCHAR.[ #char "\\", #char "\\", #char "?", #char "\\" ];
    UTF16_LONG_PATH_PREFIX_BYTES :: UTF16_LONG_PATH_PREFIX.count * size_of(WCHAR);

    if !utf8_path {
        utf16_path = .[ 0 ];
    } else if utf8_path.count < MAX_PATH {
        utf16_path = UTF8ToUTF16(utf8_path);

        for * utf16_path {
            if it.* == #char "/" {
                it.* = #char "\\";
            }
        }
    } else if isAbsolutePath(utf8_path) {
        utf16_path_bytes : u32;
        debugCheckNT(RtlUTF8ToUnicodeN(null, 0, *utf16_path_bytes, utf8_path.data, cast(u32) utf8_path.count));

        utf16_path_length := UTF16_LONG_PATH_PREFIX.count + utf16_path_bytes / size_of(WCHAR);

        utf16_path.data = pushToArena(*context.pet.arenas.per_frame, WCHAR, utf16_path_length + "\0".count);
        debugCheckNT(RtlUTF8ToUnicodeN(utf16_path.data + UTF16_LONG_PATH_PREFIX.count,
                                       utf16_path_bytes,
                                       *utf16_path_bytes,
                                       utf8_path.data,
                                       cast(u32) utf8_path.count));

        utf16_path.count = UTF16_LONG_PATH_PREFIX.count + utf16_path_bytes / size_of(WCHAR);
        assert(utf16_path.count == utf16_path_length);

        memcpy(utf16_path.data, UTF16_LONG_PATH_PREFIX.data, UTF16_LONG_PATH_PREFIX_BYTES);

        for * utf16_path {
            if it.* == #char "/" {
                it.* = #char "\\";
            }
        }
    } else {
        // WinAPI does not support namespaced relative paths, so we get the absolute path first and only then prefix it with
        // `UTF16_LONG_PATH_PREFIX`.
        //     https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation?tabs=registry#:~:text=Because%20you%20cannot%20use%20the%20%22%5C%5C%3F%5C%22%20prefix%20with%20a%20relative%20path%2C%20relative%20paths%20are%20always%20limited%20to%20a%20total%20of%20MAX_PATH%20characters.

        utf16_relative_path := UTF8ToUTF16(utf8_path);

        for * utf16_relative_path {
            if it.* == #char "/" {
                it.* = #char "\\";
            }
        }

        utf16_path_with_null_length := GetFullPathNameW(utf16_relative_path.data, 0, null, null);
        assert(utf16_path_with_null_length > 0, print_sys_error = true);

        utf16_path_capacity := cast(u32) (UTF16_LONG_PATH_PREFIX.count + utf16_path_with_null_length);

        utf16_path.data = pushToArena(*context.pet.arenas.per_frame, WCHAR, utf16_path_capacity);
        memcpy(utf16_path.data, UTF16_LONG_PATH_PREFIX.data, UTF16_LONG_PATH_PREFIX_BYTES);

        utf16_path.count = GetFullPathNameW(utf16_relative_path.data,
                                            utf16_path_capacity - UTF16_LONG_PATH_PREFIX.count,
                                            utf16_path.data     + UTF16_LONG_PATH_PREFIX.count,
                                            null);
        assert(utf16_path.count > 0, print_sys_error = true);

        utf16_path.count += UTF16_LONG_PATH_PREFIX.count;
    }

    return utf16_path;
}

makeUTF8Path :: (utf16_path_ : [] WCHAR) -> string {
    utf16_path := utf16_path_;

    UTF16_LONG_PATH_PREFIX       :: WCHAR.[ #char "\\", #char "\\", #char "?", #char "\\" ];
    UTF16_LONG_PATH_PREFIX_BYTES :: UTF16_LONG_PATH_PREFIX.count * size_of(WCHAR);

    if utf16_path.count >= UTF16_LONG_PATH_PREFIX.count
    && !memcmp(utf16_path.data, UTF16_LONG_PATH_PREFIX.data, UTF16_LONG_PATH_PREFIX_BYTES) {
        utf16_path.count -= UTF16_LONG_PATH_PREFIX.count;
        utf16_path.data  += UTF16_LONG_PATH_PREFIX.count;
    }

    utf8_path := UTF16ToUTF8(utf16_path);

    for * utf8_path {
        if it.* == #char "\\" {
            it.* = #char "/";
        }
    }

    return utf8_path;
}

enumerateWindowsFilesUTF16 :: (
    utf16_directory       : [] WCHAR,
    callback              : (user_data : *$T, file_info : File.Info(.RELATIVE)) -> EnumerateFilesCallbackResult,
    user_data             : *T,
    root_directory_length : s64,
    $recursively          : bool,
    $skip_directories     : bool,
    $skip_symlinks        : bool
) -> File.Error, EnumerateFilesCallbackResult {
    handle := CreateFileW(utf16_directory.data, GENERIC_READ, FILE_SHARE_READ, null, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_SEQUENTIAL_SCAN, null);
    if handle == INVALID_HANDLE_VALUE {
        error := GetLastError();
        if error == {
            case ERROR_FILE_NOT_FOUND;    return .FILE_NOT_FOUND,          .CONTINUE;
            case ERROR_PATH_NOT_FOUND;    return .PATH_NOT_FOUND,          .CONTINUE;
            case ERROR_SHARING_VIOLATION; return .SHARED_ACCESS_VIOLATION, .CONTINUE;
            case;                         return .UNHANDLED,               .CONTINUE;
        }
    }
    defer debugCheck(CloseHandle(handle), print_sys_error = true);

    autoResetPerFrameArenas();

    INFOS_BUFFER_CAPACITY :: #run kiloBytes(64);
    infos_buffer := pushToArena(*context.pet.arenas.per_frame, INFOS_BUFFER_CAPACITY);

    makeFullPathUTF16 :: (utf16_directory : [] WCHAR, utf16_filename : [] WCHAR) -> [] WCHAR {
        slash_required := utf16_directory[utf16_directory.count - 1] != #char "\\";

        utf16_full_filename : [] WCHAR = ---;
        utf16_full_filename.count = utf16_directory.count + cast(s64) slash_required + utf16_filename.count;
        utf16_full_filename.data  = pushToArena(*context.pet.arenas.per_frame, WCHAR, utf16_full_filename.count);
        memcpy(utf16_full_filename.data, utf16_directory.data, utf16_directory.count * size_of(WCHAR));
        if slash_required then utf16_full_filename[utf16_directory.count] = #char "\\";
        memcpy(utf16_full_filename.data + utf16_directory.count + cast(s64) slash_required,
               utf16_filename.data,
               utf16_filename.count * size_of(WCHAR));

        return utf16_full_filename;
    }

    while outer_loop := true {
        if !GetFileInformationByHandleEx(handle, .FileIdExtdDirectoryInfo, infos_buffer, INFOS_BUFFER_CAPACITY) {
            error := GetLastError();
            if error == ERROR_NO_MORE_FILES break;
            assertMessage("GetFileInformationByHandleEx(\"%\", .FileIdExtdDirectoryInfo) has failed",
                          utf16_directory,
                          print_sys_error = true,
                          error);
        }

        infos_it := cast(*FILE_ID_EXTD_DIR_INFO) infos_buffer;
        while true {
            defer {
                if !infos_it.NextEntryOffset break;
                infos_it = (cast(*void) infos_it) + infos_it.NextEntryOffset;
            }

            if infos_it.FileAttributes & FILE_ATTRIBUTE_DIRECTORY {
                utf16_filename : [] WCHAR = .{ infos_it.FileNameLength / size_of(WCHAR), infos_it.FileName.data };

                if (utf16_filename.count == 1 && utf16_filename[0] == #char ".")
                || (utf16_filename.count == 2 && utf16_filename[0] == #char "." && utf16_filename[1] == #char ".") {
                    continue;
                }

                #if recursively {
                    utf16_full_filename := makeFullPathUTF16(utf16_directory, utf16_filename);
                }

                #if skip_directories {
                    // skip
                } else #if skip_symlinks {
                    if !(infos_it.FileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) || (infos_it.ReparsePointTag != IO_REPARSE_TAG_SYMLINK) {
                        #if !recursively {
                            utf16_full_filename := makeFullPathUTF16(utf16_directory, utf16_filename);
                        }

                        file_info : File.Info(.RELATIVE) = ---;
                        file_info.path = makeUTF8Path(utf16_full_filename);
                        advance(*file_info.path, root_directory_length);
                        translateFileInfo(*file_info, infos_it);

                        result := callback(user_data, file_info);
                        if result == .BREAK return .NONE, .BREAK;
                    }
                } else {
                    #if !recursively {
                        utf16_full_filename := makeFullPathUTF16(utf16_directory, utf16_filename);
                    }

                    file_info : File.Info(.RELATIVE) = ---;
                    file_info.path = makeUTF8Path(utf16_full_filename);
                    advance(*file_info.path, root_directory_length);
                    translateFileInfo(*file_info, infos_it);

                    result := callback(user_data, file_info);
                    if result == .BREAK return .NONE, .BREAK;
                }

                #if recursively {
                    _, result := enumerateWindowsFilesUTF16(utf16_full_filename,
                                                            callback,
                                                            user_data,
                                                            root_directory_length,
                                                            recursively,
                                                            skip_symlinks,
                                                            skip_directories);
                    if result == .BREAK return .NONE, .BREAK;
                }
            } else {
                #if skip_symlinks {
                    if (infos_it.FileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) && (infos_it.ReparsePointTag == IO_REPARSE_TAG_SYMLINK) {
                        continue;
                    }
                }

                utf16_filename      : [] WCHAR = .{ infos_it.FileNameLength / size_of(WCHAR), infos_it.FileName.data };
                utf16_full_filename := makeFullPathUTF16(utf16_directory, utf16_filename);

                file_info : File.Info(.RELATIVE) = ---;
                file_info.path = makeUTF8Path(utf16_full_filename);
                advance(*file_info.path, root_directory_length);
                translateFileInfo(*file_info, infos_it);

                result := callback(user_data, file_info);
                if result == .BREAK return .NONE, .BREAK;
            }
        }
    }

    return .NONE, .CONTINUE;
}
