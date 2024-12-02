#assert OS == .WINDOWS "This file should not be used anywhere except Windows builds";

openWindowsFile :: (filename : string, flags : File.Flags, $create_path_if_does_not_exist := false) -> (File #must, File.Error #must) {
    utf16_filename := UTF8ToUTF16(filename, pushToArena, *context.pet.arenas.per_frame);

    desired_access, shared_access, creation_disposition, flags_and_attributes := flagsToWin32Flags(flags);

    file : File;
    file.handle = CreateFileW(utf16_filename.data, desired_access, shared_access, null, creation_disposition, flags_and_attributes, null);
    if file.handle == INVALID_HANDLE_VALUE {
        if GetLastError() == {
            case ERROR_FILE_NOT_FOUND;
                assert(flags & .EXISTS);
                errorMessage("File \"%\" was tried to be opened with flag EXISTS but it does not exist", filename);
                return file, .FILE_NOT_FOUND;

            case ERROR_PATH_NOT_FOUND;
                #if create_path_if_does_not_exist {
                    warningMessage("Path to file \"%\" does not exist, so it will be created", filename);

                    createPathToFilename(*utf16_filename);

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
                errorMessage("File \"%\" cannot be opened", filename, print_sys_error = true);
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

enumerateWindowsFiles :: (
    $$directory       : string,
    callback          : (user_data : *$T, file_info : *File.Info) -> EnumerateFilesCallbackResult,
    user_data         : *T,
    $case_sensitive   : bool,
    $recursively      : bool,
    $skip_directories : bool,
    $skip_symlinks    : bool
) -> EnumerateFilesCallbackResult {
    utf16_wildcard : [File.MAX_FILENAME_LENGTH + 1] WCHAR = ---;
    UTF8ToUTF16(*utf16_wildcard, directory);

    #if is_constant(directory) {
        #if directory[directory.count - 1] == #char "/" {
            utf16_wildcard[directory.count + 0] = #char "*";
            utf16_wildcard[directory.count + 1] = 0;
        } else {
            utf16_wildcard[directory.count + 0] = #char "/";
            utf16_wildcard[directory.count + 1] = #char "*";
            utf16_wildcard[directory.count + 2] = 0;
        }
    } else {
        if directory[directory.count - 1] == #char "/" {
            utf16_wildcard[directory.count + 0] = #char "*";
            utf16_wildcard[directory.count + 1] = 0;
        } else {
            utf16_wildcard[directory.count + 0] = #char "/";
            utf16_wildcard[directory.count + 1] = #char "*";
            utf16_wildcard[directory.count + 2] = 0;
        }
    }

    additional_flags := FIND_FIRST_EX_LARGE_FETCH;
    #if case_sensitive additional_flags |= FIND_FIRST_EX_CASE_SENSITIVE;

    find_data : WIN32_FIND_DATAW;
    find_file := FindFirstFileExW(utf16_wildcard.data, .FindExInfoBasic, *find_data, .FindExSearchNameMatch, null, additional_flags);
    assert(find_file != INVALID_HANDLE_VALUE, print_sys_error = true);

    filename_buffer : [File.MAX_FILENAME_LENGTH + 1] u8 = ---;

    file_info : File.Info;
    file_info.name.data = filename_buffer.data;

    result : EnumerateFilesCallbackResult = .CONTINUE;
    while true {
        utf16_filename : [] WCHAR = .{ ntStringLength(find_data.cFileName), find_data.cFileName.data };
        file_info.name.count = UTF16ToUTF8(*filename_buffer, utf16_filename);

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
                    translateFileInfo(*file_info, find_data, true);

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
            translateFileInfo(*file_info, find_data, false);

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

getWindowsFileInfo :: (file_info : *File.Info) -> File.Error {
    utf16_filename := UTF8ToUTF16(file_info.name, pushToArena, *context.pet.arenas.per_frame);

    attribute_data : WIN32_FILE_ATTRIBUTE_DATA = ---;
    if !GetFileAttributesExW(utf16_filename.data, .GetFileExInfoStandard, *attribute_data) {
        if GetLastError() == {
            case ERROR_FILE_NOT_FOUND;    return .FILE_NOT_FOUND;
            case ERROR_PATH_NOT_FOUND;    return .PATH_NOT_FOUND;
            case ERROR_SHARING_VIOLATION; return .SHARED_ACCESS_VIOLATION;
            case;
                errorMessage("GetFileAttributesExW has failed for file \"%\"", file_info.name, print_sys_error = true);
                return .UNHANDLED;
        }
    }

    translateFileInfo(file_info, attribute_data);
    return .NONE;
}

getWindowsFileInfo :: (file : File, file_info : *File.Info) -> File.Error {
    name_info : FILE_NAME_INFO = ---;
    if !GetFileInformationByHandleEx(file.handle, .FileNameInfo, *name_info, size_of(FILE_NAME_INFO)) {
        if GetLastError() == ERROR_SHARING_VIOLATION {
            return .SHARED_ACCESS_VIOLATION;
        } else {
            errorMessage("GetFileInformationByHandleEx has failed", print_sys_error = true);
            return .UNHANDLED;
        }
    }

    file_info.name = UTF16ToUTF8(.{ name_info.FileName.FileNameLength, name_info.FileName.data },
                                 pushToArena,
                                 *context.pet.arenas.per_frame);

    by_handle_info : BY_HANDLE_FILE_INFORMATION = ---;
    if !GetFileInformationByHandle(file.handle, *by_handle_info) {
        if GetLastError() == ERROR_SHARING_VIOLATION {
            return .SHARED_ACCESS_VIOLATION;
        } else {
            errorMessage("GetFileInformationByHandle has failed for file \"%\"",
                         file_info.name,
                         print_sys_error = true);
            return .UNHANDLED;
        }
    }

    attribute_tag_info : FILE_ATTRIBUTE_TAG_INFO = ---;
    if !GetFileInformationByHandleEx(file.handle, .FileAttributeTagInfo, *attribute_tag_info, size_of(FILE_ATTRIBUTE_TAG_INFO)) {
        if GetLastError() == ERROR_SHARING_VIOLATION {
            return .SHARED_ACCESS_VIOLATION;
        } else {
            errorMessage("GetFileInformationByHandleEx has failed for file \"%\"",
                         file_info.name,
                         print_sys_error = true);
            return .UNHANDLED;
        }
    }

    translateFileInfo(file_info, by_handle_info, attribute_tag_info);
    return .NONE;
}

windowsFileExists :: (filename : string) -> bool {
    utf16_filename := UTF8ToUTF16(filename, pushToArena, *context.pet.arenas.per_frame);

    // PathFileExists just does "return GetFileAttributes(filename) != INVALID_FILE_ATTRIBUTES;",
    // so we won't use it as it requires one more library to link
    return GetFileAttributesW(utf16_filename.data) != INVALID_FILE_ATTRIBUTES;
}

getWindowsAbsolutePath :: (
    relative_path : string,
    allocate      : (user_data : *$T, bytes : s64, alignment : s64) -> *void,
    user_data     : *T
) -> string {
    utf16_relative_path := UTF8ToUTF16(relative_path, pushToArena, *context.pet.arenas.per_frame);

    utf16_absolute_path : [File.MAX_FILENAME_LENGTH + 1] WCHAR = ---;
    utf16_absolute_path_length := GetFullPathNameW(utf16_relative_path.data, utf16_absolute_path.count, utf16_absolute_path.data, null);
    assert(utf16_absolute_path_length, print_sys_error = true);

    return UTF16ToUTF8(.{ utf16_absolute_path_length, utf16_absolute_path.data }, allocate, user_data);
}

getWindowsAbsolutePath :: (absolute_path_buffer : *[$capacity] u8, relative_path : string) -> s64 {
    utf16_relative_path := UTF8ToUTF16(relative_path, pushToArena, *context.pet.arenas.per_frame);

    utf16_absolute_path : [File.MAX_FILENAME_LENGTH + 1] WCHAR = ---;
    utf16_absolute_path_length := GetFullPathNameW(utf16_relative_path.data, utf16_absolute_path.count, utf16_absolute_path.data, null);
    assert(utf16_absolute_path_length, print_sys_error = true);

    return UTF16ToUTF8(absolute_path_buffer, .{ utf16_absolute_path_length, utf16_absolute_path.data });
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

createPathToFilename :: (filename : *[] WCHAR) {
    directory_end := filename.data + filename.count - 1;
    while directory_end > filename.data {
        if directory_end.* == #char "/" || directory_end.* == #char "\\" {
            break;
        }
        directory_end -= 1;
    }
    assert(directory_end > filename.data, "There is no slash in the path");

    old_symbol := directory_end.*;
    old_length := filename.count;

    directory_end.* = 0;
    filename.count  = directory_end - filename.data;

    if CreateDirectoryW(filename.data, null) {
        directory_end.* = old_symbol;
        filename.count  = old_length;
    } else if GetLastError() == ERROR_PATH_NOT_FOUND {
        createPathToFilename(filename);

        directory_end.* = old_symbol;
        filename.count  = old_length;

        debugCheck(CreateDirectoryW(filename.data, null), print_sys_error = true);
    } else {
        // We do not handle ERROR_ALREADY_EXISTS because this function is called only when CreateFileW returns ERROR_PATH_NOT_FOUND
        assertMessage("CreateDirectoryW has failed", print_sys_error = true);
    }
}

translateFileInfo :: (file_info : *File.Info, find_data : WIN32_FIND_DATAW, $is_directory : bool) {
    file_info.creation_time    = Basic.filetime_to_apollo(xx,force find_data.ftCreationTime);
    file_info.last_access_time = Basic.filetime_to_apollo(xx,force find_data.ftLastAccessTime);
    file_info.last_write_time  = Basic.filetime_to_apollo(xx,force find_data.ftLastWriteTime);

    file_info.size = (cast(u64) find_data.nFileSizeHigh << 32) | find_data.nFileSizeLow;

    file_info.attributes = 0;
    if find_data.dwFileAttributes & FILE_ATTRIBUTE_READONLY then file_info.attributes |= .READ_ONLY;
    if find_data.dwFileAttributes & FILE_ATTRIBUTE_HIDDEN   then file_info.attributes |= .HIDDEN;
    if find_data.dwFileAttributes & FILE_ATTRIBUTE_SYSTEM   then file_info.attributes |= .SYSTEM;
    if find_data.dwFileAttributes & FILE_ATTRIBUTE_ARCHIVE  then file_info.attributes |= .ARCHIVE;

    #if is_directory {
        assert(find_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY);
        file_info.attributes |= .DIRECTORY;
    }

    if find_data.dwFileAttributes & FILE_ATTRIBUTE_DEVICE    then file_info.attributes |= .DEVICE;
    if find_data.dwFileAttributes & FILE_ATTRIBUTE_TEMPORARY then file_info.attributes |= .TEMPORARY;

    if (find_data.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) && find_data.dwReserved0 == IO_REPARSE_TAG_SYMLINK {
        file_info.attributes |= .SYMLINK;
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
