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

scopedLock :: (mutex : *Mutex) #expand {
    lock(mutex);
    `defer unlock(mutex);
}
