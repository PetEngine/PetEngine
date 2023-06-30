#scope_export

// @Cleanup: Clean up asserts

StaticArray :: struct(T : Type, capacity : s64) {
    count : s64;
    data  : [capacity] T;
}

operator [] :: (array : StaticArray, index : s64) -> array.T #must #no_context {
    #if DEBUG_BUILD {
        if index >= array.count {
            write_string("[ASSERT]: StaticArray out of bounds access violation\n", true);
            if IsDebuggerPresent() {
                debug_break();
            }
            exit(1);
        }
    }

    return array.data[index];
}

operator *[] :: (array : *StaticArray, index : s64) -> *array.T #must #no_context {
    #if DEBUG_BUILD {
        if index >= array.count {
            write_string("[ASSERT]: StaticArray out of bounds access violation\n", true);
            if IsDebuggerPresent() {
                debug_break();
            }
            exit(1);
        }
    }

    return *array.data[index];
}

operator []= :: (array : *StaticArray, index : s64, value : array.T) #no_context {
    #if DEBUG_BUILD {
        if index >= array.count {
            write_string("[ASSERT]: StaticArray out of bounds access violation\n", true);
            if IsDebuggerPresent() {
                debug_break();
            }
            exit(1);
        }
    }

    array.data[index] = value;
}

for_expansion :: (array : *StaticArray, body : Code, flags : For_Flags) #expand {
    REVERSE    :: cast(bool) (flags & .REVERSE);
    BY_POINTER :: cast(bool) (flags & .POINTER);

    #if REVERSE {
        from_index := array.count - 1;
        to_index   :: 0;
    } else {
        from_index :: 0;
        to_index   := array.count - 1;
    }

    for <=REVERSE `it_index : from_index .. to_index {
        #if BY_POINTER {
            `it := *array.data[it_index];
        } else {
            `it := array.data[it_index];
        }

        #insert(remove = #assert false) body;
    }
}

#scope_file

exit :: (status: s32) #foreign libc;

#if OS == .WINDOWS {
    libc :: #system_library "msvcrt";
} else {
    libc :: #system_library "libc";
}
