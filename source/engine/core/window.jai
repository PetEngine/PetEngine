//
// WindowManager
//

WindowManager :: struct {
    MAX_WINDOWS :: 16;

    WindowsList :: struct {
        first : *Window;
        last  : *Window;
        count : u8;
    }

    windows : WindowsList;

    // This is a context for a Win32 window procedure. Since we process all input and all events for all windows on the same thread,
    // wich is main thread, we do not create a context for each window and instead just store a pointer to main thread's context
    // for all windows.
    jai_context : *#Context;
}

createWindowManager :: () {
    assert(!context.pet.core.window_manager);
    assertThreadKind(.MAIN);

    #if OS == .WINDOWS {
        createWin32WindowManager();
    } else {
        notImplemented();
    }

    // We will probably need to split platform version of creating window manager into 'allocate' and 'create'
    // to save context into `jai_context` just in case we will need it during the process of WindowManager creation.
    context.pet.core.window_manager.jai_context = *context;
}

destroyWindowManager :: () {
    assertThreadKind(.MAIN);

    for * context.pet.core.window_manager.windows {
        warningMessage("Window \"%\" with ID = % has not been destroyed", getWindowTitle(it), it.id);
        destroyWindow(it);
    }

    #if OS == .WINDOWS {
        destroyWin32WindowManager();
    } else {
        notImplemented();
    }
}

processWindowsEvents :: () -> bool {
    assertThreadKind(.MAIN);

    manager := context.pet.core.window_manager;

    for * manager.windows {
        // Reset flags for a new frame.
        it.flags &= ~(.MOVED | .RESIZED);
        resetInput(*it.input);

        #if OS == .WINDOWS {
            processXInput(*it.input);
        } else {
            notImplemented();
        }
    }

    #if OS == .WINDOWS {
        pollRawInputBuffer();
        quit := processWin32Messages();
    } else {
        quit :: true;
        notImplemented();
    }

    assert(!quit || !manager.windows.count);
    return !quit;
}

for_expansion :: (list : *WindowManager.WindowsList, body : Code, flags : For_Flags) #expand {
    #assert flags & .POINTER "The only way to iterate over WindowManager.WindowsList is by pointer";

    `it       := list.first;
    `it_index : int;

    while it {
        assert(it.id != Window.INVALID_ID);
        #if OS == .WINDOWS {
            assert((cast(*Win32Window) it).handle);
        } else {
            notImplemented();
        }

        // we will have it.next == null if the user will use remove statement
        next      := it.next;
        increment := 1;

        #insert(
            continue = { it = next; it_index += increment; continue; },
            remove   = { destroyWindow(it); increment = 0; }
        ) body;

        it        = next;
        it_index += increment;
    }

    assert(it_index <= list.count, "it_index (%) <= list.count (%)", it_index, list.count);
}

//
// Window
//

Window :: struct {
    OS_DEFAULT_POSITION : s16 : 0xFFFF;
    OS_DEFAULT_SIZE     : u16 : 0xFFFF;
    INVALID_ID          : u8  : WindowManager.MAX_WINDOWS;
    MIN_WIDTH           : s16 : 640;
    MIN_HEIGHT          : s16 : 360;

    Flags :: enum_flags u8 {
        MOVED;
        RESIZED;
        MINIMIZED;
        MAXIMIZED;
    }

    next : *Window;

    rect    : Rect;
    surface : Rect;
    screen  : Resolution;

    dpi_scale : f32;

    id    : u8    = INVALID_ID;
    flags : Flags;

    input : Input;
}

createWindow :: (
    x       : s16        = Window.OS_DEFAULT_POSITION,
    y       : s16        = Window.OS_DEFAULT_POSITION,
    surface : Resolution = .{ Window.OS_DEFAULT_SIZE, Window.OS_DEFAULT_SIZE },
    title   : string     = ENGINE_NAME
) -> *Window #must {
    assertThreadKind(.MAIN);

    manager := context.pet.core.window_manager;

    //
    // Allocate
    //

    assert(manager.windows.count < WindowManager.MAX_WINDOWS,
           "You have created too many windows, maximum number allowed is %",
           WindowManager.MAX_WINDOWS);

    window : *Window;
    #if OS == .WINDOWS {
        window = allocateWin32Window();
    } else {
        notImplemented();
    }

    assert(window);
    assert(window.id == Window.INVALID_ID);

    window.id = manager.windows.count;
    manager.windows.count += 1;

    if manager.windows.last {
        manager.windows.last.next = window;
    } else {
        manager.windows.first = window;
    }
    manager.windows.last = window;

    //
    // Create
    //

    #if OS == .WINDOWS {
        createWin32Window(cast(*Win32Window) window, x, y, surface, title);
    } else {
        notImplemented();
    }

    return window;
}

// There is no need to call this function if you do not want to close the window prematurely
// i.e. before the user close it via OS UI
destroyWindow :: (window : *Window) {
    #if OS == .WINDOWS {
        destroyWin32Window(cast(*Win32Window) window);
    } else {
        notImplemented();
    }
}

showWindow :: (window : *Window) {
    #if OS == .WINDOWS {
        showWin32Window(cast(*Win32Window) window);
    } else {
        notImplemented();
    }
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

#scope_module

deallocateWindow :: (window : *Window) {
    assertThreadKind(.MAIN);

    manager := context.pet.core.window_manager;

    //
    // Deallocate
    //

    assert(manager.windows.count > 0);
    manager.windows.count -= 1;

    if !manager.windows.count {
       manager.windows.first = null;
       manager.windows.last  = null;
    } else if manager.windows.first == window {
        manager.windows.first = window.next;
    } else {
        prev := manager.windows.first;
        assert(prev);

        while prev.next != window {
            assert(prev.next);
            prev = prev.next;
        }

        if manager.windows.last == window {
            manager.windows.last = prev;
            assert(!window.next);
        }

        prev.next = window.next;
    }

    //
    // Reset the entire state for future reuse
    //

    #if OS == .WINDOWS {
        (cast(*Win32Window) window).* = .{};
    } else {
        notImplemented();
        window.* = .{};
    }
}

#scope_file

#if OS == .WINDOWS {
    #load "windows/window.jai";
} else {
    notImplemented();
}
