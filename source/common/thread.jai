#scope_export

Thread :: struct(Data : Type) {
    Procedure :: #type (data : *Data);

    #if OS == .WINDOWS {
        handle : HANDLE;
    }

    procedure : Procedure;
    data      : *Data;

    jai_context : #Context;
}

ThreadKind :: enum s8 {
    UNDEFINED :: -1;

    MAIN;
    SHADERS_HOT_RELOAD;

    // Internal
    DEVICE_MESSENGER;
}

createThread :: (thread : *Thread, procedure : thread.Procedure, data : *thread.Data, $name : string, kind : ThreadKind, stack_size := 0) {
    assert(kind != .MAIN && kind != .DEVICE_MESSENGER);

    thread.procedure = procedure;
    thread.data      = data;

    thread.jai_context.allocator       = context.allocator;
    thread.jai_context.logger          = context.logger;
    thread.jai_context.logger_data     = context.logger_data;
    thread.jai_context.print_style     = context.print_style;
    thread.jai_context.pet.thread.name = name;
    thread.jai_context.pet.thread.kind = kind;
    #Context.pet.initGlobals(*thread.jai_context);

    #if OS == .WINDOWS {
        Data :: thread.Data;

        winThreadProc :: (parameter : *void) -> u32 #c_call {
            thread : *Thread(Data) = parameter;

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

                thread.jai_context.stack_trace = *this_frame;
            }

            push_context thread.jai_context {
                threadProc(thread);
            }

            return 0;
        }

        // #CRT. thread.handle = CreateThread(null, cast(SIZE_T) stack_size, winThreadProc, thread, CREATE_SUSPENDED, null);
        thread.handle = cast(HANDLE) _beginthreadex(null, cast(u32) stack_size, winThreadProc, thread, CREATE_SUSPENDED, null);
        assert(thread.handle, print_sys_error = true);

        #if name {
            utf16_name : [name.count + 1] WCHAR = ---;
            ASCIIToUTF16(*utf16_name, name);

            debugCheckHRESULT(SetThreadDescription(thread.handle, utf16_name.data));
        }
    } else {
        notImplemented();
    }
}

closeThreadHandle :: (thread : *Thread) {
    #if OS == .WINDOWS {
        debugCheck(CloseHandle(thread.handle), print_sys_error = true);
        thread.handle = null;
    }
}

startThread :: (thread : *Thread) {
    #if OS == .WINDOWS {
        result := ResumeThread(thread.handle);
        assert(result != 0xFFFF_FFFF, print_sys_error = true);
    } else {
        notImplemented();
    }
}

pauseThread :: (thread : *Thread) {
    #if OS == .WINDOWS {
        result := SuspendThread(thread.handle);
        assert(result != 0xFFFF_FFFF, print_sys_error = true);
    } else {
        notImplemented();
    }
}

waitThread :: (thread : *Thread, milliseconds : u32 = 0xFFFF_FFFF, alertable := false) -> bool {
    signaled : bool;

    #if OS == .WINDOWS {
        wait_result := WaitForSingleObjectEx(thread.handle, milliseconds, cast(BOOL) alertable);
        assert(wait_result == WAIT_OBJECT_0 || wait_result == WAIT_TIMEOUT, print_sys_error = true);

        signaled = wait_result == WAIT_OBJECT_0;
    } else {
        notImplemented();
    }

    return signaled;
}

exitThread :: (exit_code : u32 = 0xFFFF_FFFF) {
    #if OS == .WINDOWS {
        if exit_code == 0xFFFF_FFFF {
            exit_code = GetLastError();
        }
        _endthreadex(exit_code); // #CRT.
    } else {
        notImplemented();
    }
}

exitProcess :: (exit_code : u32 = 0xFFFF_FFFF) #no_context {
    #if OS == .WINDOWS {
        if exit_code == 0xFFFF_FFFF {
            exit_code = GetLastError();
        }
    } else {
        if exit_code == 0xFFFF_FFFF {
            exit_code = errno;
        }
    }

    exit(cast,no_check(s32) exit_code); // #CRT.
}

getNextThreadIndex :: inline () -> u32 #no_context {
    thread_index : u32 = 1;
    next_thread_index := *g_next_thread_index;
    #if CPU == .X64 {
        #asm { lock_xadd.d [next_thread_index], thread_index; }
    } else {
        notImplemented();
    }
    return thread_index;
}

#scope_file

threadProc :: no_inline (thread : *Thread) {
    context.thread_index = getNextThreadIndex();

    context.allocator.proc(.THREAD_START, 0, 0, null, context.allocator.data);
    defer context.allocator.proc(.THREAD_STOP, 0, 0, null, context.allocator.data);

    temporary_storage : Temporary_Storage;
    context.temporary_storage = *temporary_storage;

    // TEMPORARY_STORAGE_SIZE is defined by the compiler based on Build_Options.temporary_storage_size
    temporary_storage_data := Allocator.rpaligned_alloc(DEFAULT_CACHE_LINE_SIZE, TEMPORARY_STORAGE_SIZE);
    defer Allocator.rpfree(temporary_storage_data);

    set_initial_data(context.temporary_storage, TEMPORARY_STORAGE_SIZE, temporary_storage_data);

    // @Continue: #Settings. Settings are in different module
    //     readSetting("arenas.persistent_capacity")
    //     readSetting("arenas.per_frame_capacity")
    createArena(*context.pet.arenas.persistent, gigaBytes(1), "Persistent");
    defer destroyArena(*context.pet.arenas.persistent);

    createArena(*context.pet.arenas.per_frame, megaBytes(512), "Per frame");
    defer destroyArena(*context.pet.arenas.per_frame);

    thread.procedure(thread.data);
}

g_next_thread_index : u32 = 1;

exit :: (status: s32) #foreign libc_or_crt;

#if OS == .WINDOWS {
    _beginthreadex :: (
        security      : *SECURITY_ATTRIBUTES,
        stack_size    : u32,
        start_address : THREAD_START_ROUTINE,
        arglist       : *void,
        initflag      : u32,
        thrdaddr      : *u32
    ) -> u64 #foreign libc_or_crt;

    _endthreadex :: (
       retval : u32
    ) #foreign libc_or_crt;

    libc_or_crt :: #library,system "msvcrt";
} else {
    libc_or_crt :: #library,system "libc";
}
