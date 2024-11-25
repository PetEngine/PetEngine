#assert OS == .WINDOWS "This file should not be used anywhere except Windows builds";

//
// Win32 window manager
//

Win32WindowManager :: struct {
    #as using public_data : WindowManager;

    app_instance : HMODULE;
    window_class : ATOM;

    windows : [WindowManager.MAX_WINDOWS] Win32Window;

    use_dark_theme : bool;
}

createWin32WindowManager :: () {
    manager := pushToArena(*context.pet.arenas.persistent, Win32WindowManager);
    context.pet.core.window_manager = manager;

    manager.app_instance = GetModuleHandleW(null);
    assert(manager.app_instance, print_sys_error = true);

    setMonitorDPIAwareness();

    CLASS_NAME       :: "PetEngineWindowClass";
    utf16_class_name : [CLASS_NAME.count + 1] WCHAR = ---;
    ASCIIToUTF16(*utf16_class_name, CLASS_NAME);

    icon_handle := LoadIconW(null, IDI_APPLICATION);
    assert(icon_handle, print_sys_error = true);

    cursor_handle := LoadCursorW(null, IDC_ARROW);
    assert(cursor_handle, print_sys_error = true);

    window_class := WNDCLASSEXW.{
        cbSize        = size_of(WNDCLASSEXW),
        style         = CS_VREDRAW | CS_HREDRAW | CS_DBLCLKS | CS_OWNDC,
        lpfnWndProc   = windowEventsCallback,
        hInstance     = manager.app_instance,
        hIcon         = icon_handle,
        hCursor       = cursor_handle,
        hbrBackground = cast,no_check(HBRUSH) (COLOR_WINDOW + 1),
        lpszMenuName  = null,
        lpszClassName = utf16_class_name.data,
        hIconSm       = icon_handle,
    };

    manager.window_class = RegisterClassExW(*window_class);
    assert(manager.window_class, print_sys_error = true);

    manager.use_dark_theme = useDarkTheme();
}

destroyWin32WindowManager :: () {
    manager := cast(*Win32WindowManager) context.pet.core.window_manager;

    for manager.windows {
        if it.handle {
            SendMessageW(it.handle, WM_CLOSE, 0, 0);
            assert(it.handle == null);
        }
    }
    assert(manager.active_windows.count == 0);

    debugCheck(UnregisterClassW(cast,no_check(LPCWSTR) manager.window_class, manager.app_instance),
               print_sys_error = true);

    debugCheck(FreeLibrary(manager.app_instance),
               print_sys_error = true);
}

allocateWin32Window :: () -> *Win32Window #must {
    manager := cast(*Win32WindowManager) context.pet.core.window_manager;
    scopedLock(*manager.mutex);

    assert(manager.active_windows.count < Win32WindowManager.MAX_WINDOWS,
           "You have created too many windows, maximum number allowed is %",
           Win32WindowManager.MAX_WINDOWS);

    window : *Win32Window;
    for * manager.windows {
        if !it.handle {
            window = it;
            break;
        }
    }

    assert(window);
    assert(window.flags == .CLOSED);
    assert(window.id    == Window.INVALID_ID);

    window.id = manager.active_windows.count;
    manager.active_windows.count += 1;

    return window;
}

//
// Win32 window
//

Win32Window :: struct {
    #as using public_data : Window;

    PlatformFlags :: enum_flags u8 {
        // If we create a window with Window.OS_DEFAULT_SIZE we cannot apply dpi scaling on createWin32Window
        // since we do not know the actual window rect yet, so we apply it on WM_WINDOWPOSCHANGED message
        // when we get its rect for the first time.
        APPLY_DPI_SCALING_ON_SHOW;

        // Win32 MakeCode for Key.PAUSE is 0xE11D45, which is > 0xFFFF, so it's split in 2 reports: 0xE11D and 0x0045.
        // We know that 0xE11D is used with Key.PAUSE only, so we just skip the second report assuming it == 0x0045.
        HANDLING_KEY_PAUSE;
    }

    handle         : HWND;
    platform_flags : PlatformFlags;
}

createWin32Window :: (window : *Win32Window, x : s16, y : s16, surface : Resolution, title : string) {
    manager := cast(*Win32WindowManager) context.pet.core.window_manager;

    // @TODO: #Editor. WS_EX_ACCEPTFILES only in editor builds.
    // @TODO: System language reading alignment: WS_EX_LAYOUTRTL, WS_EX_RTLREADING
    WINDOW_STYLES          :: WS_OVERLAPPEDWINDOW;
    EXTENDED_WINDOW_STYLES :: WS_EX_OVERLAPPEDWINDOW
                            | WS_EX_ACCEPTFILES
                            | WS_EX_NOPARENTNOTIFY;

    window_rect_width  := CW_USEDEFAULT;
    window_rect_height := CW_USEDEFAULT;

    if surface.width != Window.OS_DEFAULT_SIZE && surface.height != Window.OS_DEFAULT_SIZE {
        window.surface.width  = surface.width;
        window.surface.height = surface.height;

        window_rect := RECT.{ 0, 0, surface.width, surface.height };
        debugCheck(AdjustWindowRectEx(*window_rect, WINDOW_STYLES, FALSE, EXTENDED_WINDOW_STYLES), print_sys_error = true);

        window_rect_width  = window_rect.right  - window_rect.left;
        window_rect_height = window_rect.bottom - window_rect.top;
    }

    class_name := cast,no_check(LPCWSTR) manager.window_class;
    assert((class_name & 0xFFFF) == class_name, "Window class atom should be in the low-order word only");

    utf16_title := UTF8ToUTF16(title, pushToArena, *context.pet.arenas.per_frame);

    window_rect_x : s32 = ifx x == window.OS_DEFAULT_POSITION then CW_USEDEFAULT else x;
    window_rect_y : s32 = ifx y == window.OS_DEFAULT_POSITION then CW_USEDEFAULT else y;

    window.handle = CreateWindowExW(EXTENDED_WINDOW_STYLES,
                                    class_name,
                                    utf16_title.data,
                                    WINDOW_STYLES,
                                    window_rect_x,
                                    window_rect_y,
                                    window_rect_width,
                                    window_rect_height,
                                    null,
                                    null,
                                    manager.app_instance,
                                    null);
    assert(window.handle, print_sys_error = true);

    SetWindowLongPtrW(window.handle, GWLP_USERDATA, cast,no_check(LONG_PTR) window);

    window.screen.width  = cast(u16) GetSystemMetrics(SM_CXSCREEN);
    window.screen.height = cast(u16) GetSystemMetrics(SM_CYSCREEN);

    if window_rect_width != CW_USEDEFAULT && window_rect_height != CW_USEDEFAULT {
        window.dpi_scale = applyInitialDPIScalingToWindow(window.handle, .{ cast(u16) window_rect_width, cast(u16) window_rect_height });
    } else {
        window.dpi_scale       = 1.0;
        window.platform_flags |= .APPLY_DPI_SCALING_ON_SHOW;
    }

    if manager.use_dark_theme {
        applyWindowTheme(window.handle);
    }
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

getWin32WindowTitle :: (window : *Win32Window) -> string {
    title_length := GetWindowTextLengthW(window.handle);
    assert(title_length > 0 || (title_length == 0 && GetLastError() == ERROR_SUCCESS));

    if !title_length return "";

    utf16_title := pushToArena(*context.pet.arenas.per_frame, WCHAR, title_length + 1);

    result := GetWindowTextW(window.handle, utf16_title, title_length + 1);
    assert(result == title_length, print_sys_error = true);

    title := UTF16ToUTF8(.{ title_length, utf16_title }, pushToArena, *context.pet.arenas.per_frame);
    return title;
}

setWin32WindowTitle :: (window : *Win32Window, title : string) {
    if title {
        utf16_title := UTF8ToUTF16(title, pushToArena, *context.pet.arenas.per_frame);
        debugCheck(SetWindowTextW(window.handle, utf16_title.data), print_sys_error = true);
    } else {
        debugCheck(SetWindowTextW(window.handle, null), print_sys_error = true);
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

windowEventsCallback :: (window_handle : HWND, message : u32, wparam : WPARAM, lparam : LPARAM) -> LRESULT #c_call {
    result : LRESULT;
    window := cast,no_check(*Win32Window) GetWindowLongPtrW(window_handle, GWLP_USERDATA);

    if message == {
        case WM_DESTROY; {
            push_context,defer_pop window.proc_context;
            autoResetPerFrameArenas();
            assertThreadKind(.WINDOW);

            deallocateWindow(window);

            result = DefWindowProcW(window_handle, message, wparam, lparam);
        }

        case WM_MOVE;
            window.flags |= .MOVED;

            window.surface.x = cast,trunc(s16) (lparam & 0xFFFF);
            window.surface.y = cast,trunc(s16) (lparam >> 16);

        case WM_SIZE;
            window.flags |= .RESIZED;
            window.flags &= ~(.MINIMIZED | .MAXIMIZED);

            if wparam == {
                case SIZE_MINIMIZED; window.flags |= .MINIMIZED;
                case SIZE_MAXIMIZED; window.flags |= .MAXIMIZED;
            }

            window.surface.width  = cast(u16) (lparam & 0xFFFF);
            window.surface.height = cast(u16) (lparam >> 16);

        case WM_CLOSE;
            window.flags |= .CLOSED;

            // DefWindowProc calls DestroyWindow to destroy the window
            result = DefWindowProcW(window_handle, message, wparam, lparam);

        case WM_SETTINGCHANGE; {
            push_context,defer_pop window.proc_context;
            autoResetPerFrameArenas();
            assertThreadKind(.WINDOW);

            checkWindowThemeChange(window_handle, wparam, lparam);

            result = DefWindowProcW(window_handle, message, wparam, lparam);
        }

        case WM_GETMINMAXINFO;
            if window {
                push_context,defer_pop window.proc_context;

                info := cast(*MINMAXINFO) lparam;

                window_style := cast(u32) GetWindowLongW(window_handle, GWL_STYLE);
                assert(window_style, print_sys_error = true);

                window_style_ex := cast(u32) GetWindowLongW(window_handle, GWL_EXSTYLE);
                assert(window_style_ex, print_sys_error = true);

                window_rect := RECT.{ 0, 0, Window.MIN_WIDTH, Window.MIN_HEIGHT };
                debugCheck(AdjustWindowRectEx(*window_rect, window_style, FALSE, window_style_ex), print_sys_error = true);

                info.ptMinTrackSize.x = window_rect.right  - window_rect.left;
                info.ptMinTrackSize.y = window_rect.bottom - window_rect.top;
            }

        case WM_WINDOWPOSCHANGED; {
            push_context,defer_pop window.proc_context;
            autoResetPerFrameArenas();
            assertThreadKind(.WINDOW);

            window_position := cast(*WINDOWPOS) lparam;

            window.rect.x      = cast,trunc(s16) window_position.x;
            window.rect.y      = cast,trunc(s16) window_position.y;
            window.rect.width  = cast(u16) window_position.cx;
            window.rect.height = cast(u16) window_position.cy;

            if window.platform_flags & .APPLY_DPI_SCALING_ON_SHOW {
                window.dpi_scale       = applyInitialDPIScalingToWindow(window_handle, window.rect.resolution);
                window.platform_flags &= ~.APPLY_DPI_SCALING_ON_SHOW;
            }

            // WM_SIZE and WM_MOVE are not sent if an application handles the WM_WINDOWPOSCHANGED without calling DefWindowProc
            result = DefWindowProcW(window_handle, message, wparam, lparam);
        }

        case WM_DISPLAYCHANGE;
            window.screen.width  = cast(u16) (lparam & 0xFFFF);
            window.screen.height = cast(u16) (lparam >> 16);

        case WM_INPUT_DEVICE_CHANGE; {
            push_context,defer_pop window.proc_context;
            autoResetPerFrameArenas();
            assertThreadKind(.WINDOW);

            onRawInputDeviceChange(cast(HANDLE) lparam, wparam);
        }

        case WM_INPUT; {
            push_context,defer_pop window.proc_context;
            autoResetPerFrameArenas();
            assertThreadKind(.WINDOW);

            assert(GET_RAWINPUT_CODE_WPARAM(wparam) == RIM_INPUT, "Input sink is not supported");
            onRawInput(window, cast(HRAWINPUT) lparam);

            // The application must call DefWindowProc so the system can perform cleanup
            result = DefWindowProcW(window_handle, message, wparam, lparam);
        }

        case WM_MENUCHAR;
            // To suppress bip sound on Alt+Enter when there is no menu created
            if !lparam && (wparam & 0xFFFF) == #char "\n" {
                result = MNC_CLOSE;
            }

        case WM_DPICHANGED; {
            push_context,defer_pop window.proc_context;
            autoResetPerFrameArenas();
            assertThreadKind(.WINDOW);

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

            assert(success, print_sys_error = true);
        }

        case;
            result = DefWindowProcW(window_handle, message, wparam, lparam);
    }

    return result;
}

setMonitorDPIAwareness :: () {
    debugCheck(SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2), print_sys_error = true);

    assert(GetAwarenessFromDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2) == .DPI_AWARENESS_PER_MONITOR_AWARE,
           print_sys_error = true);
}

deallocateWindow :: (window : *Win32Window) {
    assert(window.flags == .CLOSED);

    window.id     = Window.INVALID_ID;
    window.handle = null;

    old := Atomics.atomic_add(*context.pet.core.window_manager.active_windows.count, -1);
    assert(old > 0);
}

applyInitialDPIScalingToWindow :: (window_handle : HWND, rect_resolution : Resolution) -> f32 {
    assert(rect_resolution.width  && rect_resolution.width  != Window.OS_DEFAULT_SIZE);
    assert(rect_resolution.height && rect_resolution.height != Window.OS_DEFAULT_SIZE);

    monitor_dpi := cast(f32) GetDpiForWindow(window_handle);
    DEFAULT_DPI :: 96.0;
    dpi_scale   := monitor_dpi / DEFAULT_DPI;

    scaled_width  := cast(u16) Math.ceil(rect_resolution.width  * dpi_scale);
    scaled_height := cast(u16) Math.ceil(rect_resolution.height * dpi_scale);

    SET_WINDOW_POS_FLAGS :: SWP_NOMOVE
                          | SWP_NOZORDER
                          | SWP_NOREDRAW
                          | SWP_NOACTIVATE
                          | SWP_NOCOPYBITS
                          | SWP_NOOWNERZORDER
                          | SWP_NOSENDCHANGING
                          | SWP_DEFERERASE
                          | SWP_ASYNCWINDOWPOS;

    debugCheck(SetWindowPos(window_handle, HWND_TOP, 0, 0, scaled_width, scaled_height, SET_WINDOW_POS_FLAGS), print_sys_error = true);

    return dpi_scale;
}

useDarkTheme :: () -> bool {
    SUBKEY       :: "Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
    utf16_subkey : [SUBKEY.count + 1] WCHAR = ---;
    ASCIIToUTF16(*utf16_subkey, SUBKEY);

    VALUE       :: "AppsUseLightTheme";
    utf16_value : [VALUE.count + 1] WCHAR = ---;
    ASCIIToUTF16(*utf16_value, VALUE);

    apps_use_light_theme : u32;
    data_size            : u32 = size_of(u32);

    status := RegGetValueW(HKEY_CURRENT_USER, utf16_subkey.data, utf16_value.data, RRF_RT_REG_DWORD, null, *apps_use_light_theme, *data_size);
    if status == {
        case ERROR_SUCCESS;
            return !apps_use_light_theme;

        case ERROR_FILE_NOT_FOUND;
            warningMessage("\"HKEY_CURRENT_USER\\%\\%\" reg value is not found. Fallback to Windows default theme", SUBKEY, VALUE);

        case;
            assert(false, "RegGetValueW has failed", print_sys_error = true, cast,no_check(u32) status);
    }

    return false;;
}

applyWindowTheme :: (window_handle : HWND) {
    manager := cast(*Win32WindowManager) context.pet.core.window_manager;

    use_dark_theme := cast(BOOL) manager.use_dark_theme;
    debugCheckHRESULT(DwmSetWindowAttribute(window_handle, .DWMWA_USE_IMMERSIVE_DARK_MODE, *use_dark_theme, size_of(BOOL)));
}

checkWindowThemeChange :: (window_handle : HWND, wparam : WPARAM, lparam : LPARAM) {
    // Ignore computer policy
    if wparam != 0 return;

    if lparam {
        utf16_setting_name        := cast(LPCWSTR) lparam;
        utf16_immersive_color_set := cast(LPCWSTR) "I\0m\0m\0e\0r\0s\0i\0v\0e\0C\0o\0l\0o\0r\0S\0e\0t\0\0\0".data; // ImmersiveColorSet

        if ntStringCompare(utf16_setting_name, utf16_immersive_color_set) {
            return;
        }
    }

    manager := cast(*Win32WindowManager) context.pet.core.window_manager;

    was_using_dark_theme   := manager.use_dark_theme;
    manager.use_dark_theme  = useDarkTheme();

    if was_using_dark_theme != manager.use_dark_theme {
        applyWindowTheme(window_handle);
    }
}

Math :: #import "Math";
