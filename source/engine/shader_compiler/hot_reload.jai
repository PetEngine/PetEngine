ShadersHotReload :: struct {
    thread : Thread(ShadersHotReload);

    #if OS == .WINDOWS {
        directory  : HANDLE = INVALID_HANDLE_VALUE;
        overlapped : OVERLAPPED;
    }
}

createShadersHotReload :: (hot_reload : *ShadersHotReload) {
    if !fileExists(ShaderCompiler.SOURCE_SHADERS_FOLDER) {
        #if DEBUG_BUILD warningMessage("Source shaders folder is not found: %", ShaderCompiler.SOURCE_SHADERS_FOLDER);
        return;
    }

    createThread(*hot_reload.thread,
                 hotReloadProc,
                 hot_reload,
                 "Shaders Hot Reload",
                 .SHADERS_HOT_RELOAD,
                 0, // persistent arena is not needed
                 readSetting("arenas.per_frame_capacity"));

    #if OS == .WINDOWS {
        utf16_source_shaders_folder : [ShaderCompiler.SOURCE_SHADERS_FOLDER.count + 1] WCHAR = ---;
        ASCIIToUTF16(*utf16_source_shaders_folder, ShaderCompiler.SOURCE_SHADERS_FOLDER);

        hot_reload.directory = CreateFileW(utf16_source_shaders_folder.data,
                                           FILE_LIST_DIRECTORY,
                                           FILE_SHARE_READ | FILE_SHARE_WRITE,
                                           null,
                                           OPEN_EXISTING,
                                           FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OVERLAPPED,
                                           null);
        assert(hot_reload.directory != INVALID_HANDLE_VALUE, print_sys_error = true);

        hot_reload.overlapped.hEvent = CreateEventExW(null, null, 0, EVENT_ALL_ACCESS);
        assert(hot_reload.overlapped.hEvent, print_sys_error = true);
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
        result := CancelIoEx(hot_reload.directory, *hot_reload.overlapped);
        assert(result || GetLastError() == ERROR_NOT_FOUND, print_sys_error = true);
    } else {
        notImplemented();
    }

    waitThread(*hot_reload.thread);

    #if OS == .WINDOWS {
        debugCheck(CloseHandle(hot_reload.overlapped.hEvent), print_sys_error = true);
        debugCheck(CloseHandle(hot_reload.directory), print_sys_error = true);
    } else {
        notImplemented();
    }

    closeThreadHandle(*hot_reload.thread);
}

#scope_file

#if OS == .WINDOWS {
    hotReloadProc :: (hot_reload : *ShadersHotReload) {
        notification_information_buffer : [DEFAULT_PAGE_SIZE] u8 #align 4;

        while true {
            resetArena(*context.pet.arenas.per_frame);
            Basic.reset_temporary_storage();

            info := cast(*FILE_NOTIFY_EXTENDED_INFORMATION) notification_information_buffer.data;
            debugCheck(ReadDirectoryChangesExW(hot_reload.directory,
                                               info,
                                               notification_information_buffer.count,
                                               TRUE,
                                               .LAST_WRITE,
                                               null,
                                               *hot_reload.overlapped,
                                               null,
                                               .ReadDirectoryNotifyExtendedInformation),
                       print_sys_error = true);

            wait_result := WaitForSingleObjectEx(hot_reload.overlapped.hEvent, INFINITE, FALSE);
            assert(wait_result == WAIT_OBJECT_0, print_sys_error = true);

            status_block := cast(*IO_STATUS_BLOCK) *hot_reload.overlapped;
            if status_block.Status == STATUS_SUCCESS {
                assert(status_block.Information > 0, print_sys_error = true, RtlNtStatusToDosError(status_block.Status));

                while true {
                    // Windows emmits 2 events on every file write:
                    //     1st - from the application's write call
                    //     2nd - from file system cache write call.
                    // ReadDirectoryChangesExW operates on file system level, so it doesn't know about process who caused that access.
                    //     https://stackoverflow.com/questions/14036449/c-winapi-readdirectorychangesw-receiving-double-notifications
                    //
                    // The only way to know this is to create a security audit and track event log.
                    //     https://stackoverflow.com/a/7607255
                    //
                    // In my opinion, it's too much, so I've made this empirically found workaround: the first notification
                    // (from application) has FileSize and AllocatedLength equal 0, the second one (from system cache) has them filled.
                    // So if it's one of those notification we can safely ignore it, if it's really an empty file we are also not
                    // interested in it.
                    if info.FileSize.QuadPart {
                        filename := UTF16ToUTF8(.{ info.FileNameLength / size_of(WCHAR), info.FileName.data });
                        reloadShader(filename);
                    }

                    if !info.NextEntryOffset break;
                    info = cast(*void, info) + info.NextEntryOffset;
                }
            } else {
                assert(status_block.Status == STATUS_CANCELLED, print_sys_error = true, RtlNtStatusToDosError(status_block.Status));
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
    recompileCallback :: (hot_reload : *ShadersHotReload, source_file_info : File.Info(.RELATIVE)) -> EnumerateFilesCallbackResult {
        if String.path_extension(source_file_info.path) != "shader" {
            return .CONTINUE;
        }

        shader_name := string.{
            source_file_info.path.count - ".shader".count,
            source_file_info.path.data
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
    }

    error := enumerateFiles(ShaderCompiler.SOURCE_SHADERS_FOLDER, recompileCallback, hot_reload, recursively = true);
    if error == {
        case .FILE_NOT_FOUND; #through;
        case .PATH_NOT_FOUND;
            verboseMessage("Source shaders folder is not found: %", ShaderCompiler.SOURCE_SHADERS_FOLDER);
        case .NONE;
            // everything is good
        case;
            assertMessage("enumerateFiles(%) has failed", ShaderCompiler.SOURCE_SHADERS_FOLDER);
    }
}
