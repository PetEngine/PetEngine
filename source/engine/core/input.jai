// @TODO: #Input.
//     1. Multiple gamepad support.
//     2. Move platform stuff to a platform file.
//     3. @Continue: Fill key codes

Input :: struct {
    MAX_KEYS :: 256;

    keyboard : [MAX_KEYS] KeyState;
    mouse    : Mouse;
}

KeyState :: enum_flags u8 {
    UP;
    DOWN;
    RELEASED;
    PRESSED;
}

Mouse :: struct {
    x  : s16;
    y  : s16;

    dx : s16;
    dy : s16;

    wheel : s16;

    button_left   : KeyState;
    button_right  : KeyState;
    button_middle : KeyState;
    button_4      : KeyState;
    button_5      : KeyState;
}

createInput :: (window : *Window) -> Input {
    input : Input;

    #if OS == .WINDOWS {
        createRawInput(cast(*Win32Window) window);
    } else {
        notImplemented();
    }

    return input;
}

destroyInput :: (input : *Input) {
}

#if OS == .WINDOWS {
onRawInputDeviceChange :: (ri_device : HANDLE, wparam : WPARAM) {
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
            debugMessage(DEVICE_CONNECTED_MESSAGE, ri_device, device_name, manufacturer, product, new_line = false);

        case GIDC_REMOVAL;
            debugMessage(DEVICE_DISCONNECTED_MESSAGE, ri_device, new_line = false);
    }
}

processRawInput :: () {
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

            assert(raw_input_it.header.dwType == RIM_TYPEMOUSE || raw_input_it.header.dwType == RIM_TYPEKEYBOARD,
                   "Raw input from mouse and keyboard is supported only");

            if raw_input_it.header.dwType == {
                case RIM_TYPEMOUSE;    processMouseRawInput(*raw_input_it.data.mouse);
                case RIM_TYPEKEYBOARD; processKeyboardRawInput(*raw_input_it.data.keyboard);
            }

            raw_input_it  = NEXTRAWINPUTBLOCK(raw_input_it);
            data_count   -= 1;
        }
    }
}

onRawInput :: (ri_handle : HRAWINPUT) {
    ri_header_size : u32;
    ri_result := GetRawInputData(ri_handle, RID_HEADER, null, *ri_header_size, size_of(RAWINPUTHEADER));
    assert(ri_result == 0, print_sys_error = true);
    assert(ri_header_size == size_of(RAWINPUTHEADER), "Expected ri_header_size == %, got %", size_of(RAWINPUTHEADER), ri_header_size);

    ri_header : RAWINPUTHEADER = ---;
    ri_result = GetRawInputData(ri_handle, RID_HEADER, *ri_header, *ri_header_size, size_of(RAWINPUTHEADER));
    assert(ri_result && ri_result != 0xFFFF_FFFF, print_sys_error = true);

    assert(GET_RAWINPUT_CODE_WPARAM(ri_header.wParam) == RIM_INPUT,
           "Input sink is not supported");

    assert(ri_header.dwType == RIM_TYPEMOUSE || ri_header.dwType == RIM_TYPEKEYBOARD,
           "Raw input from mouse and keyboard is supported only");

    raw_input_size : u32;
    ri_result = GetRawInputData(ri_handle, RID_INPUT, null, *raw_input_size, size_of(RAWINPUTHEADER));
    assert(ri_result == 0, print_sys_error = true);
    assert(raw_input_size <= size_of(RAWINPUT), "Expected raw_input_size <= %, got %", size_of(RAWINPUT), raw_input_size);

    raw_input : RAWINPUT = ---;
    ri_result = GetRawInputData(ri_handle, RID_INPUT, *raw_input, *raw_input_size, size_of(RAWINPUTHEADER));
    assert(ri_result == raw_input_size, print_sys_error = true);

    assert(GET_RAWINPUT_CODE_WPARAM(raw_input.header.wParam) == RIM_INPUT,
           "Input sink is not supported");

    assert(raw_input.header.dwType == RIM_TYPEMOUSE || raw_input.header.dwType == RIM_TYPEKEYBOARD,
           "Raw input from mouse and keyboard is supported only");

    if raw_input.header.dwType == {
        case RIM_TYPEMOUSE;    processMouseRawInput(*raw_input.data.mouse);
        case RIM_TYPEKEYBOARD; processKeyboardRawInput(*raw_input.data.keyboard);
    }
}

KeyCode :: enum u8 #specified {
    BACKSPACE :: 0x08;
    TAB       :: 0x09;

    SHIFT   :: 0x10;
    CONTROL :: 0x11;
    ALT     :: 0x12;

    RETURN :: 0x0D;
    ESCAPE :: 0x1B;
    SPACE  :: 0x20;

    CAPS_LOCK :: 0x14;

    PAGE_UP   :: 0x21;
    PAGE_DOWN :: 0x22;
    END       :: 0x23;
    HOME      :: 0x24;
    INSERT    :: 0x2D;
    DELETE    :: 0x2E;

    LEFT  :: 0x25;
    UP    :: 0x26;
    RIGHT :: 0x27;
    DOWN  :: 0x28;

    NUM_LOCK      :: 0x90;
    NUM_0         :: 0x60;
    NUM_1         :: 0x61;
    NUM_2         :: 0x62;
    NUM_3         :: 0x63;
    NUM_4         :: 0x64;
    NUM_5         :: 0x65;
    NUM_6         :: 0x66;
    NUM_7         :: 0x67;
    NUM_8         :: 0x68;
    NUM_9         :: 0x69;
    NUM_EQUALS    :: 0x92;
    NUM_MUL       :: 0x6A;
    NUM_ADD       :: 0x6B;
    NUM_SEPARATOR :: 0x6C;
    NUM_SUB       :: 0x6D;
    NUM_DOT       :: 0x6E;
    NUM_DIV       :: 0x6F;
    NUM_RETURN    :: RETURN;

    F1  :: 0x70;
    F2  :: 0x71;
    F3  :: 0x72;
    F4  :: 0x73;
    F5  :: 0x74;
    F6  :: 0x75;
    F7  :: 0x76;
    F8  :: 0x77;
    F9  :: 0x78;
    F10 :: 0x79;
    F11 :: 0x7A;
    F12 :: 0x7B;
    F13 :: 0x7C;
    F14 :: 0x7D;
    F15 :: 0x7E;
    F16 :: 0x7F;
    F17 :: 0x80;
    F18 :: 0x81;
    F19 :: 0x82;
    F20 :: 0x83;
    F21 :: 0x84;
    F22 :: 0x85;
    F23 :: 0x86;
    F24 :: 0x87;

    KEY_0 :: 0x30;
    KEY_1 :: 0x31;
    KEY_2 :: 0x32;
    KEY_3 :: 0x33;
    KEY_4 :: 0x34;
    KEY_5 :: 0x35;
    KEY_6 :: 0x36;
    KEY_7 :: 0x37;
    KEY_8 :: 0x38;
    KEY_9 :: 0x39;

    A :: 0x41;
    B :: 0x42;
    C :: 0x43;
    D :: 0x44;
    E :: 0x45;
    F :: 0x46;
    G :: 0x47;
    H :: 0x48;
    I :: 0x49;
    J :: 0x4A;
    K :: 0x4B;
    L :: 0x4C;
    M :: 0x4D;
    N :: 0x4E;
    O :: 0x4F;
    P :: 0x50;
    Q :: 0x51;
    R :: 0x52;
    S :: 0x53;
    T :: 0x54;
    U :: 0x55;
    V :: 0x56;
    W :: 0x57;
    X :: 0x58;
    Y :: 0x59;
    Z :: 0x5A;

    LEFT_SHIFT    :: 0xA0;
    RIGHT_SHIFT   :: 0xA1;
    LEFT_CONTROL  :: 0xA2;
    RIGHT_CONTROL :: 0xA3;
    LEFT_ALT      :: 0xA4;
    RIGHT_ALT     :: 0xA5;
    LEFT_WIN      :: 0x5B;
    RIGHT_WIN     :: 0x5C;

    COMMA         :: 0xBC;
    DOT           :: 0xBE;
    SLASH         :: 0xBF;
    SEMICOLON     :: 0xBA;
    APOSTROPHE    :: 0xDE;
    BACK_SLASH    :: 0xDC;
    LEFT_BRACKET  :: 0xDB;
    RIGHT_BRACKET :: 0xDD;
    MINUS         :: 0xBD;
    EQUALS        :: 0xBB;
    TILDE         :: 0xC0;

    VOLUME_MUTE :: 0xAD;
    VOLUME_DOWN :: 0xAE;
    VOLUME_UP   :: 0xAF;

    MEDIA_NEXT       :: 0xB0;
    MEDIA_PREV       :: 0xB1;
    MEDIA_STOP       :: 0xB2;
    MEDIA_PLAY_PAUSE :: 0xB3;

    OEM_AX  :: 0xE1; // 'AX' key on Japanese AX kbd
    OEM_102 :: 0xE2; // "<>" or "\|" on RT 102-key kbd
}
}

#scope_file

#if OS == .WINDOWS {
createRawInput :: (window : *Win32Window) {
    #if DEBUG_BUILD then NOTIFY_FLAG :: RIDEV_DEVNOTIFY;
                    else NOTIFY_FLAG :: 0;

    raw_input_devices := RAWINPUTDEVICE.[
        .{
            usUsagePage = HID_USAGE_PAGE_GENERIC,
            usUsage     = HID_USAGE_GENERIC_KEYBOARD,
            dwFlags     = NOTIFY_FLAG,
            hwndTarget  = window.handle,
        },
        .{
            usUsagePage = HID_USAGE_PAGE_GENERIC,
            usUsage     = HID_USAGE_GENERIC_MOUSE,
            dwFlags     = NOTIFY_FLAG,
            hwndTarget  = window.handle,
        },
    ];

    debugCheck(RegisterRawInputDevices(raw_input_devices.data, raw_input_devices.count, size_of(RAWINPUTDEVICE)),
               print_sys_error = true);
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

processMouseRawInput :: (raw_mouse : *RAWMOUSE) {
    if raw_mouse.usButtonFlags & RI_MOUSE_BUTTON_1_DOWN infoMessage("[Input] LMB is pressed");
    if raw_mouse.usButtonFlags & RI_MOUSE_BUTTON_2_DOWN infoMessage("[Input] RMB is pressed");
    if raw_mouse.usButtonFlags & RI_MOUSE_BUTTON_3_DOWN infoMessage("[Input] MMB is pressed");
    if raw_mouse.usButtonFlags & RI_MOUSE_BUTTON_4_DOWN infoMessage("[Input] Button 4 is pressed");
    if raw_mouse.usButtonFlags & RI_MOUSE_BUTTON_5_DOWN infoMessage("[Input] Button 5 is pressed");

    if raw_mouse.usButtonFlags & RI_MOUSE_BUTTON_1_UP infoMessage("[Input] LMB is released");
    if raw_mouse.usButtonFlags & RI_MOUSE_BUTTON_2_UP infoMessage("[Input] RMB is released");
    if raw_mouse.usButtonFlags & RI_MOUSE_BUTTON_3_UP infoMessage("[Input] MMB is released");
    if raw_mouse.usButtonFlags & RI_MOUSE_BUTTON_4_UP infoMessage("[Input] Button 4 is released");
    if raw_mouse.usButtonFlags & RI_MOUSE_BUTTON_5_UP infoMessage("[Input] Button 5 is released");

    if raw_mouse.usButtonFlags & RI_MOUSE_WHEEL infoMessage("[Input] Wheel delta = %", cast,trunc(s16) raw_mouse.usButtonData / cast(float) WHEEL_DELTA);

    // /**/ if raw_mouse.usFlags & MOUSE_MOVE_ABSOLUTE infoMessage("[Input] Mouse UV is [%, %]", raw_mouse.lLastX / 65535.0, raw_mouse.lLastY / 65535.0);
    // else if raw_mouse.lLastX || raw_mouse.lLastY    infoMessage("[Input] Mosue delta is [%, %]", raw_mouse.lLastX, raw_mouse.lLastY);
}

processKeyboardRawInput :: (raw_keyboard : *RAWKEYBOARD) {
    if raw_keyboard.MakeCode == KEYBOARD_OVERRUN_MAKE_CODE {
        warningMessage("[Input] Invalid or unrecognizable combination of keys is pressed or the number of keys pressed exceeds the limit for this keyboard");
        return;
    }

    if raw_keyboard.Flags & RI_KEY_BREAK {
        infoMessage("[Input] Key % (hex: 0x%, make code: 0x%) is released",
                    cast(KeyCode) raw_keyboard.VKey,
                    formatHex(raw_keyboard.VKey),
                    formatHex(raw_keyboard.MakeCode));
    } else {
        infoMessage("[Input] Key % (hex: 0x%, make code: 0x%) is down",
                    cast(KeyCode) raw_keyboard.VKey,
                    formatHex(raw_keyboard.VKey),
                    formatHex(raw_keyboard.MakeCode));
    }
}
}
