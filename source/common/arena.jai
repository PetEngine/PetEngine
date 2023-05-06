#scope_export

Arena :: struct {
    memory   : *void;
    occupied : s64;
    capacity : s64;
    marker   : s64;
    name     : string;
}

createArena :: (arena : *Arena, capacity : s64, name : string) {
    assert(capacity > 0);

    arena.name = name;

    #if OS == .WINDOWS {
        system_info : SYSTEM_INFO = ---;
        GetSystemInfo(*system_info);

        page_size : s64 = system_info.dwPageSize;
    } else {
        page_size : s64 = 4096;
        notImplemented();
    }

    arena.capacity = alignUpWithPowerOfTwo(capacity, page_size);
    if arena.capacity != capacity {
        warningMessage("\"%\" arena will be created with different capacity since given capacity does not match system page size alignment requirement. Given capacity: % bytes, aligned capacity: % byte, page size: % bytes",
                       arena.name,
                       Basic.formatInt(capacity,           digits_per_comma = 3, comma_string = "'"),
                       Basic.formatInt(arena.capacity, digits_per_comma = 3, comma_string = "'"),
                       page_size);
    }

    #if OS == .WINDOWS {
        // @TODO: MEM_LARGE_PAGES?
        arena.memory = VirtualAlloc(null, cast(SIZE_T) arena.capacity, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    } else {
        notImplemented();
    }

    assert(arena.memory != null);
}

destroyArena :: (arena : *Arena) {
    assert(arena.memory != null, "Initialize arena first");

    #if OS == .WINDOWS {
        result := VirtualFree(arena.memory, 0, MEM_DECOMMIT);
    } else {
        notImplemented();
    }

    assert(result != FALSE);

    arena.memory   = null;
    arena.occupied = 0;
    arena.capacity = 0;
    arena.marker   = 0;
}

pushToArena :: (arena : *Arena, bytes : s64) -> *void #must {
    assert(arena.memory && arena.capacity, "Initialize arena first");
    assert(bytes > 0, "There is no sense in allocating <= 0 bytes");

    assert(arena.occupied + bytes < arena.capacity,
           "There is no enogh space in \"%\" arena for % bytes. Occupied: % bytes, capacity: % bytes",
           arena.name, bytes, arena.occupied, arena.capacity);

    pointer := arena.memory + arena.occupied;
    arena.occupied += bytes;

    return pointer;
}

pushToArena :: inline (arena : *Arena, $type : Type, $$count : s64 = 1) -> *type #must {
    memory := pushToArena(arena, size_of(type) * count);

    init :: initializer_of(type);
    #if init {
        for 0..count-1 {
            init(memory + it);
        }
    }

    return memory;
}

resetArena :: inline (arena : *Arena, $zero_memory := true) {
    #if zero_memory {
        memset(arena.memory, 0, arena.occupied);
    }

    arena.occupied = 0;
    arena.marker   = 0;
}

resetArenaToMarker :: inline (arena : *Arena, $zero_memory := true) {
    #if zero_memory {
        memset(arena.memory + arena.marker, 0, arena.occupied - arena.marker);
    }

    arena.occupied = arena.marker;
}

setMarkerInArena :: inline (arena : *Arena) {
    arena.marker = arena.occupied;
}
