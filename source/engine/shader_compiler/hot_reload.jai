ShadersHotReload :: struct {
    thread : Thread(ShadersHotReload);

    #if OS == .WINDOWS {
        notification      : HANDLE;
        directory         : HANDLE;
        overlapped        : OVERLAPPED;
        stop_thread_event : HANDLE;
    }

    device         : *Device;
    shader_manager : *ShaderManager;
}

initShadersHotReload :: (hot_reload : *ShadersHotReload, device : *Device, shader_manager : *ShaderManager) {
    createThread(*hot_reload.thread, hotReloadProc, hot_reload, "Shaders Hot Reload", .SHADERS_HOT_RELOAD);

    #if OS == .WINDOWS {
        wide_source_shaders_folder : [ShaderCompiler.SOURCE_SHADERS_FOLDER.count + 1] WCHAR = ---;
        asciiToWide(*wide_source_shaders_folder, ShaderCompiler.SOURCE_SHADERS_FOLDER, true);

        hot_reload.notification = FindFirstChangeNotificationW(wide_source_shaders_folder.data, TRUE, FILE_NOTIFY_CHANGE_LAST_WRITE);
        assert(hot_reload.notification != INVALID_HANDLE_VALUE, print_sys_error = true);

        hot_reload.directory = CreateFileW(wide_source_shaders_folder.data,
                                           GENERIC_READ,
                                           FILE_SHARE_READ | FILE_SHARE_WRITE,
                                           null,
                                           OPEN_EXISTING,
                                           FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OVERLAPPED,
                                           null);
        assert(hot_reload.directory != INVALID_HANDLE_VALUE, print_sys_error = true);

        OVERLAPPED_IO_EVENT_NAME :: "Shaders Hot Reload Overlapped IO Event";
        wide_overlapped_io_event_name : [OVERLAPPED_IO_EVENT_NAME.count + 1] WCHAR = ---;
        asciiToWide(*wide_overlapped_io_event_name, OVERLAPPED_IO_EVENT_NAME, true);

        hot_reload.overlapped.hEvent = CreateEventExW(null, wide_overlapped_io_event_name.data, 0, EVENT_ALL_ACCESS);
        assert(hot_reload.overlapped.hEvent, print_sys_error = true);

        STOP_THREAD_EVENT_NAME :: "Shaders Hot Reload Stop Thread Event";
        wide_stop_thread_event_name : [STOP_THREAD_EVENT_NAME.count + 1] WCHAR = ---;
        asciiToWide(*wide_stop_thread_event_name, STOP_THREAD_EVENT_NAME, true);

        hot_reload.stop_thread_event = CreateEventExW(null, wide_stop_thread_event_name.data, CREATE_EVENT_MANUAL_RESET, EVENT_ALL_ACCESS);
        assert(hot_reload.stop_thread_event, print_sys_error = true);
    } else {
        notImplemented();
    }

    hot_reload.device         = device;
    hot_reload.shader_manager = shader_manager;

    recompileOutOfDateShaders(hot_reload);
    startThread(*hot_reload.thread);
}

destroyShadersHotReload :: (hot_reload : *ShadersHotReload) {
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
        notification_information_buffer : [4096] u8 #align 4;

        handles_to_wait := HANDLE.[
            hot_reload.notification,
            hot_reload.stop_thread_event
        ];

        while true {
            resetArena(*context.pet.per_frame_arena);
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
                        filename := wideToAscii(info.FileName.data,
                                                info.FileNameLength / size_of(WCHAR),
                                                pushToArena,
                                                *context.pet.per_frame_arena);

                        // Remove file extension
                        filename.count = String.find_index_from_right(filename, #char ".");

                        reloadShader(hot_reload.device, hot_reload.shader_manager, filename);

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

// @TODO: #ThreadPool
reloadShader :: inline (device : *Device, manager : *ShaderManager, name : string) {
    if compileShader(name) {
        shader := findShader(device, manager, name);
        if shader {
            reloadShader(device, manager, shader);
        }
    }
}

recompileOutOfDateShaders :: (hot_reload : *ShadersHotReload) {
    enumerateFiles(ShaderCompiler.SOURCE_SHADERS_FOLDER, (hot_reload : *ShadersHotReload, file_info : *FileInfo) -> EnumerateFilesCallbackResult {
        if String.path_extension(file_info.name) != "shader" {
            return .CONTINUE;
        }

        shader_name : string = ---;
        shader_name.data  = file_info.name.data  + (ShaderCompiler.SOURCE_SHADERS_FOLDER.count + 1);
        shader_name.count = file_info.name.count - (ShaderCompiler.SOURCE_SHADERS_FOLDER.count + 1) - ".shader".count;

        binary_filename := makeBinaryShaderFilename(shader_name);

        source_file_info, source_file_error := getFileInfo(file_info.name);
        assert(source_file_error == .NONE);

        binary_file_info, binary_file_error := getFileInfo(binary_filename);
        assert(binary_file_error == .NONE || binary_file_error == .FILE_NOT_FOUND || binary_file_error == .PATH_NOT_FOUND);

        if binary_file_error == .FILE_NOT_FOUND || binary_file_error == .PATH_NOT_FOUND {
            warningMessage("File % does not exist", binary_filename);
        }

        if Basic.compare_apollo_times(binary_file_info.last_write_time, source_file_info.last_write_time) > 0 {
            return .CONTINUE;
        }

        compileShader(shader_name);

        return .CONTINUE;
    }, hot_reload, recursively = true);
}
