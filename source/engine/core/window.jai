//
// WindowManager
//

WindowManager :: struct {
    MAX_WINDOWS :: 16;

    windows_count : u8;
}

createWindowManager :: () -> *WindowManager #must {
    manager : *WindowManager;

    #if OS == .WINDOWS {
        manager = createWin32WindowManager();
    } else {
        notImplemented();
    }

    return manager;
}

destroyWindowManager :: (manager : *WindowManager) {
    #if OS == .WINDOWS {
        destroyWin32WindowManager(cast(*Win32WindowManager) manager);
    } else {
        notImplemented();
    }
}

//
// Window
//

Window :: struct {
    OS_DEFAULT_POSITION : s16 : 0xFFFF;
    OS_DEFAULT_SIZE     : u16 : 0xFFFF;

    Flags :: enum_flags u8 {
        CLOSED;
        MOVED;
        RESIZED;
        MINIMIZED;
        MAXIMIZED;
    }

    rect : struct {
        x      : s16;
        y      : s16;
        width  : u16;
        height : u16;
    };

    surface : struct {
        width  : u16;
        height : u16;
    };

    screen : struct {
        width  : u16;
        height : u16;
    };

    dpi_scale : f32;

    flags : Flags;

    input : Input;
}

createWindow :: (
    manager        : *WindowManager,
    x              := Window.OS_DEFAULT_POSITION,
    y              := Window.OS_DEFAULT_POSITION,
    surface_width  := Window.OS_DEFAULT_SIZE,
    surface_height := Window.OS_DEFAULT_SIZE,
    title          := "Pet Engine"
) -> *Window #must {
    window : *Window;

    #if OS == .WINDOWS {
        window = createWin32Window(cast(*Win32WindowManager) manager, x, y, surface_width, surface_height, title);
    } else {
        notImplemented();
    }

    return window;
}

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

    window.flags &= ~.CLOSED;
}

processWindowEvents :: (window : *Window) -> bool {
    // Reset flags for a new frame.
    window.flags &= ~(.MOVED | .RESIZED | .MINIMIZED | .MAXIMIZED);
    resetInput(*window.input);

    #if OS == .WINDOWS {
        processRawInput(cast(*Win32Window) window);
        processWin32WindowEvents(cast(*Win32Window) window);
    } else {
        notImplemented();
    }

    return !(window.flags & .CLOSED);
}

#scope_file

#if OS == .WINDOWS {
    #load "windows/window.jai";
} else {
    notImplemented();
}
