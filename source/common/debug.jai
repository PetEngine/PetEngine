#scope_export

MessagePriority :: enum u8 {
    VERBOSE;
    DEBUG;
    INFO;
    WARNING;
    ERROR;
    ASSERT;
}

verboseMessage :: #bake_arguments message(priority = .VERBOSE);
debugMessage   :: #bake_arguments message(priority = .DEBUG);
infoMessage    :: #bake_arguments message(priority = .INFO);
warningMessage :: #bake_arguments message(priority = .WARNING);
errorMessage   :: #bake_arguments message(priority = .ERROR);
assertMessage  :: #bake_arguments message(priority = .ASSERT);

#if DEBUG_BUILD {
    assert :: (
        expression       : Code,
        $format          := "",
        args             : ..Any,
        $print_sys_error := false,
        location         := #caller_location
    ) #expand #no_debug {
        #if is_constant(#insert expression) {
            #if !(#insert expression) {
                FORMAT_OR_EXPRESSION :: #run formatOrExpression(format, expression);
                assertMessage(FORMAT_OR_EXPRESSION, ..args, print_sys_error = print_sys_error, location = location);
            }
        } else {
            if !(#insert expression) {
                FORMAT_OR_EXPRESSION :: #run formatOrExpression(format, expression);
                assertMessage(FORMAT_OR_EXPRESSION, ..args, print_sys_error = print_sys_error, location = location);
            }
        }
    }

    debugCheck :: (
        expression       : Code,
        $format          := "",
        args             : ..Any,
        $print_sys_error := false,
        location         := #caller_location
    ) #expand #no_debug {
        assert(expression, format, ..args, print_sys_error = print_sys_error, location = location);
    }
} else {
    assert :: (
        #discard expression      : Code,
        #discard format          := "",
        #discard args            : ..Any,
        #discard print_sys_error := false,
        #discard location        := #caller_location
    ) #expand #no_debug {
    }

    debugCheck :: (
        expression               : Code,
        #discard format          := "",
        #discard args            : ..Any,
        #discard print_sys_error := false,
        #discard location        := #caller_location
    ) #expand #no_debug {
        #insert expression;
    }
}

#if OS == .WINDOWS {
    debugCheckHRESULT :: (expression : Code, $strict := true, location := #caller_location) #expand #no_debug {
        #if DEBUG_BUILD {
            result := #insert expression;

            // Mask out reserved value (see common/windows.jai HRESULT definition)
            result &= 0x87FF_FFFF;

            #if strict {
                success := result == ERROR_SUCCESS;
            } else {
                success := SUCCEEDED(result);
            }

            STR_EXPRESSION :: #run codeToString(expression);
            format_result  := formatHex(result, 8);

            assert(success, "% returned 0x%", STR_EXPRESSION, format_result, print_sys_error = true, location = location);

            #if !strict {
                if result != ERROR_SUCCESS {
                    warningMessage("% returned 0x% at %(%)",
                                   STR_EXPRESSION,
                                   format_result,
                                   location.fully_pathed_filename,
                                   location.line_number,
                                   print_sys_error = true);
                }
            }
        } else {
            #insert expression;
        }
    }
}

debugCheckVK :: (expression : Code, $strict := true, location := #caller_location) #expand #no_debug {
    #if DEBUG_BUILD {
        result := #insert expression;

        #if strict {
            success := result == .VK_SUCCESS;
        } else {
            success := result >= .VK_SUCCESS;
        }

        STR_EXPRESSION :: #run codeToString(expression);

        assert(success, "% returned %", STR_EXPRESSION, result, location = location);

        #if !strict {
            if result != .VK_SUCCESS {
                warningMessage("% returned % at %(%)",
                               STR_EXPRESSION,
                               result,
                               location.fully_pathed_filename,
                               location.line_number);
            }
        }
    } else {
        #insert expression;
    }
}

assertThreadKind :: (kind : ThreadKind, procedure_name := #procedure_name(), location := #caller_location) #expand #no_debug {
    assert(context.pet.thread_kind == kind, "% can be called only from % thread kind", procedure_name, kind, location = location);
}

notImplemented :: ($assert_in_run_time := false, location := #caller_location) #expand #no_debug {
    #if assert_in_run_time {
        assertMessage("Not implemented", location = location);
    } else {
        #assert false "Not implemented";
    }
}

codeToString :: (code : Code) -> string #compile_time {
    // @TODO: #CompileTime. Remove this assert when prevent_compile_time_calls_from_runtime will be fixed
    Basic.assert(#compile_time, "This function should be run only in compile time");

    builder : Basic.String_Builder;
    builder.allocator = Basic.temp;

    root := Compiler.compiler_get_nodes(code);
    Program_Print.print_expression(*builder, root);

    return Basic.builder_to_string(*builder,, allocator = Basic.temp);
}

debuggerPresent :: inline () -> bool #no_context {
    #if OS == .WINDOWS {
        return IsDebuggerPresent() != FALSE;
    } else {
        notImplemented();
        return false;
    }
}

debugBreakIfDebugging :: () #expand #no_debug {
    if debuggerPresent() then debug_break();
}

#scope_file

Compiler      :: #import "Compiler";
Program_Print :: #import "Program_Print";
File_CLEANUP  :: #import "File";

g_mutex : Mutex;

message :: (
    $priority        : MessagePriority,
    $format          : string,
    args             : ..Any,
    $print_sys_error := false,
    location         := #caller_location
) {
    #if priority == .DEBUG   && !DEBUG_BUILD            return;
    #if priority == .VERBOSE && !PRINT_VERBOSE_MESSAGES return;

    sys_error_code : u32 = 0;

    #if print_sys_error {
        #if OS == .WINDOWS {
            sys_error_code = GetLastError();
        } else {
            notImplemented();
        }
    }

    builder: Basic.String_Builder;
    builder.allocator = Basic.temp;

    Basic.print(*builder, "[%]: ", priority);

    #if priority == .ASSERT {
        normalized_filename, result := File_CLEANUP.get_absolute_path(location.fully_pathed_filename);
        Basic.assert(result);

        Basic.print(*builder, "%(%,%): ", normalized_filename, location.line_number, location.character_number);
    }

    if args.count > 0 {
        #assert format.count > 0;
        Basic.print(*builder, format, ..args);
    } else #if format.count > 0 {
        Basic.append(*builder, format);
    } else {
        Basic.append(*builder, "<no message>");
    }

    #if print_sys_error {
        if sys_error_code != 0 {
            Basic.print(*builder, ". System error (%): ", sys_error_code);

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

    // Add new line if there is no any in the end
    {
        buffer := Basic.get_current_buffer(*builder);
        data := Basic.get_buffer_data(buffer);
        if data[buffer.count - 1] != #char "\n" {
            Basic.append(*builder, "\n");
        }
    }

    #if priority == .ASSERT {
        // @TODO: Stack trace
    }

    message := Basic.builder_to_string(*builder,, allocator = Basic.temp);

    lock(*g_mutex);

    #if OS == .WINDOWS {
        #if priority != .VERBOSE && priority != .INFO {
            OutputDebugStringA(Basic.temp_c_string(message));
        }

        console_handle : HANDLE = ---;
        #if priority == .ERROR console_handle = GetStdHandle(STD_ERROR_HANDLE);
        else                   console_handle = GetStdHandle(STD_OUTPUT_HANDLE);
        Basic.assert(console_handle != INVALID_HANDLE_VALUE);

        console_mode : u32;
        if GetConsoleMode(console_handle, *console_mode) {
            success : BOOL;

            // We do not change a color for verbose messages
            #if priority != .VERBOSE {
                     #if priority == .DEBUG   success = SetConsoleTextAttribute(console_handle, 0x09);
                else #if priority == .INFO    success = SetConsoleTextAttribute(console_handle, 0x0A);
                else #if priority == .WARNING success = SetConsoleTextAttribute(console_handle, 0x06);
                else #if priority >= .ERROR   success = SetConsoleTextAttribute(console_handle, 0x04);
                else                          #assert false "Unhandled message priority";
                Basic.assert(success != FALSE);
            }

            success = WriteFile(console_handle, message.data, cast(u32) message.count, null, null);
            Basic.assert(success != FALSE);

            #if priority != .VERBOSE {
                success = SetConsoleTextAttribute(console_handle, 0x07);
                Basic.assert(success != FALSE);
            }
        } else {
            success := WriteFile(console_handle, message.data, cast(u32) message.count, null, null);
            Basic.assert(success != FALSE);
        }
    } else {
        notImplemented();
    }

    unlock(*g_mutex);

    #if priority == .ASSERT {
        debugBreakIfDebugging();
        exitProcess(ifx sys_error_code != 0 then sys_error_code else 1);
    }
}

formatOrExpression :: ($format : string, expression : Code) -> string #compile_time {
    // @TODO: #CompileTime.
    Basic.assert(#compile_time, "This function should be run only in compile time");

    #if format.count > 0 {
        return format;
    } else {
        return codeToString(expression);
    }
}
