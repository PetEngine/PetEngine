#scope_export

Mutex :: struct {
    #if OS == .WINDOWS {
        srw_lock : SRWLOCK;
    }
}

lock :: (mutex : *Mutex, $shared := false) #no_context {
    #if OS == .WINDOWS {
        #if shared { AcquireSRWLockShared(*mutex.srw_lock);    }
        else       { AcquireSRWLockExclusive(*mutex.srw_lock); }
    } else {
        notImplemented();
    }
}

unlock :: (mutex : *Mutex, $shared := false) #no_context {
    #if OS == .WINDOWS {
        #if shared { ReleaseSRWLockShared(*mutex.srw_lock);    }
        else       { ReleaseSRWLockExclusive(*mutex.srw_lock); }
    } else {
        notImplemented();
    }
}

tryLock :: (mutex : *Mutex, $shared := false) -> bool #no_context {
    #if OS == .WINDOWS {
        #if shared { return cast(bool) TryAcquireSRWLockShared(*mutex.srw_lock);    }
        else       { return cast(bool) TryAcquireSRWLockExclusive(*mutex.srw_lock); }
    } else {
        notImplemented();
    }
}

scopedLock :: (mutex : *Mutex, $shared := false) #expand #no_context {
    lock(mutex, shared);
    `defer unlock(mutex, shared);
}

RecursiveMutex :: struct {
    #if OS == .WINDOWS {
        critical_section : CRITICAL_SECTION;
    }
}

createRecursiveMutex :: (mutex : *RecursiveMutex) #no_context {
    #if OS == .WINDOWS {
        InitializeCriticalSection(*mutex.critical_section);
    } else {
        notImplemented();
    }
}

destroyRecursiveMutex :: (mutex : *RecursiveMutex) #no_context {
    #if OS == .WINDOWS {
        DeleteCriticalSection(*mutex.critical_section);
    } else {
        notImplemented();
    }
}

lock :: (mutex : *RecursiveMutex) #no_context {
    #if OS == .WINDOWS {
        EnterCriticalSection(*mutex.critical_section);
    } else {
        notImplemented();
    }
}

unlock :: (mutex : *RecursiveMutex) #no_context {
    #if OS == .WINDOWS {
        LeaveCriticalSection(*mutex.critical_section);
    } else {
        notImplemented();
    }
}

tryLock :: (mutex : *RecursiveMutex) -> bool #no_context {
    #if OS == .WINDOWS {
        return cast(bool) TryEnterCriticalSection(*mutex.critical_section);
    } else {
        notImplemented();
    }
}

scopedLock :: (mutex : *RecursiveMutex) #expand #no_context {
    lock(mutex);
    `defer unlock(mutex);
}
