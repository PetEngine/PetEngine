Input :: struct {
    MAX_KEYS     :: #run Basic.enum_highest_value(Key) + 1;
    MAX_GAMEPADS :: 4;

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

    Thumb :: struct {
        x      : f32; // [-1.0; 1.0]
        y      : f32; // [-1.0; 1.0]
        button : KeyState;
    }

    Gamepad :: struct {
        button_a : KeyState;
        button_b : KeyState;
        button_x : KeyState;
        button_y : KeyState;

        left_shoulder  : KeyState;
        right_shoulder : KeyState;

        start : KeyState;
        back  : KeyState;

        dpad_up    : KeyState;
        dpad_down  : KeyState;
        dpad_left  : KeyState;
        dpad_right : KeyState;

        left_trigger  : f32; // [0.0, 1.0]
        right_trigger : f32; // [0.0, 1.0]

        left_thumb  : Thumb;
        right_thumb : Thumb;

        connected : bool;
    }

    keyboard : [MAX_KEYS] KeyState;
    mouse    : Mouse;
    gamepads : [MAX_GAMEPADS] Gamepad;
}

createInput :: (window : *Window) {
    #if OS == .WINDOWS {
        loadXInput();
        setupInitialInputState(cast(*Win32Window) window);
        registerRawInput(cast(*Win32Window) window);
    } else {
        notImplemented();
    }
}

destroyInput :: () {
    #if OS == .WINDOWS {
        unloadXInput();
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

    for * input.gamepads {
        it.button_a           &= ~(.PRESSED | .RELEASED);
        it.button_b           &= ~(.PRESSED | .RELEASED);
        it.button_x           &= ~(.PRESSED | .RELEASED);
        it.button_y           &= ~(.PRESSED | .RELEASED);
        it.left_shoulder      &= ~(.PRESSED | .RELEASED);
        it.right_shoulder     &= ~(.PRESSED | .RELEASED);
        it.start              &= ~(.PRESSED | .RELEASED);
        it.back               &= ~(.PRESSED | .RELEASED);
        it.left_thumb.button  &= ~(.PRESSED | .RELEASED);
        it.right_thumb.button &= ~(.PRESSED | .RELEASED);
        it.dpad_up            &= ~(.PRESSED | .RELEASED);
        it.dpad_down          &= ~(.PRESSED | .RELEASED);
        it.dpad_left          &= ~(.PRESSED | .RELEASED);
        it.dpad_right         &= ~(.PRESSED | .RELEASED);
    }
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

getNewDigitalButtonState :: inline (state : Input.KeyState, down : bool) -> Input.KeyState #no_context {
    if down return getNewKeyState(state, true);
    return getNewKeyState(state, false);
}

getWindowSurfaceSpaceMousePosition :: inline (window : *Window) -> (x : s16, y : s16) #no_context {
    return window.input.mouse.screen_x - window.surface.x,
           window.input.mouse.screen_y - window.surface.y;
}

#scope_file

#if OS == .WINDOWS {
    #load "windows/input.jai";
} else {
    notImplemented();
}
