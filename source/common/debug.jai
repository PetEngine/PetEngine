#scope_export

// @TODO:
//     - #StackTrace. Find out how Visual Studio handles inline procedures
//     - Tags
//     - Log messages to files depending on tag

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
        custom_sys_code  : u32 = 0,
        location         := #caller_location
    ) #expand #no_debug {
        #if is_constant(#insert expression) {
            #if !(#insert expression) {
                FORMAT_OR_EXPRESSION :: #run formatOrExpression(format, expression);
                assertMessage(FORMAT_OR_EXPRESSION, ..args, print_sys_error = print_sys_error, custom_sys_code, location);
            }
        } else {
            if !(#insert expression) {
                FORMAT_OR_EXPRESSION :: #run formatOrExpression(format, expression);
                assertMessage(FORMAT_OR_EXPRESSION, ..args, print_sys_error = print_sys_error, custom_sys_code, location);
            }
        }
    }

    debugCheck :: (
        expression       : Code,
        $format          := "",
        args             : ..Any,
        $print_sys_error := false,
        custom_sys_code  : u32 = 0,
        location         := #caller_location
    ) #expand #no_debug {
        assert(expression, format, ..args, print_sys_error = print_sys_error, custom_sys_code, location);
    }

    #if OS == .WINDOWS {
        debugCheckWin32 :: (expression : Code, $strict := true, location := #caller_location) #expand #no_debug {
            result := #insert expression;

            #if strict {
                success := result == ERROR_SUCCESS;
            } else {
                success := SUCCEEDED(result);
            }

            STR_EXPRESSION :: #run codeToString(expression);
            assert(success, STR_EXPRESSION, print_sys_error = true, cast,no_check(u32) result, location);

            #if !strict {
                if result != ERROR_SUCCESS {
                    warningMessage(STR_EXPRESSION, print_sys_error = true, cast,no_check(u32) result, location);
                }
            }
        }

        debugCheckHRESULT :: (expression : Code, $strict := true, location := #caller_location) #expand #no_debug {
            result := #insert expression;

            // Mask out reserved value (see common/windows.jai HRESULT definition)
            result &= 0x87FF_FFFF;

            #if strict {
                success := result == ERROR_SUCCESS;
            } else {
                success := SUCCEEDED(result);
            }

            STR_EXPRESSION :: #run codeToString(expression);
            assert(success, STR_EXPRESSION, print_sys_error = true, cast,no_check(u32) result, location);

            #if !strict {
                if result != ERROR_SUCCESS {
                    warningMessage(STR_EXPRESSION, print_sys_error = true, cast,no_check(u32) result, location);
                }
            }
        }

        debugCheckNT :: (expression : Code, $strict := true, location := #caller_location) #expand #no_debug {
            status := #insert expression;

            STR_EXPRESSION :: #run codeToString(expression);

            if STATUS_SEVERITY(status) == {
                case STATUS_SEVERITY_INFORMATIONAL;
                    infoMessage(STR_EXPRESSION, print_sys_error = true, cast,no_check(u32) status, location);

                case STATUS_SEVERITY_WARNING;
                    #if strict {
                        assertMessage(STR_EXPRESSION, print_sys_error = true, cast,no_check(u32) status, location);
                    } else {
                        warningMessage(STR_EXPRESSION, print_sys_error = true, cast,no_check(u32) status, location);
                    }

                case STATUS_SEVERITY_ERROR;
                    assertMessage(STR_EXPRESSION, print_sys_error = true, cast,no_check(u32) status, location);
            }
        }
    }

    debugCheckVK :: (expression : Code, $strict := true, location := #caller_location) #expand #no_debug {
        result := #insert expression;

        #if strict {
            success := result == .VK_SUCCESS;
        } else {
            success := result >= .VK_SUCCESS;
        }

        STR_EXPRESSION :: #run codeToString(expression);

        assert(success, "% has returned %", STR_EXPRESSION, result, location = location);

        #if !strict {
            if result != .VK_SUCCESS {
                absolute_path_buffer : [File.MAX_FILENAME_LENGTH + 1] u8 = ---;
                absolute_path := getAbsolutePath(*absolute_path_buffer, location.fully_pathed_filename);

                warningMessage("%(%,%): % has returned %",
                               absolute_path,
                               location.line_number,
                               location.character_number,
                               STR_EXPRESSION,
                               result);
            }
        }
    }
} else {
    assert :: (
        #discard expression      : Code,
        #discard format          := "",
        #discard args            : ..Any,
        #discard print_sys_error := false,
        #discard custom_sys_code : u32 = 0,
        #discard location        := #caller_location
    ) #expand #no_debug {
    }

    debugCheck :: (
        expression               : Code,
        #discard format          := "",
        #discard args            : ..Any,
        #discard print_sys_error := false,
        #discard custom_sys_code : u32 = 0,
        #discard location        := #caller_location
    ) #expand #no_debug {
        #insert expression;
    }

    #if OS == .WINDOWS {
        debugCheckWin32 :: (expression : Code, #discard strict := true, #discard location := #caller_location) #expand #no_debug {
            #insert expression;
        }

        debugCheckHRESULT :: (expression : Code, #discard strict := true, #discard location := #caller_location) #expand #no_debug {
            #insert expression;
        }

        debugCheckNT :: (expression : Code, #discard strict := true, #discard location := #caller_location) #expand #no_debug {
            #insert expression;
        }
    }

    debugCheckVK :: (expression : Code, #discard strict := true, #discard location := #caller_location) #expand #no_debug {
        #insert expression;
    }
}

assertThreadKind :: (kind : ThreadKind, procedure_name := #procedure_name(), location := #caller_location) #expand #no_debug {
    assert(context.pet.thread.kind == kind, "% can be called only from % thread kind", procedure_name, kind, location = location);
}

notImplemented :: ($assert_in_run_time := false, location := #caller_location) #expand #no_debug {
    #if assert_in_run_time {
        assertMessage("Not implemented", location = location);
    } else {
        #assert false "Not implemented";
    }
}

codeToString :: (code : Code) -> string #compile_time {
    // @Cleanup: #CompileTime. Remove this assert when prevent_compile_time_calls_from_runtime will be fixed
    Basic.assert(#compile_time, "This function should be run only in compile time");

    builder := Basic.String_Builder.{ allocator = Basic.temp };

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

message :: (
    $priority        : MessagePriority,
    $format          : string,
    args             : ..Any,
    $print_sys_error := false,
    custom_sys_code  : u32 = 0,
    location         := #caller_location
) {
    #if priority == .DEBUG   && !DEBUG_BUILD            return;
    #if priority == .VERBOSE && !PRINT_VERBOSE_MESSAGES return;

    sys_error_code := custom_sys_code;

    #if print_sys_error {
        #if OS == .WINDOWS {
            if !sys_error_code {
                sys_error_code = GetLastError();
            }
        } else {
            notImplemented();
        }
    }

    builder := Basic.String_Builder.{ allocator = Basic.temp };

    Basic.print(*builder, "[%]: ", priority);

    #if priority == .ASSERT {
        absolute_path_buffer : [File.MAX_FILENAME_LENGTH + 1] u8 = ---;
        absolute_path := getAbsolutePath(*absolute_path_buffer, location.fully_pathed_filename);

        Basic.print(*builder, "%(%,%): ", absolute_path, location.line_number, location.character_number);
    } else if custom_sys_code {
        absolute_path_buffer : [File.MAX_FILENAME_LENGTH + 1] u8 = ---;
        absolute_path := getAbsolutePath(*absolute_path_buffer, location.fully_pathed_filename);

        Basic.print(*builder, "%(%,%): ", absolute_path, location.line_number, location.character_number);
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
        if sys_error_code {
            minimum_digits := 4 << cast(s64) (sys_error_code > 0xFFFF);

            #if priority < .ERROR {
                Basic.print(*builder, " has returned 0x%: ", formatHex(sys_error_code, minimum_digits));
            } else {
                Basic.print(*builder, ". System error (0x%): ", formatHex(sys_error_code, minimum_digits));
            }

            sys_error_message_buffer : [512] u8 = ---;
            sys_error_message := string.{ data = sys_error_message_buffer.data };

            #if OS == .WINDOWS {
                sys_error_message.count = FormatMessageA(FORMAT_MESSAGE_IGNORE_INSERTS | FORMAT_MESSAGE_FROM_SYSTEM,
                                                         null,
                                                         sys_error_code,
                                                         MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
                                                         sys_error_message.data,
                                                         sys_error_message_buffer.count,
                                                         null);
                sys_error_message.count -= ".\r\n".count;
            } else {
                notImplemented();
            }

            Basic.assert(sys_error_message.count > 0);

            Basic.append(*builder, sys_error_message);
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
        Basic.append(*builder, "\nStack trace:\n");
        if #compile_time {
            printStackTraceFromJaiContext(*builder);
        } else {
            printStackTrace(*builder);
        }
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
        exitProcess(ifx sys_error_code then sys_error_code else 1);
    }
}

formatOrExpression :: ($format : string, expression : Code) -> string #compile_time {
    Basic.assert(#compile_time, "This function should be run only in compile time"); // @Cleanup: #CompileTime.

    #if format.count > 0 {
        return format;
    } else {
        return codeToString(expression);
    }
}

// We don't use context.stack_trace since it does not track external procedures which may be essential in stack trace
printStackTrace :: (builder : *Basic.String_Builder) {
    #if OS == .WINDOWS {
        scopedLock(*g_mutex); // All DbgHelp functions are single threaded, so we have to synchronize their calls

        FRAMES_TO_SKIP        :: 2; // Skip this function & message (caller)
        MAX_FRAMES_TO_CAPTURE :: 0xFFFF;

        // We might not have per frame arena at this moment, so we use temporary storage
        stack_trace : **void = Basic.talloc(MAX_FRAMES_TO_CAPTURE * size_of(*void));

        frames_count := RtlCaptureStackBackTrace(FRAMES_TO_SKIP, MAX_FRAMES_TO_CAPTURE, stack_trace, null);
        Basic.assert(frames_count > 0, "RtlCaptureStackBackTrace did not capture any frames which is impossible. Error: %", GetLastError());

        pseudo_process_handle := GetCurrentProcess();
        process : HANDLE;
        success := DuplicateHandle(pseudo_process_handle, pseudo_process_handle, pseudo_process_handle, *process, 0, FALSE, DUPLICATE_SAME_ACCESS);
        Basic.assert(success != FALSE, "DuplicateHandle has failed with error %", GetLastError());
        defer {
            success = CloseHandle(process);
            Basic.assert(success != FALSE, "CloseHandle has failed with error %", GetLastError());
        }

        success = SymInitialize(process, null, TRUE);
        Basic.assert(success != FALSE, "SymInitialize has failed with error %", GetLastError());
        defer {
            success = SymCleanup(process);
            Basic.assert(success != FALSE, "SymCleanup has failed with error %", GetLastError());
        }

        line_info          := IMAGEHLP_LINE64.{ SizeOfStruct = size_of(IMAGEHLP_LINE64) };
        module_info        := IMAGEHLP_MODULE64.{ SizeOfStruct = size_of(IMAGEHLP_MODULE64) };
        symbol_info_memory : [size_of(SYMBOL_INFO) + MAX_SYM_NAME] u8;

        symbol_info := cast(*SYMBOL_INFO) symbol_info_memory.data;
        symbol_info.SizeOfStruct = size_of(SYMBOL_INFO);
        symbol_info.MaxNameLen   = MAX_SYM_NAME;

        for frame : toView(stack_trace, frames_count) {
            Basic.append(builder, "    ");

            column : u32;
            if SymGetLineFromAddr64(process, cast(u64) frame, *column, *line_info) {
                Basic.print(builder, "%(%,%): ", to_string(line_info.FileName), line_info.LineNumber, column);
            } else {
                module_base := SymGetModuleBase64(process, cast(u64) frame);
                Basic.assert(module_base != 0, "SymGetModuleBase64 has failed with error %", GetLastError());

                success = SymGetModuleInfo64(process, cast(u64) frame, *module_info);
                Basic.assert(success != FALSE, "SymGetModuleInfo64 has failed with error %", GetLastError());

                Basic.print(builder, "%(%): ", to_string(module_info.LoadedImageName.data), frame);
            }

            procedure_name : string = ---;
            if SymFromAddr(process, cast(u64) frame, null, symbol_info) {
                procedure_name.count = symbol_info.NameLen;
                procedure_name.data  = symbol_info.Name.data;
            } else {
                procedure_name = "<unknown procedure>";

                last_error := GetLastError();
                Basic.assert(last_error == ERROR_MOD_NOT_FOUND, "SymFromAddr has failed with error %", last_error);
            }

            Basic.print(builder, "%\n", procedure_name);
        }
    } else {
        // @TODO: #StackTrace. This implementation is ok for now, but we have to rewrite it to something similar to what we do on Windows
        printStackTraceFromJaiContext(builder);
    }
}

printStackTraceFromJaiContext :: (builder : *Basic.String_Builder) {
    // _STACK_TRACE is defined by the compiler based on Build_Options.stack_trace
    #if _STACK_TRACE {
        Basic.assert(context.stack_trace != null, "Stack trace is empty which is impossible");

        node := context.stack_trace;
        while node {
            if node.info {
                Basic.print(builder, "    %(%): ", node.info.location.fully_pathed_filename, node.line_number);
                if node.info.name {
                    Basic.append(builder, node.info.name);
                } else {
                    Basic.print(builder, "<unknown procedure> %", node.info.procedure_address);
                }
                Basic.append(builder, "\n");
            } else {
                Basic.append(builder, "    Unknown procedure in unknown module\n");
            }
            node = node.next;
        }
    } else {
        Basic.append(builder, "    <empty>\n");
    }
}

g_mutex : Mutex;

Program_Print :: #import "Program_Print";
