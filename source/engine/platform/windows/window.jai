#assert OS == .WINDOWS "This file should not be used anywhere except Windows builds";

#scope_module

//
// Win32 window manager
//

Win32WindowManager :: struct {
    #as using public_data : WindowManager;

    app_instance : HMODULE;
    window_class : ATOM;

    // @TODO: #ContextDependency
    jai_context : *Context;

    free_windows : *Win32Window;
    windows      : [WindowManager.MAX_WINDOWS] Win32Window;
}

// @TODO: #PersistentArena
g_windowManager : Win32WindowManager;

createWin32WindowManager :: () -> *Win32WindowManager #must {
    manager := *g_windowManager;

    result := GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS,
                                 cast,no_check(LPCWSTR) #this,
                                 *manager.app_instance);
    assert(result != FALSE);

    setMonitorDPIAwareness();

    ASCII_CLASS_NAME :: "PetEngineWindowClass";
    unicode_class_name : [ASCII_CLASS_NAME.count + 1] s16;
    for 0 .. ASCII_CLASS_NAME.count - 1 { // @TODO: #utf8_to_wide
        unicode_class_name[it] = ASCII_CLASS_NAME[it];
    }

    window_class : WNDCLASSEXW = ---;
    window_class.cbSize        = size_of(WNDCLASSEXW);
    window_class.style         = CS_VREDRAW | CS_HREDRAW | CS_DBLCLKS | CS_OWNDC;
    window_class.lpfnWndProc   = windowEventsCallback;
    window_class.cbClsExtra    = 0;
    window_class.cbWndExtra    = 0;
    window_class.hInstance     = manager.app_instance;
    window_class.hIcon         = LoadIconW(manager.app_instance, IDI_APPLICATION);
    window_class.hCursor       = LoadCursorW(manager.app_instance, IDC_ARROW);
    window_class.hbrBackground = cast,no_check(HBRUSH) (COLOR_BACKGROUND + 1);
    window_class.lpszMenuName  = null;
    window_class.lpszClassName = unicode_class_name.data;
    window_class.hIconSm       = window_class.hIcon;

    manager.window_class = RegisterClassExW(*window_class);
    assert(manager.window_class != 0);

    for 0 .. manager.MAX_WINDOWS - 2 {
        current_window := *manager.windows[it];
        next_window    := *manager.windows[it + 1];

        current_window.flags     = .CLOSED;
        current_window.manager   = manager;
        current_window.next_free = next_window;
    }

    last_window := *manager.windows[manager.MAX_WINDOWS - 1];
    last_window.flags     = .CLOSED;
    last_window.manager   = manager;
    last_window.next_free = null;

    manager.free_windows = manager.windows.data;
    manager.jai_context  = *context;

    return manager;
}

destroyWin32WindowManager :: (manager : *Win32WindowManager) {
    assert(manager == *g_windowManager);

    for manager.windows {
        if it.handle {
            SendMessageW(it.handle, WM_CLOSE, 0, 0);
            assert(it.handle == null);
        }
    }

    assert(manager.windows_count == 0);

    result := UnregisterClassW(cast,no_check(LPCWSTR) manager.window_class, manager.app_instance);
    assert(result != FALSE);

    result = FreeLibrary(manager.app_instance);
    assert(result != FALSE);
}

//
// Win32 window
//

Win32Window :: struct {
    #as using public_data : Window;

    PlatformFlags :: enum_flags u8 {
        APPLY_DPI_SCALING_ON_SHOW;
    }

    platform_flags : PlatformFlags;

    handle : HANDLE;

    manager   : *Win32WindowManager;
    next_free : *Win32Window;
}

createWin32Window :: (
    manager        : *Win32WindowManager,
    x              : s16,
    y              : s16,
    surface_width  : u16,
    surface_height : u16,
    title          : string
) -> *Win32Window #must {
    assert(manager == *g_windowManager);

    window := allocateWindow(manager);

    // @TODO: #Editor. WS_EX_ACCEPTFILES only in editor builds.
    // @TODO: System language reading alignment: WS_EX_LAYOUTRTL, WS_EX_RTLREADING
    WINDOW_STYLES          :: WS_OVERLAPPEDWINDOW;
    EXTENDED_WINDOW_STYLES :: WS_EX_OVERLAPPEDWINDOW
                            | WS_EX_ACCEPTFILES
                            | WS_EX_NOPARENTNOTIFY;

    window_rect_width  := CW_USEDEFAULT;
    window_rect_height := CW_USEDEFAULT;

    if surface_width != Window.OS_DEFAULT_SIZE && surface_height != Window.OS_DEFAULT_SIZE {
        window.surface.width  = surface_width;
        window.surface.height = surface_height;

        window_rect := RECT.{ 0, 0, surface_width, surface_height };
        if AdjustWindowRectEx(*window_rect, WINDOW_STYLES, FALSE, EXTENDED_WINDOW_STYLES) {
            // @TODO: WS_EX_LAYOUTRTL ?
            window_rect_width  = window_rect.right  - window_rect.left;
            window_rect_height = window_rect.bottom - window_rect.top;
        }
    }

    unicode_title := pushToArena(*context.pet.per_frame_arena, s16, title.count + 1);
    for 0..title.count-1 { // @TODO: #utf8_to_wide
        unicode_title[it] = title[it];
    }

    window.handle = CreateWindowExW(EXTENDED_WINDOW_STYLES,
                                    cast,no_check(LPCWSTR) manager.window_class,
                                    unicode_title,
                                    WINDOW_STYLES,
                                    ifx x == window.OS_DEFAULT_POSITION then CW_USEDEFAULT else x,
                                    ifx y == window.OS_DEFAULT_POSITION then CW_USEDEFAULT else y,
                                    window_rect_width,
                                    window_rect_height,
                                    null,
                                    null,
                                    manager.app_instance,
                                    null);
    assert(window.handle != null);

    SetWindowLongPtrW(window.handle, GWLP_USERDATA, cast,no_check(LONG_PTR) window);

    if window_rect_width != CW_USEDEFAULT && window_rect_height != CW_USEDEFAULT {
        window.dpi_scale = applyInitialDPIScalingToWindow(window.handle, cast(u16) window_rect_width, cast(u16) window_rect_height);
    } else {
        window.dpi_scale       = 1.0;
        window.platform_flags |= .APPLY_DPI_SCALING_ON_SHOW;
    }

    return window;
}

destroyWin32Window :: (window : *Win32Window) {
    PostMessageW(window.handle, WM_CLOSE, 0, 0);
}

showWin32Window :: (window : *Win32Window) {
    if window.flags & .CLOSED {
        // "An application should specify SW_SHOWNORMAL when displaying the window for the first time."
        // https://learn.microsoft.com/en-us/winows/win32/api/winuser/nf-winuser-showwindow#parameters
        ShowWindow(window.handle, SW_SHOWNORMAL);
    } else {
        ShowWindow(window.handle, SW_SHOW);
    }
}

processWin32WindowEvents :: (window : *Win32Window) {
    msg : MSG;
    while PeekMessageW(*msg, window.handle, 0, 0, PM_REMOVE) {
        TranslateMessage(*msg);
        DispatchMessageW(*msg);
    }
}

#scope_file

windowEventsCallback :: (
    window_handle : HWND,
    message       : u32,
    wparam        : WPARAM,
    lparam        : LPARAM
) -> LRESULT #c_call {
    result : LRESULT = 0;
    window := cast,no_check(*Win32Window) GetWindowLongPtrW(window_handle, GWLP_USERDATA);

    if message == {
        case WM_DESTROY;
            push_context window.manager.jai_context {
                deallocateWindow(window);
            }

            result = DefWindowProcW(window_handle, message, wparam, lparam);

        case WM_SIZE;
            window.flags |= .RESIZED;

            if wparam == {
                case SIZE_MINIMIZED; window.flags |= .MINIMIZED;
                case SIZE_MAXIMIZED; window.flags |= .MAXIMIZED;
            }

            window.surface.width  = cast(u16) (lparam & 0xFFFF);
            window.surface.height = cast(u16) (lparam >> 16);

            result = DefWindowProcW(window_handle, message, wparam, lparam);

        case WM_CLOSE;
            window.flags |= .CLOSED;

            result = DefWindowProcW(window_handle, message, wparam, lparam);

        case WM_WINDOWPOSCHANGED;
            window_position := cast,no_check(*WINDOWPOS) lparam;

            if window.rect.x != window_position.x || window.rect.y != window_position.y {
                window.flags |= .MOVED;
            }

            window.rect.x      = cast(s16) window_position.x;
            window.rect.y      = cast(s16) window_position.y;
            window.rect.width  = cast(u16) window_position.cx;
            window.rect.height = cast(u16) window_position.cy;

            if window.platform_flags & .APPLY_DPI_SCALING_ON_SHOW {
                push_context window.manager.jai_context {
                    window.dpi_scale = applyInitialDPIScalingToWindow(window_handle, window.rect.width, window.rect.height);
                }
                window.platform_flags &= ~.APPLY_DPI_SCALING_ON_SHOW;
            }

            result = DefWindowProcW(window_handle, message, wparam, lparam);

        case WM_MENUCHAR;
            // To suppress bip sound on Alt+Enter when there is no menu created
            if !lparam && (wparam & 0xFFFF) == #char "\n" {
                result = MNC_CLOSE;
            }

        case WM_DPICHANGED;
            new_dpi          := cast(f32) (wparam & 0xFFFF);
            DEFAULT_DPI      :: 96.0;
            window.dpi_scale  = new_dpi / DEFAULT_DPI;

            new_window_rect := cast,no_check(*RECT) lparam;

            SET_WINDOW_POS_FLAGS :: SWP_NOZORDER
                                  | SWP_NOREDRAW
                                  | SWP_NOACTIVATE
                                  | SWP_NOCOPYBITS
                                  | SWP_NOOWNERZORDER
                                  | SWP_NOSENDCHANGING
                                  | SWP_DEFERERASE;

            success := SetWindowPos(window_handle,
                                           HWND_TOP,
                                           new_window_rect.left,
                                           new_window_rect.top,
                                           new_window_rect.right  - new_window_rect.left,
                                           new_window_rect.bottom - new_window_rect.top,
                                           SET_WINDOW_POS_FLAGS);

            push_context window.manager.jai_context {
                assert(success != FALSE);
            }

            result = DefWindowProcW(window_handle, message, wparam, lparam);

        case;
            result = DefWindowProcW(window_handle, message, wparam, lparam);
    }

    return result;
}

setMonitorDPIAwareness :: () {
    success := SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    assert(success != FALSE);

    previous_thread_dpi_awareness_context := SetThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    assert(previous_thread_dpi_awareness_context != null);

    assert(GetAwarenessFromDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2) == .DPI_AWARENESS_PER_MONITOR_AWARE);

    previous_dpi_hosting_behavior := SetThreadDpiHostingBehavior(.DPI_HOSTING_BEHAVIOR_MIXED);
    assert(previous_dpi_hosting_behavior != .DPI_HOSTING_BEHAVIOR_INVALID);
}

allocateWindow :: (manager : *Win32WindowManager) -> *Win32Window #must {
    assert(manager == *g_windowManager);
    assert(manager.windows_count < manager.MAX_WINDOWS, "You have created too many windows, maximum number allowed is %", manager.MAX_WINDOWS);

    window := manager.free_windows;

    manager.free_windows = window.next_free;
    window.next_free     = null;

    manager.windows_count += 1;

    assert(window != null);
    return window;
}

deallocateWindow :: (window : *Win32Window) {
    manager := window.manager;
    assert(manager == *g_windowManager);
    assert(manager.windows_count != 0);

    window.next_free     = manager.free_windows;
    manager.free_windows = window;

    manager.windows_count -= 1;

    window.handle = null;
}

applyInitialDPIScalingToWindow :: (window_handle : HWND, width : u16, height : u16) -> f32 {
    assert(width && width != Window.OS_DEFAULT_SIZE && height && height != Window.OS_DEFAULT_SIZE);

    monitor_dpi := cast(f32) GetDpiForWindow(window_handle);
    DEFAULT_DPI :: 96.0;
    dpi_scale   := monitor_dpi / DEFAULT_DPI;

    scaled_width  := cast(u16) Math.ceil(width  * dpi_scale);
    scaled_height := cast(u16) Math.ceil(height * dpi_scale);

    SET_WINDOW_POS_FLAGS :: SWP_NOMOVE
                          | SWP_NOZORDER
                          | SWP_NOREDRAW
                          | SWP_NOACTIVATE
                          | SWP_NOCOPYBITS
                          | SWP_NOOWNERZORDER
                          | SWP_NOSENDCHANGING
                          | SWP_DEFERERASE
                          | SWP_ASYNCWINDOWPOS;

    result := SetWindowPos(window_handle, HWND_TOP, 0, 0, scaled_width, scaled_height, SET_WINDOW_POS_FLAGS);
    assert(result != FALSE);

    return dpi_scale;
}

Math  :: #import "Math";
