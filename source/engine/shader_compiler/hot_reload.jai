ShadersHotReload :: struct {
    thread : Thread(ShadersHotReload);

    #if OS == .WINDOWS {
        notification : HANDLE;
        directory    : HANDLE;
        event        : HANDLE;
    }

    running : bool;
}

initShadersHotReload :: (hot_reload : *ShadersHotReload) {
    createThread(*hot_reload.thread, hotReloadProc, hot_reload, name = "Shaders Hot Reload");

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

        EVENT_NAME :: "Shaders Hot Reload Event";
        wide_event_name : [EVENT_NAME.count + 1] WCHAR = ---;
        asciiToWide(*wide_event_name, EVENT_NAME, true);

        hot_reload.event = CreateEventExW(null, wide_event_name.data, 0, EVENT_ALL_ACCESS);
        assert(hot_reload.event, print_sys_error = true);
    } else {
        notImplemented();
    }

    hot_reload.running = true;
    startThread(*hot_reload.thread);
}

destroyShadersHotReload :: (hot_reload : *ShadersHotReload) {
    hot_reload.running = false;

    #if OS == .WINDOWS {
        debugCheck(CloseHandle(hot_reload.event), print_sys_error = true);
        debugCheck(CloseHandle(hot_reload.directory), print_sys_error = true);
        debugCheck(FindCloseChangeNotification(hot_reload.notification), print_sys_error = true);
    } else {
        notImplemented();
    }

    waitThread(*hot_reload.thread);
    closeThreadHandle(*hot_reload.thread);
}

#scope_file

#if OS == .WINDOWS {
    hotReloadProc :: (hot_reload : *ShadersHotReload) {
        notification_information_buffer : [4096] u8 #align 4;

        while hot_reload.running {
            resetArena(*context.pet.per_frame_arena);
            Basic.reset_temporary_storage();

            wait_result := WaitForSingleObjectEx(hot_reload.notification, INFINITE, FALSE);
            assert(wait_result == WAIT_OBJECT_0, print_sys_error = true);
            if !hot_reload.running break;

            info := cast(*FILE_NOTIFY_INFORMATION) notification_information_buffer.data;

            overlapped : OVERLAPPED;
            overlapped.hEvent = hot_reload.event;

            bytes_returned : u32;
            debugCheck(ReadDirectoryChangesW(hot_reload.directory,
                                             info,
                                             notification_information_buffer.count,
                                             TRUE,
                                             FILE_NOTIFY_CHANGE_LAST_WRITE,
                                             *bytes_returned,
                                             *overlapped,
                                             null),
                       print_sys_error = true);
            defer memset(notification_information_buffer.data, 0, bytes_returned);

            bytes_transferred : u32;
            debugCheck(GetOverlappedResult(hot_reload.directory, *overlapped, *bytes_transferred, TRUE),
                       print_sys_error = true);

            warningMessage("Bytes transferred: %", bytes_transferred);

            debugCheck(FindNextChangeNotification(hot_reload.notification), print_sys_error = true);
        }
    }
} else {
    notImplemented();
}
