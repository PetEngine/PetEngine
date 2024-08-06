//
// WindowManager
//

WindowManager :: struct {
    MAX_WINDOWS :: 16;

    active_windows : struct {
        first : *Window;
        last  : *Window;
        count : u8;
    };

    mutex : Mutex;
}

createWindowManager :: () {
    assert(!context.pet.core.window_manager);

    #if OS == .WINDOWS {
        createWin32WindowManager();
    } else {
        notImplemented();
    }
}

destroyWindowManager :: () {
    #if OS == .WINDOWS {
        destroyWin32WindowManager();
    } else {
        notImplemented();
    }
}

processAllWindowsEvents :: () -> bool {
    assertThreadKind(.MAIN);

    manager := context.pet.core.window_manager;
    scopedLock(*manager.mutex);

    windows_it := context.pet.core.window_manager.active_windows.first;
    while windows_it {
        processWindowEvents(windows_it);
        if windows_it.flags == .CLOSED {
            destroyWindow(windows_it);
        }
        windows_it = windows_it.next_active;
    }

    return manager.active_windows.count > 0;
}

forEachActiveWindow :: (code : Code) #expand {
    windows_it := context.pet.core.window_manager.active_windows.first;
    while windows_it {
        assert(!(windows_it.flags & .CLOSED));
        assert(windows_it.id != Window.INVALID_ID);

        // Should work with 'continue'
        defer windows_it = windows_it.next_active;

        #insert,scope() code;
    }
}

//
// Window
//

Window :: struct {
    OS_DEFAULT_POSITION : s16 : 0xFFFF;
    OS_DEFAULT_SIZE     : u16 : 0xFFFF;
    INVALID_ID          : u8  : WindowManager.MAX_WINDOWS;

    Flags :: enum_flags u8 {
        CLOSED;
        MOVED;
        RESIZED;
        MINIMIZED;
        MAXIMIZED;
    }

    next_active : *Window;

    rect      : Rect;
    surface   : Rect;
    screen    : Resolution;
    dpi_scale : f32;

    id    : u8    = INVALID_ID;
    flags : Flags = .CLOSED;

    input : Input;

    proc_context                   : Context;
    proc_context_temporary_storage : Temporary_Storage;
}

createWindow :: (
    x       : s16        = Window.OS_DEFAULT_POSITION,
    y       : s16        = Window.OS_DEFAULT_POSITION,
    surface : Resolution = .{ Window.OS_DEFAULT_SIZE, Window.OS_DEFAULT_SIZE },
    title   : string     = ENGINE_NAME
) -> *Window #must {
    window : *Window;

    #if OS == .WINDOWS {
        window = allocateWin32Window();
    } else {
        notImplemented();
    }

    {
        manager := context.pet.core.window_manager;
        scopedLock(*manager.mutex);

        if manager.active_windows.last {
            manager.active_windows.last.next_active = window;
        } else {
            manager.active_windows.first = window;
        }
        manager.active_windows.last = window;
    }

    // Window does not have its own thread, but ideologically separate window = separate thread.
    {
        window.proc_context.allocator   = context.allocator;
        window.proc_context.logger      = context.logger;
        window.proc_context.logger_data = context.logger_data;
        window.proc_context.print_style = context.print_style;
        Context.pet.initGlobals(*window.proc_context);

        push_context window.proc_context {
            context.context_info    = type_info(Context);
            context.thread_index    = getNextThreadIndex();
            context.pet.thread.kind = .WINDOW;

            context.allocator.proc(.THREAD_START, 0, 0, null, context.allocator.data);

            thread_name_length := title.count + " window".count;
            context.pet.thread.name.data = Basic.alloc(thread_name_length);
            appendToString(*context.pet.thread.name, thread_name_length, title, " window");

            context.temporary_storage = *window.proc_context_temporary_storage;

            // TEMPORARY_STORAGE_SIZE is defined by the compiler based on Build_Options.temporary_storage_size
            temporary_storage_data := Allocator.rpaligned_alloc(DEFAULT_CACHE_LINE_SIZE, TEMPORARY_STORAGE_SIZE);
            set_initial_data(context.temporary_storage, TEMPORARY_STORAGE_SIZE, temporary_storage_data);

            // @TODO: #Settings. Get persistent arena capacity from settings.
            createArena(*context.pet.arenas.persistent, gigaBytes(1), "Persistent");

            // @TODO: #Settings. Get per frame arena capacity from settings.
            createArena(*context.pet.arenas.per_frame, megaBytes(512), "Per frame");
        }
    }

    #if OS == .WINDOWS {
        createWin32Window(cast(*Win32Window) window, x, y, surface, title);
    } else {
        notImplemented();
    }

    return window;
}

showWindow :: (window : *Window) {
    #if OS == .WINDOWS {
        showWin32Window(cast(*Win32Window) window);
    } else {
        notImplemented();
    }

    window.flags &= ~.CLOSED;
}

getWindowTitle :: (window : *Window) -> string {
    title : string;

    #if OS == .WINDOWS {
        title = getWin32WindowTitle(cast(*Win32Window) window);
    } else {
        notImplemented();
    }

    return title;
}

setWindowTitle :: (window : *Window, title : string) {
    #if OS == .WINDOWS {
        setWin32WindowTitle(cast(*Win32Window) window, title);
    } else {
        notImplemented();
    }
}

#scope_file

destroyWindow :: (window : *Window) {
    #if OS == .WINDOWS {
        destroyWin32Window(cast(*Win32Window) window);
    } else {
        notImplemented();
    }

    {
        manager := context.pet.core.window_manager;
        assert(!tryLock(*manager.mutex), "Lock should have already been acquired in processAllWindowsEvents");

        if manager.active_windows.count == 0 {
           manager.active_windows.first = null;
           manager.active_windows.last  = null;
        } else if manager.active_windows.first == window {
            manager.active_windows.first = window.next_active;
        } else {
            prev_active := manager.active_windows.first;
            assert(prev_active);

            while prev_active.next_active != window {
                assert(prev_active.next_active);
                prev_active = prev_active.next_active;
            }

            if manager.active_windows.last == window {
                manager.active_windows.last = prev_active;
            }

            prev_active.next_active = window.next_active;
        }

        window.next_active = null;
    }

    push_context window.proc_context {
        destroyArena(*context.pet.arenas.per_frame);
        destroyArena(*context.pet.arenas.persistent);

        Allocator.rpfree(context.temporary_storage.original_data);
        Basic.free(context.pet.thread.name.data);
        context.allocator.proc(.THREAD_STOP, 0, 0, null, context.allocator.data);
    }

    // Reset the entire state for future reuse
    window.* = .{};
}

processWindowEvents :: (window : *Window) {
    // Reset flags for a new frame.
    window.flags &= ~(.MOVED | .RESIZED);
    resetInput(*window.input);

    #if OS == .WINDOWS {
        processRawInput(cast(*Win32Window) window);
        processXInput(*window.input);
        processWin32WindowEvents(cast(*Win32Window) window);
    } else {
        notImplemented();
    }
}

#if OS == .WINDOWS {
    #load "windows/window.jai";
} else {
    notImplemented();
}
