ShadersHotReload :: struct {
    thread : Thread(ShadersHotReload);

    #if OS == .WINDOWS {
        notification      : HANDLE;
        directory         : HANDLE;
        overlapped        : OVERLAPPED;
        stop_thread_event : HANDLE;
    }
}

createShadersHotReload :: (hot_reload : *ShadersHotReload) {
    if !fileExists(ShaderCompiler.SOURCE_SHADERS_FOLDER) {
        #if DEBUG_BUILD warningMessage("Source shaders folder is not found: %", ShaderCompiler.SOURCE_SHADERS_FOLDER);
        return;
    }

    createThread(*hot_reload.thread, hotReloadProc, hot_reload, "Shaders Hot Reload", .SHADERS_HOT_RELOAD);

    #if OS == .WINDOWS {
        utf16_source_shaders_folder : [ShaderCompiler.SOURCE_SHADERS_FOLDER.count + 1] WCHAR = ---;
        ASCIIToUTF16(*utf16_source_shaders_folder, ShaderCompiler.SOURCE_SHADERS_FOLDER);

        hot_reload.notification = FindFirstChangeNotificationW(utf16_source_shaders_folder.data, TRUE, FILE_NOTIFY_CHANGE_LAST_WRITE);
        assert(hot_reload.notification != INVALID_HANDLE_VALUE, print_sys_error = true);

        hot_reload.directory = CreateFileW(utf16_source_shaders_folder.data,
                                           GENERIC_READ,
                                           FILE_SHARE_READ | FILE_SHARE_WRITE,
                                           null,
                                           OPEN_EXISTING,
                                           FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OVERLAPPED,
                                           null);
        assert(hot_reload.directory != INVALID_HANDLE_VALUE, print_sys_error = true);

        OVERLAPPED_IO_EVENT_NAME :: "Shaders Hot Reload Overlapped IO Event";
        utf16_overlapped_io_event_name : [OVERLAPPED_IO_EVENT_NAME.count + 1] WCHAR = ---;
        ASCIIToUTF16(*utf16_overlapped_io_event_name, OVERLAPPED_IO_EVENT_NAME);

        hot_reload.overlapped.hEvent = CreateEventExW(null, utf16_overlapped_io_event_name.data, 0, EVENT_ALL_ACCESS);
        assert(hot_reload.overlapped.hEvent, print_sys_error = true);

        STOP_THREAD_EVENT_NAME :: "Shaders Hot Reload Stop Thread Event";
        utf16_stop_thread_event_name : [STOP_THREAD_EVENT_NAME.count + 1] WCHAR = ---;
        ASCIIToUTF16(*utf16_stop_thread_event_name, STOP_THREAD_EVENT_NAME);

        hot_reload.stop_thread_event = CreateEventExW(null, utf16_stop_thread_event_name.data, CREATE_EVENT_MANUAL_RESET, EVENT_ALL_ACCESS);
        assert(hot_reload.stop_thread_event, print_sys_error = true);
    } else {
        notImplemented();
    }

    recompileOutOfDateShaders(hot_reload);
    startThread(*hot_reload.thread);
}

destroyShadersHotReload :: (hot_reload : *ShadersHotReload) {
    if !fileExists(ShaderCompiler.SOURCE_SHADERS_FOLDER) {
        return;
    }

    #if OS == .WINDOWS {
        debugCheck(SetEvent(hot_reload.stop_thread_event), print_sys_error = true);

        result := CancelIoEx(hot_reload.directory, *hot_reload.overlapped);
        assert(result || GetLastError() == ERROR_NOT_FOUND, print_sys_error = true);
    } else {
        notImplemented();
    }

    waitThread(*hot_reload.thread);

    #if OS == .WINDOWS {
        debugCheck(CloseHandle(hot_reload.stop_thread_event), print_sys_error = true);
        debugCheck(CloseHandle(hot_reload.overlapped.hEvent), print_sys_error = true);
        debugCheck(CloseHandle(hot_reload.directory), print_sys_error = true);
        debugCheck(FindCloseChangeNotification(hot_reload.notification), print_sys_error = true);
    } else {
        notImplemented();
    }

    closeThreadHandle(*hot_reload.thread);
}

#scope_file

#if OS == .WINDOWS {
    hotReloadProc :: (hot_reload : *ShadersHotReload) {
        notification_information_buffer : [DEFAULT_PAGE_SIZE] u8 #align 4;

        handles_to_wait := HANDLE.[
            hot_reload.notification,
            hot_reload.stop_thread_event
        ];

        while true {
            resetArena(*context.pet.arenas.per_frame);
            Basic.reset_temporary_storage();

            wait_result := WaitForMultipleObjectsEx(handles_to_wait.count, handles_to_wait.data, FALSE, INFINITE, FALSE);
            if wait_result == WAIT_OBJECT_0 {
                info := cast(*FILE_NOTIFY_INFORMATION) notification_information_buffer.data;
                debugCheck(ReadDirectoryChangesW(hot_reload.directory,
                                                 info,
                                                 notification_information_buffer.count,
                                                 TRUE,
                                                 FILE_NOTIFY_CHANGE_LAST_WRITE,
                                                 null,
                                                 *hot_reload.overlapped,
                                                 null),
                           print_sys_error = true);

                bytes_transferred : u32;
                if GetOverlappedResult(hot_reload.directory, *hot_reload.overlapped, *bytes_transferred, TRUE) {
                    assert(bytes_transferred, print_sys_error = true);

                    while info {
                        filename := UTF16ToUTF8(.{ info.FileNameLength / size_of(WCHAR), info.FileName.data },
                                                pushToArena,
                                                *context.pet.arenas.per_frame);

                        reloadShader(filename);

                        info = ifx  info.NextEntryOffset
                               then cast(*void) info + info.NextEntryOffset
                               else null;
                    }
                } else {
                    assert(GetLastError() == ERROR_OPERATION_ABORTED, print_sys_error = true);
                }

                debugCheck(FindNextChangeNotification(hot_reload.notification), print_sys_error = true);
            } else {
                assert(wait_result == WAIT_OBJECT_0 + 1, print_sys_error = true);
                break;
            }
        }
    }
} else {
    notImplemented();
}

reloadShader :: (filename : string) {
    if String.path_extension(filename) != "shader" {
        return;
    }

    // Remove file extension
    name := string.{
        count = String.find_index_from_right(filename, #char "."),
        data  = filename.data
    };

    if compileShader(name) {
        shader := findShader(name);
        if shader {
            reloadShader(shader);
        }
    }
}

recompileOutOfDateShaders :: inline (hot_reload : *ShadersHotReload) {
    enumerateFiles(ShaderCompiler.SOURCE_SHADERS_FOLDER, (hot_reload : *ShadersHotReload, source_file_info : *File.Info) -> EnumerateFilesCallbackResult {
        if String.path_extension(source_file_info.name) != "shader" {
            return .CONTINUE;
        }

        shader_name := string.{
            source_file_info.name.count - (ShaderCompiler.SOURCE_SHADERS_FOLDER.count + "/".count) - ".shader".count,
            source_file_info.name.data  + (ShaderCompiler.SOURCE_SHADERS_FOLDER.count + "/".count)
        };

        binary_filename := makeBinaryShaderFilename(shader_name);

        binary_file_info, error := getFileInfo(binary_filename);
        assert(error == .NONE || error == .FILE_NOT_FOUND || error == .PATH_NOT_FOUND);

        if binary_file_info.last_write_time >= source_file_info.last_write_time {
            binary_file:, error = openFile(binary_filename, .READ | .SHARED_READ | .EXISTS);
            assert(error == .NONE);
            defer closeFile(*binary_file);

            header : ShaderCompiler.Header = ---;
            readFile(binary_file, *header);
            if header.version == ShaderCompiler.VERSION {
                return .CONTINUE;
            }
        }

        compileShader(shader_name);

        return .CONTINUE;
    }, hot_reload, recursively = true);
}
