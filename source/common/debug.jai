#scope_export

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
                FORMAT_OR_EXPRESSION :: #ifx format.count > 0 then format else #run codeToString(expression);
                assertMessage(FORMAT_OR_EXPRESSION, ..args, print_sys_error = print_sys_error, custom_sys_code, location);
            }
        } else {
            if !(#insert expression) {
                FORMAT_OR_EXPRESSION :: #ifx format.count > 0 then format else #run codeToString(expression);
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
            if !success {
                assertMessage(STR_EXPRESSION, print_sys_error = true, cast,no_check(u32) result, location);
            }

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
            if !success {
                assertMessage(STR_EXPRESSION, print_sys_error = true, cast,no_check(u32) result, location);
            }

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
        if !success {
            assertMessage("% has returned %", STR_EXPRESSION, result, location = location);
        }

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

    assertThreadKind :: (kind : ThreadKind, procedure_name := #procedure_name(), location := #caller_location) #expand #no_debug {
        if context.pet.thread.kind != kind {
            assertMessage("% can be called only from % thread", procedure_name, kind, location = location);
        }
    }

    assertNormalized :: (expression : Code, $epsilon := DEFAULT_F32_EPSILON, location := #caller_location) #expand #no_debug {
        v := #insert expression;
        if !normalized(v, epsilon) {
            STR_EXPRESSION :: #run codeToString(expression);
            assertMessage("%1 should be normalized. %1 = %, dot = %, epsilon = %",
                          STR_EXPRESSION,
                          formatInline(v),
                          dot(v, v),
                          epsilon,
                          location = location);
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

    assertThreadKind :: (
        #discard kind           : ThreadKind,
        #discard procedure_name := #procedure_name(),
        #discard location       := #caller_location
    ) #expand #no_debug {
    }

    assertNormalized :: (
        #discard expression : Code,
        #discard epsilon    := DEFAULT_F32_EPSILON,
        #discard location   := #caller_location
    ) #expand #no_debug {
    }
}

notImplemented :: ($assert_in_run_time := false, location := #caller_location) #expand #no_debug {
    #if assert_in_run_time {
        assertMessage("Not implemented", location = location);
    } else {
        #assert false "Not implemented";
    }
}

codeToString :: (code : Code) -> string #compile_time {
    builder := Basic.String_Builder.{ allocator = Basic.temp };

    root := Compiler.compiler_get_nodes(code);
    Program_Print.print_expression(*builder, root);

    return Basic.builder_to_string(*builder,, allocator = Basic.temp);
}

debuggerAttached :: inline () -> bool #no_context {
    #if OS == .WINDOWS {
        return IsDebuggerPresent() != FALSE;
    } else {
        notImplemented();
        return false;
    }
}

debugBreakIfDebugging :: () #expand #no_debug {
    if #compile_time {
        compile_time_debug_break();
    } else if debuggerAttached() {
        #if OS == .PS5 {
            #asm { int 0x41; }
        } else #if CPU == .X64 {
            #asm { int 3; }
        } else #if CPU == .ARM64 {
            #bytes .[ 0x20, 0x00, 0b001_0_0000, 0b1101_0100 ]; // BRK 0x01: 11 bit instruction, 16 bit immediate, 5 bit unused
        } else #if OS == .WASM {
            wasm_debug_break :: () #foreign; // You will need to provide this function as JS code in your WASM environment
            wasm_debug_break();
        } else {
            llvm_trap :: () #intrinsic "llvm.debugtrap";
            llvm_trap();
        }
    }
}

createUnhandledExceptionHandler :: () {
    g_exception_handler_context.jai_context.allocator   = context.allocator;
    g_exception_handler_context.jai_context.logger      = context.logger;
    g_exception_handler_context.jai_context.logger_data = context.logger_data;
    g_exception_handler_context.jai_context.print_style = context.print_style;
    // We do not need globals for unhandled exception handler

    push_context g_exception_handler_context.jai_context {
        context.thread_index    = getNextThreadIndex();
        context.pet.thread.name = "";
        context.pet.thread.kind = .UNDEFINED;

        context.allocator.proc(.THREAD_START, 0, 0, null, context.allocator.data);

        context.temporary_storage = *g_exception_handler_context.temporary_storage;

        // TEMPORARY_STORAGE_SIZE is defined by the compiler based on Build_Options.temporary_storage_size
        g_exception_handler_context.temporary_storage_data = Allocator.rpaligned_alloc(DEFAULT_CACHE_LINE_SIZE, TEMPORARY_STORAGE_SIZE);
        set_initial_data(context.temporary_storage, TEMPORARY_STORAGE_SIZE, g_exception_handler_context.temporary_storage_data);

        // We do not need arenas for unhandled exception handler
    }

    createRecursiveMutex(*g_exception_handler_context.mutex);

    #if OS == .WINDOWS {
        g_exception_handler_context.previous_handler = SetUnhandledExceptionFilter(unhandledExceptionHandler);
    } else {
        notImplemented();
    }
}

destroyUnhandledExceptionHandler :: () {
    #if OS == .WINDOWS {
        previous_handler := SetUnhandledExceptionFilter(g_exception_handler_context.previous_handler);
        assert(previous_handler == unhandledExceptionHandler, print_sys_error = true);
    } else {
        notImplemented();
    }

    destroyRecursiveMutex(*g_exception_handler_context.mutex);

    push_context g_exception_handler_context.jai_context {
        Allocator.rpfree(g_exception_handler_context.temporary_storage_data);
        context.allocator.proc(.THREAD_STOP, 0, 0, null, context.allocator.data);
    }
}

getSystemMessage :: (message_buffer : [] u8, system_code : u32) -> string {
    #if OS == .WINDOWS {
        message_length : s64 = FormatMessageA(FORMAT_MESSAGE_IGNORE_INSERTS | FORMAT_MESSAGE_FROM_SYSTEM,
                                              null,
                                              system_code,
                                              MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
                                              message_buffer.data,
                                              cast(u32) message_buffer.count,
                                              null);

        if message_length {
            message_length -= ".\r\n".count;
        } else {
            format_message_error := GetLastError();

            PART_0 :: "<no message available (0x";
            memcpy(message_buffer.data, PART_0.data, PART_0.count);
            message_length = PART_0.count;

            {
                digits_count := 4 << cast(s64) (format_message_error > 0xFFFF);

                start_it := *message_buffer.data[message_length];
                end_it   := *message_buffer.data[message_length + digits_count - 1];

                digits := format_message_error;
                while digits {
                    end_it.*   = "0123456789ABCDEF"[digits & 0xF];
                    digits   >>= 4;
                    end_it    -= 1;
                }

                while end_it >= start_it {
                    end_it.*  = #char "0";
                    end_it   -= 1;
                }

                message_length += digits_count;
            }

            part_1_offset := message_length;
            PART_1 :: "): ";
            memcpy(message_buffer.data + message_length, PART_1.data, PART_1.count);
            message_length += PART_1.count;

            format_message_offset := message_length;
            message_length += FormatMessageA(FORMAT_MESSAGE_IGNORE_INSERTS | FORMAT_MESSAGE_FROM_SYSTEM,
                                             null,
                                             format_message_error,
                                             MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
                                             message_buffer.data + message_length,
                                             cast(u32) (message_buffer.count - message_length),
                                             null);

            if message_length == format_message_offset {
                message_length = part_1_offset + 1;
            } else {
                message_length -= ".\r\n".count;
            }

            message_buffer[message_length] = #char ">";
            message_length += 1;
        }
    } else {
        message_length := 0;
        notImplemented();
    }

    return .{ message_length, message_buffer.data };
}

#scope_file

MessagePriority :: enum u8 {
    VERBOSE;
    DEBUG;
    INFO;
    WARNING;
    ERROR;
    ASSERT;
    UNHANDLED_EXCEPTION;
}

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
    if !context.pet.debug.message_builder {
        context.pet.debug.message_builder = *builder;
    }
    context.pet.debug.message_recursions_count += 1;
    defer {
        context.pet.debug.message_recursions_count -= 1;
        context.pet.debug.message_builder           = null;
    }

    if !Atomics.atomic_swap(*g_mutexesInitialized, true) {
        createRecursiveMutex(*g_ioMutex);
        #if OS == .WINDOWS {
            createRecursiveMutex(*g_dbgHelpMutex);
        }
    }

    MAX_MESSAGE_RECURSIONS_COUNT : u8 : 3;
    if context.pet.debug.message_recursions_count >= MAX_MESSAGE_RECURSIONS_COUNT {
        console_handle := GetStdHandle(STD_ERROR_HANDLE);
        if console_handle != INVALID_HANDLE_VALUE {
            scopedLock(*g_ioMutex);

            SetConsoleTextAttribute(console_handle, 0x04);

            FLUSH_MESSAGES_HEADER :: "Too many recursions. Most likely you have triggered assert inside assert. Accumulated string builder content:\n==================================== BEGIN ====================================\n";
            WriteFile(console_handle, FLUSH_MESSAGES_HEADER.data, FLUSH_MESSAGES_HEADER.count, null, null);

            // We are not using Basic.builder_to_string here since it might be a crash inside an allocator,
            // so we print every chunk one by one.
            buffer := Basic.get_base_buffer(context.pet.debug.message_builder);
            while buffer {
                WriteFile(console_handle, Basic.get_buffer_data(buffer), cast(u32) buffer.count, null, null);
                buffer = buffer.next;
            }

            FLUSH_MESSAGES_FOOTER :: "\n====================================  END  ====================================\n\n";
            WriteFile(console_handle, FLUSH_MESSAGES_FOOTER.data, FLUSH_MESSAGES_FOOTER.count, null, null);

            FlushFileBuffers(console_handle);

            SetConsoleTextAttribute(console_handle, 0x07);
        }

        debugBreakIfDebugging();
        exitProcess(ifx sys_error_code then sys_error_code else 1);
    }

    Basic.print(context.pet.debug.message_builder, "[%]", priority);
    #if priority != .UNHANDLED_EXCEPTION {
        if context.pet.thread.name {
            Basic.print(context.pet.debug.message_builder, "<%>", context.pet.thread.name);
        } else {
            Basic.print(context.pet.debug.message_builder, "<kind:%,tid:%>", context.pet.thread.kind, context.thread_index);
        }
    }
    Basic.append(context.pet.debug.message_builder, ": ");

    #if priority == .ASSERT {
        absolute_path_buffer : [File.MAX_FILENAME_LENGTH + 1] u8 = ---;
        absolute_path := getAbsolutePath(*absolute_path_buffer, location.fully_pathed_filename);

        Basic.print(context.pet.debug.message_builder, "%(%,%): ", absolute_path, location.line_number, location.character_number);
    } else #if priority != .UNHANDLED_EXCEPTION {
        if custom_sys_code {
            absolute_path_buffer : [File.MAX_FILENAME_LENGTH + 1] u8 = ---;
            absolute_path := getAbsolutePath(*absolute_path_buffer, location.fully_pathed_filename);

            Basic.print(context.pet.debug.message_builder, "%(%,%): ", absolute_path, location.line_number, location.character_number);
        }
    }

    if args.count > 0 {
        #assert format.count > 0;
        Basic.print(context.pet.debug.message_builder, format, ..args);
    } else #if format.count > 0 {
        Basic.append(context.pet.debug.message_builder, format);
    } else {
        Basic.append(context.pet.debug.message_builder, "<no message>");
    }

    #if print_sys_error {
        if sys_error_code {
            minimum_digits := 4 << cast(s64) (sys_error_code > 0xFFFF);

            #if priority < .ERROR {
                Basic.print(context.pet.debug.message_builder, " has returned 0x%: ", formatHex(sys_error_code, minimum_digits));
            } else {
                Basic.print(context.pet.debug.message_builder, ". System error (0x%): ", formatHex(sys_error_code, minimum_digits));
            }

            sys_error_message_buffer : [1024] u8 = ---;
            sys_error_message := getSystemMessage(sys_error_message_buffer, sys_error_code);

            Basic.append(context.pet.debug.message_builder, sys_error_message);
        }
    }

    // Add new line if there is no any in the end
    {
        buffer := Basic.get_current_buffer(context.pet.debug.message_builder);
        data := Basic.get_buffer_data(buffer);
        if data[buffer.count - 1] != #char "\n" {
            Basic.append(context.pet.debug.message_builder, "\n");
        }
    }

    #if priority >= .ASSERT {
        Basic.append(context.pet.debug.message_builder, "\nStack trace:\n");
        if #compile_time {
            printStackTraceFromJaiContext(context.pet.debug.message_builder);
        } else #if priority == .UNHANDLED_EXCEPTION && OS == .WINDOWS {
            printStackTrace(context.pet.debug.message_builder, 9); // Skip `printStackTrace`, `message`, and some ntdll.dll and kernel32.dll functions
        } else {
            printStackTrace(context.pet.debug.message_builder, 2); // Skip `printStackTrace` and `message`
        }
    }

    message := Basic.builder_to_string(context.pet.debug.message_builder, do_reset = false,, allocator = Basic.temp);

    lock(*g_ioMutex);

    #if OS == .WINDOWS {
        #if priority != .VERBOSE && priority != .INFO {
            OutputDebugStringA(Basic.temp_c_string(message));
        }

        console_handle := INVALID_HANDLE_VALUE;
        #if priority >= .ERROR console_handle = GetStdHandle(STD_ERROR_HANDLE);
        else                   console_handle = GetStdHandle(STD_OUTPUT_HANDLE);

        if console_handle != INVALID_HANDLE_VALUE {
            console_mode : u32;
            if GetConsoleMode(console_handle, *console_mode) {
                // We do not change a color for verbose messages
                #if priority != .VERBOSE {
                         #if priority == .DEBUG   debugCheck(SetConsoleTextAttribute(console_handle, 0x09), print_sys_error = true);
                    else #if priority == .INFO    debugCheck(SetConsoleTextAttribute(console_handle, 0x0A), print_sys_error = true);
                    else #if priority == .WARNING debugCheck(SetConsoleTextAttribute(console_handle, 0x06), print_sys_error = true);
                    else #if priority >= .ERROR   debugCheck(SetConsoleTextAttribute(console_handle, 0x04), print_sys_error = true);
                    else                          #assert false "Unhandled message priority";
                }

                debugCheck(WriteFile(console_handle, message.data, cast(u32) message.count, null, null), print_sys_error = true);

                Basic.reset(context.pet.debug.message_builder);

                #if priority != .VERBOSE {
                    debugCheck(SetConsoleTextAttribute(console_handle, 0x07), print_sys_error = true);
                }
            } else {
                debugCheck(WriteFile(console_handle, message.data, cast(u32) message.count, null, null), print_sys_error = true);

                Basic.reset(context.pet.debug.message_builder);
            }
        }
    } else {
        notImplemented();
    }

    unlock(*g_ioMutex);

    #if priority == .ASSERT {
        debugBreakIfDebugging();
        exitProcess(ifx sys_error_code then sys_error_code else 1);
    }
}

// We don't use context.stack_trace since it does not track external procedures which may be essential in stack trace
printStackTrace :: (builder : *Basic.String_Builder, frames_to_skip : u32) {
    #if OS == .WINDOWS {
        MAX_FRAMES_TO_CAPTURE :: 0xFFFF;

        // We might not have per frame arena at this moment, so we use temporary storage
        stack_trace : **void = Basic.talloc(MAX_FRAMES_TO_CAPTURE * size_of(*void));

        frames_count := RtlCaptureStackBackTrace(frames_to_skip, MAX_FRAMES_TO_CAPTURE, stack_trace, null);
        assert(frames_count > 0, "RtlCaptureStackBackTrace did not capture any frames which is impossible", print_sys_error = true);

        pseudo_process_handle := GetCurrentProcess();
        process : HANDLE;
        debugCheck(DuplicateHandle(pseudo_process_handle, pseudo_process_handle, pseudo_process_handle, *process, 0, FALSE, DUPLICATE_SAME_ACCESS),
                   print_sys_error = true);
        defer debugCheck(CloseHandle(process), print_sys_error = true);

        scopedLock(*g_dbgHelpMutex);

        debugCheck(SymInitialize(process, null, TRUE), print_sys_error = true);
        defer debugCheck(SymCleanup(process), print_sys_error = true);

        line_info   := IMAGEHLP_LINE64.{ SizeOfStruct = size_of(IMAGEHLP_LINE64) };
        module_info := IMAGEHLP_MODULE64.{ SizeOfStruct = size_of(IMAGEHLP_MODULE64) };

        union {
            symbol_info_memory : [size_of(SYMBOL_INFO) + MAX_SYM_NAME] u8 #align DEFAULT_CACHE_LINE_SIZE;
            symbol_info        : SYMBOL_INFO;
        }
        symbol_info.SizeOfStruct = size_of(SYMBOL_INFO);
        symbol_info.MaxNameLen   = MAX_SYM_NAME;

        for frame : toView(stack_trace, frames_count) {
            Basic.append(builder, "    ");

            column : u32;
            if SymGetLineFromAddr64(process, cast(u64) frame, *column, *line_info) {
                Basic.print(builder, "%(%,%): ", to_string(line_info.FileName), line_info.LineNumber, column);
            } else {
                debugCheck(SymGetModuleInfo64(process, cast(u64) frame, *module_info), print_sys_error = true);

                Basic.print(builder, "%(0x%): ", to_string(module_info.LoadedImageName.data), frame);
            }

            procedure_name : string = ---;
            if SymFromAddr(process, cast(u64) frame, null, *symbol_info) {
                procedure_name.count = symbol_info.NameLen;
                procedure_name.data  = symbol_info.Name.data;
            } else {
                procedure_name = "<unknown procedure>";

                last_error := GetLastError();
                assert(last_error == ERROR_MOD_NOT_FOUND, "SymFromAddr has failed", print_sys_error = true, last_error);
            }

            Basic.print(builder, "%\n", procedure_name);
        }
    } else {
        printStackTraceFromJaiContext(builder);
    }
}

printStackTraceFromJaiContext :: (builder : *Basic.String_Builder) {
    // _STACK_TRACE is defined by the compiler based on Build_Options.stack_trace
    #if _STACK_TRACE {
        assert(context.stack_trace != null, "Stack trace is empty which is impossible");

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

#if OS == .WINDOWS {
    unhandledExceptionHandler :: (ExceptionInfo : *EXCEPTION_POINTERS) -> s32 #c_call {
        scopedLock(*g_exception_handler_context.mutex);
        push_context,defer_pop g_exception_handler_context.jai_context;

        if g_exception_handler_context.inside_exception_handler {
            return EXCEPTION_EXECUTE_HANDLER;
        }

        g_exception_handler_context.inside_exception_handler = true;
        defer g_exception_handler_context.inside_exception_handler = false;

        // _STACK_TRACE is defined by the compiler based on Build_Options.stack_trace
        #if _STACK_TRACE {
            this_frame_info := Stack_Trace_Procedure_Info.{
                name              = #procedure_name(),
                location          = #location(#this),
                procedure_address = cast(*void) #this,
            };

            this_frame := Stack_Trace_Node.{
                info        = *this_frame_info,
                line_number = cast(u32) #location(#this).line_number,
            };

            context.stack_trace = *this_frame;
        }

        // autoResetPerFrameArenas is not suittable here since g_exception_handler_context.jai_context has no arenas
        Basic.auto_release_temp();

        if ExceptionInfo.ExceptionRecord.ExceptionCode == {
            case .BREAKPOINT;
                last_error := GetLastError();

                last_error_message_buffer : [1024] u8 = ---;
                last_error_message := getSystemMessage(last_error_message_buffer, last_error);

                min_digits := 4 << cast(s64) (last_error > 0xFFFF);

                message(.UNHANDLED_EXCEPTION,
                        "Breakpoint was triggered at address 0x%.\n\nLast system error (0x%): %",
                        ExceptionInfo.ExceptionRecord.ExceptionAddress,
                        formatHex(last_error, min_digits),
                        last_error_message);

            case .ACCESS_VIOLATION;
                access_type : string;
                if ExceptionInfo.ExceptionRecord.ExceptionInformation[0] == {
                    case 0; access_type = "Read access";
                    case 1; access_type = "Write access";
                    case 8; access_type = "User-mode data execution prevention (DEP)";
                    case;   access_type = "Unknown type of access";
                }
                data_address := cast(*void) ExceptionInfo.ExceptionRecord.ExceptionInformation[1];
                message(.UNHANDLED_EXCEPTION, "% violation at address 0x%", access_type, data_address);

            case .IN_PAGE_ERROR;
                access_type : string;
                if ExceptionInfo.ExceptionRecord.ExceptionInformation[0] == {
                    case 0; access_type = "Read access";
                    case 1; access_type = "Write access";
                    case 8; access_type = "User-mode data execution prevention (DEP)";
                    case;   access_type = "Unknown type of access";
                }
                data_address := cast(*void)    ExceptionInfo.ExceptionRecord.ExceptionInformation[1];
                ntstatus     := cast(NTSTATUS) ExceptionInfo.ExceptionRecord.ExceptionInformation[2];

                ntstatus_message_buffer : [1024] u8 = ---;
                ntstatus_message := getSystemMessage(ntstatus_message_buffer, cast,no_check(u32) ntstatus);

                min_digits := 4 << cast(s64) (ntstatus > 0xFFFF);

                message(.UNHANDLED_EXCEPTION,
                        "% violation at address 0x%.\n\nThe required data was not placed into memory (0x%): %",
                        access_type,
                        data_address,
                        formatHex(ntstatus, min_digits),
                        ntstatus_message);

            case;
                exception_message_buffer : [1024] u8 = ---;
                exception_message := getSystemMessage(exception_message_buffer, cast(u32) ExceptionInfo.ExceptionRecord.ExceptionCode);

                exception_name := Reflection.enum_value_to_name(ExceptionInfo.ExceptionRecord.ExceptionCode);
                if exception_name {
                    message(.UNHANDLED_EXCEPTION,
                            "% exception was triggered at address 0x%.\n\n%",
                            exception_name,
                            ExceptionInfo.ExceptionRecord.ExceptionAddress,
                            exception_message);
                } else {
                    message(.UNHANDLED_EXCEPTION,
                            "Exception (0x%) was triggered at address 0x%.\n\n%",
                            formatHex(cast(u32) ExceptionInfo.ExceptionRecord.ExceptionCode, 8),
                            ExceptionInfo.ExceptionRecord.ExceptionAddress,
                            exception_message);
                }
        }

        return EXCEPTION_EXECUTE_HANDLER;
    }
}

g_exception_handler_context : struct {
    jai_context              : #Context;
    mutex                    : RecursiveMutex;
    temporary_storage        : Temporary_Storage;
    temporary_storage_data   : *void;
    #if OS == .WINDOWS {
        previous_handler     : TOP_LEVEL_EXCEPTION_FILTER;
    }
    inside_exception_handler : bool;
};

g_ioMutex            : RecursiveMutex;
g_mutexesInitialized : bool;
#if OS == .WINDOWS {
    g_dbgHelpMutex : RecursiveMutex; // All DbgHelp functions are single threaded, so we have to synchronize their calls
}

Program_Print :: #import "Program_Print";
Reflection    :: #import "Reflection";
Atomics       :: #import "Atomics";
