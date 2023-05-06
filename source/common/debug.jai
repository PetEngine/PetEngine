#scope_export

MessagePriority :: enum u8 {
    DEBUG;
    INFO;
    WARNING;
    ERROR;
    ASSERT;
}

debugMessage   :: #bake_arguments message(priority = .DEBUG,   print_sys_error = false);
infoMessage    :: #bake_arguments message(priority = .INFO,    print_sys_error = false);
warningMessage :: #bake_arguments message(priority = .WARNING, print_sys_error = false);
errorMessage   :: #bake_arguments message(priority = .ERROR);
assertMessage  :: #bake_arguments message(priority = .ASSERT);

#if DEBUG_BUILD {
    assert :: inline (
        $$expression     : bool,
        $format          := "",
        args             : ..Any,
        $dot             := false,
        $new_line        := true,
        $print_sys_error := true,
        $location        := #caller_location
    ) {
        #if is_constant(expression) {
            #if !expression {
                assertMessage(format, ..args, dot = dot, new_line = new_line, print_sys_error = print_sys_error, location = location);
            }
        } else if !expression {
            assertMessage(format, ..args, dot = dot, new_line = new_line, print_sys_error = print_sys_error, location = location);
        }
    }
} else {
    assert :: inline (
        $$expression     : Code,
        $format          := "",
        args             : ..Any,
        $dot             := false,
        $new_line        := true,
        $print_sys_error := true,
        $location        := #caller_location
    ) {
    }
}

debugCheck :: inline (
    $$expression     : bool,
    $format          := "",
    args             : ..Any,
    $dot             := false,
    $new_line        := true,
    $print_sys_error := true,
    $location        := #caller_location
) {
    assert(expression, format, ..args, dot = dot, new_line = new_line, print_sys_error = print_sys_error, location = location);
}

notImplemented :: () #expand {
    #assert false "Not implemented";
}

message :: (
    $priority        : MessagePriority,
    $format          : string,
    args             : ..Any,
    $dot             := false,
    $new_line        := true,
    $print_sys_error := true,
    $location        := #caller_location
) {
    #if priority == .DEBUG && !DEBUG_BUILD {
        return;
    }

    sys_error_code : u32 = 0;

    #if print_sys_error {
        #if OS == .WINDOWS {
            sys_error_code = GetLastError();
        } else {
            notImplemented();
        }
    }

    builder: Basic.String_Builder;
    builder.allocator = Basic.temporary_allocator;

    Basic.print_to_builder(*builder, "[%]: ", priority);

    #if priority == .ASSERT {
        normalized_filename, result := File.get_absolute_path(location.fully_pathed_filename);
        Basic.assert(result);

        Basic.print_to_builder(*builder, "%(%,%)", normalized_filename, location.line_number, location.character_number);
    }

    if args.count {
        #if priority == .ASSERT {
            Basic.append(*builder, ": ");
        }
        Basic.print_to_builder(*builder, format, ..args);
    } else #if format.count {
        #if priority == .ASSERT {
            Basic.append(*builder, ": ");
        }
        Basic.append(*builder, format);
    }

    #if print_sys_error {
        if sys_error_code != 0 {
            Basic.print_to_builder(*builder, ". System error(%): ", sys_error_code);

            sys_error_message : string;

            #if OS == .WINDOWS {
                sys_error_message.count = FormatMessageA(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_IGNORE_INSERTS | FORMAT_MESSAGE_FROM_SYSTEM,
                                                         null,
                                                         sys_error_code,
                                                         #run MAKELANGID(LANG_ENGLISH, SUBLANG_ENGLISH_US),
                                                         cast(LPSTR) *sys_error_message.data,
                                                         0,
                                                         null);
                sys_error_message.count -= ".\r\n".count;
            } else {
                notImplemented();
            }

            Basic.assert(sys_error_message.count > 0);
            Basic.assert(sys_error_message.data != null);

            Basic.append(*builder, sys_error_message);

            #if OS == .WINDOWS {
                result := LocalFree(sys_error_message.data);
                Basic.assert(result == null);
            } else {
                notImplemented();
            }
        }
    }

    #if dot      Basic.append(*builder, ".");
    #if new_line Basic.append(*builder, "\n");

    #if priority == .ASSERT {
        // @TODO: Stack trace
    }

    message := Basic.builder_to_string(*builder, builder.allocator);

    // @TODO: Lock mutex

    #if OS == .WINDOWS {
        #if priority != .INFO {
            c_string : *u8 = Basic.talloc(message.count + 1);
            memcpy(c_string, message.data, message.count);
            c_string[message.count] = 0;

            OutputDebugStringA(c_string);
        }

        console_handle : HANDLE = ---;
        #if priority == .ERROR console_handle = GetStdHandle(STD_ERROR_HANDLE);
        else                   console_handle = GetStdHandle(STD_OUTPUT_HANDLE);
        Basic.assert(console_handle != INVALID_HANDLE_VALUE);

             #if priority == .DEBUG   SetConsoleTextAttribute(console_handle, 0x09);
        else #if priority == .INFO    SetConsoleTextAttribute(console_handle, 0x0A);
        else #if priority == .WARNING SetConsoleTextAttribute(console_handle, 0x06);
        else #if priority >= .ERROR   SetConsoleTextAttribute(console_handle, 0x04);
        else                          #assert false "Unhandled message priority";

        success := WriteFile(console_handle, message.data, cast(u32) message.count, null, null);
        Basic.assert(success != FALSE);

        SetConsoleTextAttribute(console_handle, 0x07);
    } else {
        notImplemented();
    }

    // @TODO: Unlock mutex

    #if priority == .ASSERT {
        #if DEBUG_BUILD {
            debug_break();
        }
        Basic.exit(1);
    }
}

#scope_file

File :: #import "File";
