// @TODO: #Input.
//     1. Multiple gamepad support.

Input :: struct {
    MAX_KEYS :: #run Basic.enum_highest_value(Key) + 1;

    KeyState :: enum_flags u8 {
        DOWN;
        RELEASED;
        PRESSED;
        ON; // For caps lock, num lock and scroll lock
    }

    Key :: enum u8 {
        BACKSPACE;
        TAB;

        ENTER;
        ESCAPE;
        SPACE;

        CAPS_LOCK;
        NUM_LOCK;
        SCROLL_LOCK;

        PAGE_UP;
        PAGE_DOWN;
        END;
        HOME;
        INSERT;
        DELETE;

        LEFT;
        UP;
        RIGHT;
        DOWN;

        NUM_0;
        NUM_1;
        NUM_2;
        NUM_3;
        NUM_4;
        NUM_5;
        NUM_6;
        NUM_7;
        NUM_8;
        NUM_9;
        NUM_DIV;
        NUM_MUL;
        NUM_SUB;
        NUM_ADD;
        NUM_ENTER;
        NUM_DOT;

        F1;
        F2;
        F3;
        F4;
        F5;
        F6;
        F7;
        F8;
        F9;
        F10;
        F11;
        F12;
        F13;
        F14;
        F15;
        F16;
        F17;
        F18;
        F19;
        F20;
        F21;
        F22;
        F23;
        F24;

        KEY_0;
        KEY_1;
        KEY_2;
        KEY_3;
        KEY_4;
        KEY_5;
        KEY_6;
        KEY_7;
        KEY_8;
        KEY_9;

        A;
        B;
        C;
        D;
        E;
        F;
        G;
        H;
        I;
        J;
        K;
        L;
        M;
        N;
        O;
        P;
        Q;
        R;
        S;
        T;
        U;
        V;
        W;
        X;
        Y;
        Z;

        LEFT_SHIFT;
        RIGHT_SHIFT;
        LEFT_CTRL;
        RIGHT_CTRL;
        LEFT_ALT;
        RIGHT_ALT;
        LEFT_WIN;
        RIGHT_WIN;
        CONTEXT_MENU;

        COMMA;         // ,<
        DOT;           // .>
        SLASH;         // /?
        SEMICOLON;     // ;:
        APOSTROPHE;    // '"
        BACK_SLASH;    // \|
        LEFT_BRACKET;  // [{
        RIGHT_BRACKET; // ]}
        DASH;          // -_
        EQUALS;        // =+
        TILDE;         // `~

        VOLUME_MUTE;
        VOLUME_DOWN;
        VOLUME_UP;

        MEDIA_PREV;
        MEDIA_NEXT;
        MEDIA_PLAY_PAUSE;
        MEDIA_STOP;

        OEM_102; // "<>" or "\|" on RT 102-key keyboard (the key between left shift and z)

        PRINT_SCREEN;
        BREAK;
        PAUSE;

        UNDEFINED;
    }

    Mouse :: struct {
        screen_x : s16;
        screen_y : s16;

        surface_x : s16;
        surface_y : s16;

        clamped_surface_x : s16;
        clamped_surface_y : s16;

        dx : s16;
        dy : s16;

        dwheel            : s16;
        dwheel_horizontal : s16;

        button_1 : KeyState;
        button_2 : KeyState;
        button_3 : KeyState;
        button_4 : KeyState;
        button_5 : KeyState;

        #place button_1; button_left   : KeyState;
        #place button_2; button_right  : KeyState;
        #place button_3; button_middle : KeyState;
    }

    keyboard : [MAX_KEYS] KeyState;
    mouse    : Mouse;
}

registerInput :: (window : *Window) {
    #if OS == .WINDOWS {
        setupInitialInputState(cast(*Win32Window) window);
        registerRawInput(cast(*Win32Window) window);
    } else {
        notImplemented();
    }
}

resetInput :: (input : *Input) {
    for * input.keyboard {
        it.* &= ~(.PRESSED | .RELEASED);
    }

    input.mouse.dx                = 0;
    input.mouse.dy                = 0;
    input.mouse.dwheel            = 0;
    input.mouse.dwheel_horizontal = 0;

    input.mouse.button_1 &= ~(.PRESSED | .RELEASED);
    input.mouse.button_2 &= ~(.PRESSED | .RELEASED);
    input.mouse.button_3 &= ~(.PRESSED | .RELEASED);
    input.mouse.button_4 &= ~(.PRESSED | .RELEASED);
    input.mouse.button_5 &= ~(.PRESSED | .RELEASED);
}

getNewKeyState :: inline (key_state : Input.KeyState, $down : bool) -> Input.KeyState #no_context {
    new_state := key_state;
    #if down {
        if !(key_state & .DOWN) {
            new_state |= .PRESSED | .DOWN;
        }
    } else {
        if key_state & .DOWN {
            new_state |= .RELEASED;
            new_state &= ~.DOWN;
        }
    }
    return new_state;
}

#scope_file

#if OS == .WINDOWS {
    #load "windows/input.jai";
} else {
    notImplemented();
}
