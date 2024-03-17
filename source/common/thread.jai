#scope_export

Thread :: struct(Data : Type) {
    Procedure :: #type (data : *Data);

    #if OS == .WINDOWS {
        handle : HANDLE;
    }

    procedure : Procedure;
    data      : *Data;

    jai_context : Context;
}

ThreadKind :: enum u8 {
    MAIN;
    SHADERS_HOT_RELOAD;
}

createThread :: (thread : *Thread, procedure : thread.Procedure, data : *thread.Data, $name : string, kind : ThreadKind, stack_size := 0) {
    thread.procedure = procedure;
    thread.data      = data;

    thread.jai_context.allocator       = context.allocator;
    thread.jai_context.logger          = context.logger;
    thread.jai_context.logger_data     = context.logger_data;
    thread.jai_context.print_style     = context.print_style;
    thread.jai_context.pet.thread_name = name;
    thread.jai_context.pet.thread_kind = kind;

    #if OS == .WINDOWS {
        Data :: thread.Data;

        winThreadProc :: (parameter : *void) -> u32 #c_call {
            thread : *Thread(Data) = parameter;
            push_context thread.jai_context {
                threadProc(thread);
            }
            return 0;
        }

        // thread.handle = CreateThread(null, cast(SIZE_T) stack_size, winThreadProc, thread, CREATE_SUSPENDED, null);
        thread.handle = cast(HANDLE) _beginthreadex(null, cast(u32) stack_size, winThreadProc, thread, CREATE_SUSPENDED, null);
        assert(thread.handle, print_sys_error = true);

        #if name {
            wide_name : [name.count + 1] WCHAR = ---;
            asciiToWide(*wide_name, name, true);

            debugCheckHRESULT(SetThreadDescription(thread.handle, wide_name.data));
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

exitThread :: (exit_code : u32 = 0) {
    #if OS == .WINDOWS {
        if exit_code == 0xFFFF_FFFF {
            exit_code = GetLastError();
        }
        _endthreadex(exit_code);
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

    exit(cast,no_check(s32) exit_code);
}

#scope_file

threadProc :: no_inline (thread : *Thread) {
    context.base.context_info = type_info(Context);
    context.thread_index      = getThreadIndex();

    context.allocator.proc(.THREAD_START, 0, 0, null, context.allocator.data);
    defer context.allocator.proc(.THREAD_STOP, 0, 0, null, context.allocator.data);

    temporary_storage : Temporary_Storage;
    context.temporary_storage = *temporary_storage;

    // TEMPORARY_STORAGE_SIZE is defined by the compiler based on Build_Options.temporary_storage_size
    temporary_storage_data : [TEMPORARY_STORAGE_SIZE] u8 #align 64;
    set_initial_data(context.temporary_storage, TEMPORARY_STORAGE_SIZE, temporary_storage_data.data);
    context.temporary_storage.current_page_bytes_occupied = 0;
    context.temporary_storage.total_bytes_occupied        = 0;
    context.temporary_storage.high_water_mark             = 0;

    // @TODO: #Settings. Get persistent arena capacity from settings.
    createArena(*context.pet.persistent_arena, gigaBytes(1), "Persistent");
    defer destroyArena(*context.pet.persistent_arena);

    // @TODO: #Settings. Get per frame arena capacity from settings.
    createArena(*context.pet.per_frame_arena, megaBytes(512), "Per frame");
    defer destroyArena(*context.pet.per_frame_arena);

    thread.procedure(thread.data);
}

g_next_thread_index : u32 = 1;
getThreadIndex :: inline () -> u32 #no_context {
    thread_index : u32 = 1;
    next_thread_index := *g_next_thread_index;
    #if CPU == .X64 {
        #asm { lock_xadd [next_thread_index], thread_index; }
    } else {
        notImplemented();
    }
    return thread_index;
}

exit :: (status: s32) #foreign libc_or_crt;

#if OS == .WINDOWS {
    _beginthreadex :: (
        security      : *void,
        stack_size    : u32,
        start_address : (arg : *void) -> u32 #c_call,
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
