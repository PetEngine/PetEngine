#assert OS == .WINDOWS "This file should not be used anywhere except Windows builds";

// @TODO: #Input
//    1. In a multimonitor system, MOUSE.MOVE_ABSOLUTE coordinates map to the primary monitor
//    2. MOUSE.VIRTUAL_DESKTOP

setupInitialInputState :: (window : *Win32Window) {
    // Not all virtual key states report correct state of the keys, so we don't check them at all.
    // We only care about CAPS_LOCK, NUM_LOCK and SCROLL_LOCK toggle state.

    window.input.keyboard[Input.Key.CAPS_LOCK]   |= .ON * cast(Input.KeyState) (GetKeyState(cast(s32) VK.CAPITAL) & 1);
    window.input.keyboard[Input.Key.NUM_LOCK]    |= .ON * cast(Input.KeyState) (GetKeyState(cast(s32) VK.NUMLOCK) & 1);
    window.input.keyboard[Input.Key.SCROLL_LOCK] |= .ON * cast(Input.KeyState) (GetKeyState(cast(s32) VK.SCROLL)  & 1);

    calcInitialMousePosition(window);
}

registerRawInput :: (window : *Win32Window) {
    assert(window, "Input sink is not supported");

    #if PRINT_VERBOSE_MESSAGES then NOTIFY_FLAG : RIDEV : .DEVNOTIFY;
                               else NOTIFY_FLAG : RIDEV : 0;

    raw_input_devices := RAWINPUTDEVICE.[
        .{
            usUsagePage = .GENERIC,
            usUsage     = .GENERIC_KEYBOARD,
            dwFlags     = NOTIFY_FLAG,
            hwndTarget  = window.handle,
        },
        .{
            usUsagePage = .GENERIC,
            usUsage     = .GENERIC_MOUSE,
            dwFlags     = NOTIFY_FLAG,
            hwndTarget  = window.handle,
        },
    ];

    debugCheck(RegisterRawInputDevices(raw_input_devices.data, raw_input_devices.count, size_of(RAWINPUTDEVICE)),
               print_sys_error = true);
}

loadXInput :: () {
    if g_XInput return;

    g_XInput = LoadLibraryA(cast(*s8) "XInput1_4.dll\0".data);
    assert(g_XInput, print_sys_error = true);

    g_XInputGetState = cast(PFN_XInputGetState) GetProcAddress(g_XInput, cast(*s8) "XInputGetState\0".data);
    assert(g_XInputGetState, print_sys_error = true);
}

unloadXInput :: () {
    if !g_XInput return;

    debugCheck(FreeLibrary(g_XInput), print_sys_error = true);
    g_XInput = null;
}

onRawInputDeviceChange :: (ri_device : HANDLE, wparam : WPARAM) {
    #if PRINT_VERBOSE_MESSAGES {
DEVICE_CONNECTED_MESSAGE :: #string END
Input device is connected:
    Handle:       0x%
    Device name:  %
    Manufacturer: %
    Product name: %
END;

DEVICE_DISCONNECTED_MESSAGE :: #string END
Input device is disconnected:
    Handle: 0x%
END;

        if GET_DEVICE_CHANGE_WPARAM(wparam) == {
            case GIDC_ARRIVAL;
                device_name, manufacturer, product := getRawInputDeviceNames(ri_device);
                verboseMessage(DEVICE_CONNECTED_MESSAGE, ri_device, device_name, manufacturer, product, new_line = false);

            case GIDC_REMOVAL;
                verboseMessage(DEVICE_DISCONNECTED_MESSAGE, ri_device, new_line = false);
        }
    }
}

processRawInput :: (window : *Win32Window) {
    data_buffer : [1024 / size_of(RAWINPUT)] RAWINPUT #align size_of(*void);

    while true {
        data_size : u32 = data_buffer.count * size_of(RAWINPUT);
        data_count := GetRawInputBuffer(data_buffer.data, *data_size, size_of(RAWINPUTHEADER));
        assert(data_count != 0xFFFF_FFFF, print_sys_error = true);

        if !data_count break;

        raw_input_it := data_buffer.data;
        while data_count {
            assert(GET_RAWINPUT_CODE_WPARAM(raw_input_it.header.wParam) == RIM_INPUT,
                   "Input sink is not supported");

            if raw_input_it.header.dwType == {
                case .TYPEMOUSE;    processMouseRawInput(window, *raw_input_it.data.mouse);
                case .TYPEKEYBOARD; processKeyboardRawInput(window, *raw_input_it.data.keyboard);
                case;               warningMessage("Unhandled raw input type: %", raw_input_it.header.dwType);
            }

            raw_input_it  = NEXTRAWINPUTBLOCK(raw_input_it);
            data_count   -= 1;
        }
    }
}

onRawInput :: (window : *Win32Window, ri_handle : HRAWINPUT) {
    raw_input_size : u32;
    ri_result := GetRawInputData(ri_handle, RID_INPUT, null, *raw_input_size, size_of(RAWINPUTHEADER));
    assert(ri_result == 0, print_sys_error = true);
    assert(raw_input_size <= size_of(RAWINPUT), "Expected raw_input_size <= %, got %", size_of(RAWINPUT), raw_input_size);

    raw_input : RAWINPUT = ---;
    ri_result = GetRawInputData(ri_handle, RID_INPUT, *raw_input, *raw_input_size, size_of(RAWINPUTHEADER));
    assert(ri_result == raw_input_size, print_sys_error = true);

    assert(GET_RAWINPUT_CODE_WPARAM(raw_input.header.wParam) == RIM_INPUT,
           "Input sink is not supported");

    if raw_input.header.dwType == {
        case .TYPEMOUSE;    processMouseRawInput(window, *raw_input.data.mouse);
        case .TYPEKEYBOARD; processKeyboardRawInput(window, *raw_input.data.keyboard);
        case;               warningMessage("Unhandled raw input type: %", raw_input.header.dwType);
    }
}

processXInput :: (input : *Input) {
    state : XINPUT_STATE = ---;

    for * input.gamepads {
        result := g_XInputGetState(cast(u32) it_index, *state);
        assert(result == ERROR_SUCCESS || result == ERROR_DEVICE_NOT_CONNECTED,
               "XInputGetState returned %",
               result,
               print_sys_error = true);

        if result == ERROR_DEVICE_NOT_CONNECTED {
            if it.connected {
                infoMessage("Gamepad #% has been disconnected", it_index);
                it.connected = false;
            }
            continue;
        }

        if !it.connected {
            infoMessage("Gamepad #% has been connected", it_index);
            it.connected = true;
        }

        it.button_a           = getNewDigitalButtonState(it.button_a,           cast(bool) (state.Gamepad.wButtons & XINPUT_GAMEPAD_A));
        it.button_b           = getNewDigitalButtonState(it.button_b,           cast(bool) (state.Gamepad.wButtons & XINPUT_GAMEPAD_B));
        it.button_x           = getNewDigitalButtonState(it.button_x,           cast(bool) (state.Gamepad.wButtons & XINPUT_GAMEPAD_X));
        it.button_y           = getNewDigitalButtonState(it.button_y,           cast(bool) (state.Gamepad.wButtons & XINPUT_GAMEPAD_Y));
        it.left_shoulder      = getNewDigitalButtonState(it.left_shoulder,      cast(bool) (state.Gamepad.wButtons & XINPUT_GAMEPAD_LEFT_SHOULDER));
        it.right_shoulder     = getNewDigitalButtonState(it.right_shoulder,     cast(bool) (state.Gamepad.wButtons & XINPUT_GAMEPAD_RIGHT_SHOULDER));
        it.start              = getNewDigitalButtonState(it.start,              cast(bool) (state.Gamepad.wButtons & XINPUT_GAMEPAD_START));
        it.back               = getNewDigitalButtonState(it.back,               cast(bool) (state.Gamepad.wButtons & XINPUT_GAMEPAD_BACK));
        it.dpad_up            = getNewDigitalButtonState(it.dpad_up,            cast(bool) (state.Gamepad.wButtons & XINPUT_GAMEPAD_DPAD_UP));
        it.dpad_down          = getNewDigitalButtonState(it.dpad_down,          cast(bool) (state.Gamepad.wButtons & XINPUT_GAMEPAD_DPAD_DOWN));
        it.dpad_left          = getNewDigitalButtonState(it.dpad_left,          cast(bool) (state.Gamepad.wButtons & XINPUT_GAMEPAD_DPAD_LEFT));
        it.dpad_right         = getNewDigitalButtonState(it.dpad_right,         cast(bool) (state.Gamepad.wButtons & XINPUT_GAMEPAD_DPAD_RIGHT));
        it.left_thumb.button  = getNewDigitalButtonState(it.left_thumb.button,  cast(bool) (state.Gamepad.wButtons & XINPUT_GAMEPAD_LEFT_THUMB));
        it.right_thumb.button = getNewDigitalButtonState(it.right_thumb.button, cast(bool) (state.Gamepad.wButtons & XINPUT_GAMEPAD_RIGHT_THUMB));

        // [0; 255] -> [0; 1]
        adaptTrigger :: inline (value : u8) -> f32 #no_context {
            if value > XINPUT_GAMEPAD_TRIGGER_THRESHOLD return value / 255.0;
            return 0.0;
        }

        it.left_trigger  = adaptTrigger(state.Gamepad.bLeftTrigger);
        it.right_trigger = adaptTrigger(state.Gamepad.bRightTrigger);

        // [-32768; 32767] -> [-1; 1]
        adaptOffset :: inline (value : s16, $deadzone : s16) -> f32 #no_context {
            if value < -deadzone return value / 32768.0;
            if value >  deadzone return value / 32767.0;
            return 0.0;
        }

        it.left_thumb.x  = adaptOffset(state.Gamepad.sThumbLX, XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE);
        it.left_thumb.y  = adaptOffset(state.Gamepad.sThumbLY, XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE);
        it.right_thumb.x = adaptOffset(state.Gamepad.sThumbRX, XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE);
        it.right_thumb.y = adaptOffset(state.Gamepad.sThumbRY, XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE);
    }
}

#scope_file

g_XInput         : HMODULE;
g_XInputGetState : PFN_XInputGetState;

calcInitialMousePosition :: (window : *Win32Window) {
    mouse_position : POINT = ---;
    debugCheck(GetCursorPos(*mouse_position), print_sys_error = true);

    window.input.mouse.screen_x = cast,trunc(s16) mouse_position.x;
    window.input.mouse.screen_y = cast,trunc(s16) mouse_position.y;
}

getRawInputDeviceNames :: (ri_device : HANDLE) -> (device_name : string, manufacturer : string, product_name : string) {
    device_wide_name   : [MAX_PATH] WCHAR;
    device_name_length : u32 = device_wide_name.count;

    ri_result := GetRawInputDeviceInfoW(ri_device, RIDI_DEVICENAME, device_wide_name.data, *device_name_length);
    assert(ri_result && ri_result != 0xFFFF_FFFF, print_sys_error = true);

    if ri_result < device_name_length then device_name_length = ri_result;
    device_name := wideToAscii(device_wide_name.data, device_name_length, pushToArena, *context.pet.per_frame_arena);

    manufacturer : string;
    product_name : string;

    hid_device := CreateFileW(device_wide_name.data,
                              FILE_GENERIC_READ & ~FILE_READ_DATA,
                              FILE_SHARE_READ | FILE_SHARE_WRITE,
                              null,
                              OPEN_EXISTING,
                              FILE_ATTRIBUTE_DEVICE,
                              null);

    if hid_device != INVALID_HANDLE_VALUE {
        // https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/hidsdi/nf-hidsdi-hidd_getmanufacturerstring
        manufacturer_wide_name : [((1 << 12) - 3) / size_of(WCHAR)] WCHAR;

        if HidD_GetManufacturerString(hid_device, manufacturer_wide_name.data, manufacturer_wide_name.count * size_of(WCHAR)) {
            manufacturer = wideToAscii(manufacturer_wide_name.data, wideLength(manufacturer_wide_name), pushToArena, *context.pet.per_frame_arena);
        } else {
            // It seems like when manufacture string does not exist, HID returns ERROR_INVALID_USER_BUFFER
            assert(GetLastError() == ERROR_INVALID_USER_BUFFER, print_sys_error = true);
        }

        // https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/hidsdi/nf-hidsdi-hidd_getproductstring
        product_wide_name : [((1 << 12) - 3) / size_of(WCHAR)] WCHAR;

        if HidD_GetProductString(hid_device, product_wide_name.data, product_wide_name.count * size_of(WCHAR)) {
            product_name = wideToAscii(product_wide_name.data, wideLength(product_wide_name), pushToArena, *context.pet.per_frame_arena);
        } else {
            // It seems like when product string does not exist, HID returns ERROR_INVALID_USER_BUFFER
            assert(GetLastError() == ERROR_INVALID_USER_BUFFER, print_sys_error = true);
        }

        debugCheck(CloseHandle(hid_device), print_sys_error = true);
    } else {
        // Sometimes device names are human readable (does not contain PID, VID, GUID, ...), so CreateFileW cannot find them
        assert(GetLastError() == ERROR_PATH_NOT_FOUND, print_sys_error = true);
    }

    return device_name, manufacturer, product_name;
}

processMouseRawInput :: (window : *Win32Window, raw_mouse : *RAWMOUSE) {
    /**/ if raw_mouse.usButtonFlags & .BUTTON_1_DOWN then window.input.mouse.button_1 = getNewKeyState(window.input.mouse.button_1, true);
    else if raw_mouse.usButtonFlags & .BUTTON_1_UP   then window.input.mouse.button_1 = getNewKeyState(window.input.mouse.button_1, false);
    /**/ if raw_mouse.usButtonFlags & .BUTTON_2_DOWN then window.input.mouse.button_2 = getNewKeyState(window.input.mouse.button_2, true);
    else if raw_mouse.usButtonFlags & .BUTTON_2_UP   then window.input.mouse.button_2 = getNewKeyState(window.input.mouse.button_2, false);
    /**/ if raw_mouse.usButtonFlags & .BUTTON_3_DOWN then window.input.mouse.button_3 = getNewKeyState(window.input.mouse.button_3, true);
    else if raw_mouse.usButtonFlags & .BUTTON_3_UP   then window.input.mouse.button_3 = getNewKeyState(window.input.mouse.button_3, false);
    /**/ if raw_mouse.usButtonFlags & .BUTTON_4_DOWN then window.input.mouse.button_4 = getNewKeyState(window.input.mouse.button_4, true);
    else if raw_mouse.usButtonFlags & .BUTTON_4_UP   then window.input.mouse.button_4 = getNewKeyState(window.input.mouse.button_4, false);
    /**/ if raw_mouse.usButtonFlags & .BUTTON_5_DOWN then window.input.mouse.button_5 = getNewKeyState(window.input.mouse.button_5, true);
    else if raw_mouse.usButtonFlags & .BUTTON_5_UP   then window.input.mouse.button_5 = getNewKeyState(window.input.mouse.button_5, false);

    /**/ if raw_mouse.usButtonFlags & .WHEEL  then window.input.mouse.dwheel            = cast(s16) (cast,trunc(s16) raw_mouse.usButtonData / cast(float) WHEEL_DELTA);
    else if raw_mouse.usButtonFlags & .HWHEEL then window.input.mouse.dwheel_horizontal = cast(s16) (cast,trunc(s16) raw_mouse.usButtonData / cast(float) WHEEL_DELTA);

    if raw_mouse.usFlags & .MOVE_ABSOLUTE {
        assert(!(raw_mouse.usFlags & .VIRTUAL_DESKTOP), "Virtual desktops are not supported for mosue input yet");

        window.input.mouse.dx = cast(s16) raw_mouse.lLastX - window.input.mouse.screen_x;
        window.input.mouse.dy = cast(s16) raw_mouse.lLastY - window.input.mouse.screen_y;

        window.input.mouse.screen_x = cast(s16) raw_mouse.lLastX;
        window.input.mouse.screen_y = cast(s16) raw_mouse.lLastY;
    } else if raw_mouse.lLastX || raw_mouse.lLastY {
        window.input.mouse.dx = cast(s16) raw_mouse.lLastX;
        window.input.mouse.dy = cast(s16) raw_mouse.lLastY;

        window.input.mouse.screen_x += window.input.mouse.dx;
        window.input.mouse.screen_y += window.input.mouse.dy;

        window.input.mouse.screen_x = clamp(window.input.mouse.screen_x, 0, cast(s16) window.screen.width);
        window.input.mouse.screen_y = clamp(window.input.mouse.screen_y, 0, cast(s16) window.screen.height);
    }
}

processKeyboardRawInput :: (window : *Win32Window, raw_keyboard : *RAWKEYBOARD) {
    if window.platform_flags & .HANDLING_KEY_PAUSE {
        assert(raw_keyboard.MakeCode == 0x0045 && !(raw_keyboard.Flags & (.KEY_E0 | .KEY_E1)));
        window.platform_flags &= ~.HANDLING_KEY_PAUSE;
        return;
    }

    key       := makeCodeToKey(raw_keyboard.MakeCode, raw_keyboard.Flags, (window.input.keyboard[Input.Key.NUM_LOCK] & .ON) != 0);
    key_state := *window.input.keyboard[key];

    if raw_keyboard.Flags & .KEY_BREAK {
        key_state.* = getNewKeyState(key_state.*, false);
    } else {
        key_state.* = getNewKeyState(key_state.*, true);

        if key == .CAPS_LOCK || key == .NUM_LOCK || key == .SCROLL_LOCK {
            if key_state.* & .PRESSED {
                key_state.* ^= .ON;
            }
        }
    }

    if key == .PAUSE {
        window.platform_flags |= .HANDLING_KEY_PAUSE;
    }
}

makeCodeToKey :: (make_code : u16, flags : RI, num_lock_is_on : bool) -> Input.Key {
    key : Input.Key = .UNDEFINED;

    if make_code >= KEYBOARD_OVERRUN_MAKE_CODE {
       warningMessage("[Input] Invalid or unrecognizable combination of keys is pressed or the number of keys pressed exceeds the limit for this keyboard");
       return key;
    }

    if flags & .KEY_E0 {
        assert(!(flags & .KEY_E1));
        make_code |= 0xE000;
    } else if flags & .KEY_E1 {
        make_code |= 0xE100;
    }

    if make_code == {
        case 0x000E; key = .BACKSPACE;
        case 0x000F; key = .TAB;

        case 0x001C; key = .ENTER;
        case 0x0001; key = .ESCAPE;
        case 0x0039; key = .SPACE;

        case 0x003A; key = .CAPS_LOCK;
        case 0x0045; key = .NUM_LOCK;
        case 0x0046; key = .SCROLL_LOCK;

        case 0xE049; key = .PAGE_UP;
        case 0xE051; key = .PAGE_DOWN;
        case 0xE04F; key = .END;
        case 0xE047; key = .HOME;
        case 0xE052; key = .INSERT;
        case 0xE053; key = .DELETE;

        case 0xE04B; key = .LEFT;
        case 0xE048; key = .UP;
        case 0xE04D; key = .RIGHT;
        case 0xE050; key = .DOWN;

        case 0x0052; key = ifx num_lock_is_on then .NUM_0 else .INSERT;
        case 0x004F; key = ifx num_lock_is_on then .NUM_1 else .END;
        case 0x0050; key = ifx num_lock_is_on then .NUM_2 else .DOWN;
        case 0x0051; key = ifx num_lock_is_on then .NUM_3 else .PAGE_DOWN;
        case 0x004B; key = ifx num_lock_is_on then .NUM_4 else .LEFT;
        case 0x004C; key = ifx num_lock_is_on then .NUM_5 else .UNDEFINED;
        case 0x004D; key = ifx num_lock_is_on then .NUM_6 else .RIGHT;
        case 0x0047; key = ifx num_lock_is_on then .NUM_7 else .HOME;
        case 0x0048; key = ifx num_lock_is_on then .NUM_8 else .UP;
        case 0x0049; key = ifx num_lock_is_on then .NUM_9 else .PAGE_UP;
        case 0xE035; key = .NUM_DIV;
        case 0x0037; key = .NUM_MUL;
        case 0x004A; key = .NUM_SUB;
        case 0x004E; key = .NUM_ADD;
        case 0xE01C; key = .NUM_ENTER;
        case 0x0053; key = ifx num_lock_is_on then .NUM_DOT else .DELETE;

        case 0x003B; key = .F1;
        case 0x003C; key = .F2;
        case 0x003D; key = .F3;
        case 0x003E; key = .F4;
        case 0x003F; key = .F5;
        case 0x0040; key = .F6;
        case 0x0041; key = .F7;
        case 0x0042; key = .F8;
        case 0x0043; key = .F9;
        case 0x0044; key = .F10;
        case 0x0057; key = .F11;
        case 0x0058; key = .F12;
        case 0x0064; key = .F13;
        case 0x0065; key = .F14;
        case 0x0066; key = .F15;
        case 0x0067; key = .F16;
        case 0x0068; key = .F17;
        case 0x0069; key = .F18;
        case 0x006A; key = .F19;
        case 0x006B; key = .F20;
        case 0x006C; key = .F21;
        case 0x006D; key = .F22;
        case 0x006E; key = .F23;
        case 0x0076; key = .F24;

        case 0x0002; key = .KEY_1;
        case 0x0003; key = .KEY_2;
        case 0x0004; key = .KEY_3;
        case 0x0005; key = .KEY_4;
        case 0x0006; key = .KEY_5;
        case 0x0007; key = .KEY_6;
        case 0x0008; key = .KEY_7;
        case 0x0009; key = .KEY_8;
        case 0x000A; key = .KEY_9;
        case 0x000B; key = .KEY_0;

        case 0x001E; key = .A;
        case 0x0030; key = .B;
        case 0x002E; key = .C;
        case 0x0020; key = .D;
        case 0x0012; key = .E;
        case 0x0021; key = .F;
        case 0x0022; key = .G;
        case 0x0023; key = .H;
        case 0x0017; key = .I;
        case 0x0024; key = .J;
        case 0x0025; key = .K;
        case 0x0026; key = .L;
        case 0x0032; key = .M;
        case 0x0031; key = .N;
        case 0x0018; key = .O;
        case 0x0019; key = .P;
        case 0x0010; key = .Q;
        case 0x0013; key = .R;
        case 0x001F; key = .S;
        case 0x0014; key = .T;
        case 0x0016; key = .U;
        case 0x002F; key = .V;
        case 0x0011; key = .W;
        case 0x002D; key = .X;
        case 0x0015; key = .Y;
        case 0x002C; key = .Z;

        case 0x002A; key = .LEFT_SHIFT;
        case 0x0036; key = .RIGHT_SHIFT;
        case 0x001D; key = .LEFT_CTRL;
        case 0xE01D; key = .RIGHT_CTRL;
        case 0x0038; key = .LEFT_ALT;
        case 0xE038; key = .RIGHT_ALT;
        case 0xE05B; key = .LEFT_WIN;
        case 0xE05C; key = .RIGHT_WIN;
        case 0xE05D; key = .CONTEXT_MENU;

        case 0x0033; key = .COMMA;
        case 0x0034; key = .DOT;
        case 0x0035; key = .SLASH;
        case 0x0027; key = .SEMICOLON;
        case 0x0028; key = .APOSTROPHE;
        case 0x002B; key = .BACK_SLASH;
        case 0x001A; key = .LEFT_BRACKET;
        case 0x001B; key = .RIGHT_BRACKET;
        case 0x000C; key = .DASH;
        case 0x000D; key = .EQUALS;
        case 0x0029; key = .TILDE;

        case 0xE020; key = .VOLUME_MUTE;
        case 0xE02E; key = .VOLUME_DOWN;
        case 0xE030; key = .VOLUME_UP;

        case 0xE010; key = .MEDIA_PREV;
        case 0xE019; key = .MEDIA_NEXT;
        case 0xE022; key = .MEDIA_PLAY_PAUSE;
        case 0xE024; key = .MEDIA_STOP;

        case 0x0056; key = .OEM_102;

        case 0xE037; key = .PRINT_SCREEN;
        case 0xE046; key = .BREAK;
        case 0xE11D; key = .PAUSE;
    }

    return key;
}
