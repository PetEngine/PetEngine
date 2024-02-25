#scope_export

// @TODO:
//     1. Place arena name in front of arena itself:
//              memory   = [name|memory]
//              capacity = name.count + capacity

Arena :: struct {
    memory       : *void;
    occupied     : s64;
    capacity     : s64;
    marker       : s64;
    name         : string;
#if DEBUG_BUILD {
    max_occupied : s64;
}
}

createArena :: (arena : *Arena, capacity : s64, $format : string, args : ..Any) {
    assert(capacity > 0);

    builder : Basic.String_Builder;
    builder.allocator = Basic.temp;

    Basic.print(*builder, "% thread ", context.pet.thread_name);
    Basic.print(*builder, format, ..args);
    arena.name = Basic.builder_to_string(*builder); // We need to preserve it, so do not use Basic.temp

    #if OS == .WINDOWS {
        system_info : SYSTEM_INFO = ---;
        GetSystemInfo(*system_info);

        page_size              : s64 = system_info.dwPageSize;
        allocation_granularity : s64 = system_info.dwAllocationGranularity;
    } else {
        page_size              : s64 : 4096;
        allocation_granularity : s64 : 4096;
        notImplemented();
    }

    arena.capacity = alignUpWithPowerOfTwo(capacity, page_size);
    arena.capacity = alignUpWithPowerOfTwo(arena.capacity, allocation_granularity);
    if arena.capacity != capacity {
        warningMessage("\"%\" arena will be created with different capacity since given capacity does not match system page size and allocation granularity alignment requirement. Given capacity: % bytes, aligned capacity: % byte, page size: % bytes, allocation granularity: % bytes",
                       arena.name,
                       Basic.formatInt(capacity,       digits_per_comma = 3, comma_string = "'"),
                       Basic.formatInt(arena.capacity, digits_per_comma = 3, comma_string = "'"),
                       page_size,
                       allocation_granularity);
    }

    #if OS == .WINDOWS {
        // @TODO: MEM_LARGE_PAGES?
        arena.memory = VirtualAlloc(null, cast(SIZE_T) arena.capacity, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    } else {
        notImplemented();
    }

    assert(arena.memory != null, print_sys_error = true);
}

createSubarena :: (arena : *Arena, subarena : *Arena, subarena_capacity : s64, $format : string, args : ..Any) {
    builder : Basic.String_Builder;
    builder.allocator = Basic.temp;

    Basic.print(*builder, "% arena / ", arena.name);
    Basic.print(*builder, format, ..args);
    subarena.name = Basic.builder_to_string(*builder); // We need to preserve it, so do not use Basic.temp

    subarena.memory   = pushToArena(arena, subarena_capacity);
    subarena.capacity = subarena_capacity;
}

destroyArena :: (arena : *Arena) {
    assert(arena.memory != null, "Initialize arena first");

    #if OS == .WINDOWS {
        debugCheck(VirtualFree(arena.memory, 0, MEM_DECOMMIT), print_sys_error = true);
    } else {
        notImplemented();
    }

    #if DEBUG_BUILD {
        debugMessage("% arena: max occupied bytes: % / %", arena.name, arena.max_occupied, arena.capacity);
        arena.max_occupied = 0;
    }

    Basic.free(arena.name);

    memset(arena, 0, size_of(Arena));
}

destroySubarena :: (subarena : *Arena) {
    assert(subarena.memory != null, "Initialize subarena first");

    #if DEBUG_BUILD {
        debugMessage("% subarena: max occupied bytes: % / %", subarena.name, subarena.max_occupied, subarena.capacity);
        subarena.max_occupied = 0;
    }

    Basic.free(subarena.name);

    memset(subarena, 0, size_of(Arena));
}

pushToArena :: (arena : *Arena, bytes : s64) -> *void #must {
    assert(arena.memory && arena.capacity, "Initialize arena first");
    assert(bytes > 0, "There is no sense in allocating <= 0 bytes");

    assert(arena.occupied + bytes <= arena.capacity,
           "There is no enough space in \"%\" arena for % bytes. Occupied: % bytes, capacity: % bytes",
           arena.name, bytes, arena.occupied, arena.capacity);

    pointer := arena.memory + arena.occupied;
    arena.occupied += bytes;

    #if DEBUG_BUILD {
        if arena.occupied > arena.max_occupied {
            arena.max_occupied = arena.occupied;
        }
    }

    return pointer;
}

pushToArena :: inline (arena : *Arena, $type : Type, count := 1) -> *type #must {
    memory : *type = pushToArena(arena, size_of(type) * count);

    init :: initializer_of(type);
    #if init {
        for 0 .. count - 1 {
            init(memory + it);
        }
    }

    return memory;
}

Align :: enum_flags u8 {
    SIZE;
    ADDRESS;

    ALL :: SIZE | ADDRESS;
}

pushToArenaAligned :: (arena : *Arena, bytes : s64, alignment : s64, $align : Align) -> *void #must {
    #assert align != 0 "If you do not want to align anything, then just use pushToArena function";

    assert(arena.memory && arena.capacity, "Initialize arena first");
    assert(bytes > 0, "There is no sense in allocating <= 0 bytes");

    #if align & .SIZE {
        aligned_bytes := alignUpWithPowerOfTwo(bytes, alignment);
    } else {
        aligned_bytes := bytes;
    }

    #if align & .ADDRESS {
        aligned_offset := alignUpWithPowerOfTwo(arena.occupied, alignment);
    } else {
        aligned_offset := arena.occupied;
    }

    assert(aligned_offset + aligned_bytes < arena.capacity,
           "There is not enough space in \"%\" arena for % bytes. Occupied: % bytes, capacity: % bytes",
           arena.name, aligned_bytes, aligned_offset, arena.capacity);

    pointer := arena.memory + aligned_offset;
    arena.occupied = aligned_offset + aligned_bytes;

    #if DEBUG_BUILD {
        if arena.occupied > arena.max_occupied {
            arena.max_occupied = arena.occupied;
        }
    }

    return pointer;
}

resetArena :: inline (arena : *Arena, $zero_memory := true) #no_context {
    #if zero_memory {
        memset(arena.memory, 0, arena.occupied);
    }

    arena.occupied = 0;
    arena.marker   = 0;
}

resetArenaToMarker :: inline (arena : *Arena, $zero_memory := true) #no_context {
    #if zero_memory {
        memset(arena.memory + arena.marker, 0, arena.occupied - arena.marker);
    }

    arena.occupied = arena.marker;
}

setArenaMarker :: inline (arena : *Arena) #no_context {
    arena.marker = arena.occupied;
}
