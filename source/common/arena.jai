#scope_export

Arena :: struct {
    memory       : *void;
    occupied     : s64;
    capacity     : s64;
    name         : string;
#if DEBUG_BUILD {
    max_occupied : s64;
}
}

createArena :: (arena : *Arena, capacity : s64, $format : string, args : ..Any, alignment := 0) {
    assert(capacity > 0);

    builder := Basic.String_Builder.{ allocator = Basic.temp };

    Basic.print(*builder, "% thread/", context.pet.thread_name);
    Basic.print(*builder, format, ..args);
    Basic.append(*builder, " arena");

    // We need to preserve it, so do not use Basic.temp
    arena.name = Basic.builder_to_string(*builder);

    #if OS == .WINDOWS {
        system_info : SYSTEM_INFO = ---;
        GetNativeSystemInfo(*system_info);

        page_size : s64 = system_info.dwPageSize;
    } else {
        page_size : s64 : 4096;
        notImplemented();
    }

CAPACITY_WARNING_STRING :: #string END
"%" will be created with different capacity because given capacity does not match system page size alignment requirement.
    Given capacity:   % bytes (% KB, % MB, % GB)
    Aligned capacity: % bytes (% KB, % MB, % GB)
    System page size: % bytes (% KB, % MB)
END;

    arena.capacity = alignUpWithPowerOfTwo(capacity, page_size);
    if arena.capacity != capacity {
        warningMessage(CAPACITY_WARNING_STRING,
                       arena.name,
                       capacity,       bytesToKiloBytes(capacity),       bytesToMegaBytes(capacity),       bytesToGigaBytes(capacity),
                       arena.capacity, bytesToKiloBytes(arena.capacity), bytesToMegaBytes(arena.capacity), bytesToGigaBytes(arena.capacity),
                       page_size,      bytesToKiloBytes(page_size),      bytesToMegaBytes(page_size));
    }

    #if OS == .WINDOWS {
        // @TODO: MEM_LARGE_PAGES?
        if alignment > 0 {
            assert(isPowerOfTwo(alignment));

            mem_address_requirements := MEM_ADDRESS_REQUIREMENTS.{
                Alignment = cast(SIZE_T) alignment
            };

            mem_extended_parameter := MEM_EXTENDED_PARAMETER.{
                Type    = cast(u64) MEM_EXTENDED_PARAMETER_TYPE.MemExtendedParameterAddressRequirements,
                Pointer = *mem_address_requirements
            };

            arena.memory = VirtualAlloc2FromApp(null, null, cast(SIZE_T) arena.capacity, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE, *mem_extended_parameter, 1);
        } else {
            arena.memory = VirtualAllocFromApp(null, cast(SIZE_T) arena.capacity, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
        }
    } else {
        notImplemented();
    }

    assert(arena.memory, print_sys_error = true);
}

createSubarena :: (arena : *Arena, subarena : *Arena, subarena_capacity : s64, $format : string, args : ..Any, alignment := 0) {
    builder := Basic.String_Builder.{ allocator = Basic.temp };

    Basic.print(*builder, "%/", arena.name);
    Basic.print(*builder, format, ..args);
    Basic.append(*builder, " subarena");

    // We need to preserve it, so do not use Basic.temp
    subarena.name = Basic.builder_to_string(*builder);

    subarena.memory   = pushToArena(arena, subarena_capacity, alignment);
    subarena.capacity = subarena_capacity;
}

destroyArena :: (arena : *Arena) {
    assert(arena.memory, "Create arena first");

    #if OS == .WINDOWS {
        debugCheck(VirtualFree(arena.memory, 0, MEM_DECOMMIT), print_sys_error = true);
    } else {
        notImplemented();
    }

    #if DEBUG_BUILD {
        debugMessage("%: max occupied bytes: % / %", arena.name, arena.max_occupied, arena.capacity);
    }

    Basic.free(arena.name);
    memset(arena, 0, size_of(Arena));
}

destroySubarena :: (subarena : *Arena) {
    assert(subarena.memory, "Create subarena first");

    #if DEBUG_BUILD {
        debugMessage("%: max occupied bytes: % / %", subarena.name, subarena.max_occupied, subarena.capacity);
    }

    Basic.free(subarena.name);
    memset(subarena, 0, size_of(Arena));
}

pushToArena :: (arena : *Arena, bytes : s64, alignment := 0) -> *void #must {
    assert(arena.memory && arena.capacity, "Create arena first");
    assert(bytes > 0, "There is no sense in allocating <= 0 bytes");

    aligned_address := arena.memory + arena.occupied;
    if alignment > 0 {
        aligned_address = cast(*void) alignUpWithPowerOfTwo(cast(u64) aligned_address, cast(u64) alignment);
    }

    assert(aligned_address + bytes <= arena.memory + arena.capacity,
           "There is no enough space in \"%\" arena for % bytes. Aligned offset: % bytes, capacity: % bytes",
           arena.name,
           bytes,
           aligned_address - arena.memory,
           arena.capacity);

    arena.occupied = aligned_address + bytes - arena.memory;

    #if DEBUG_BUILD {
        if arena.occupied > arena.max_occupied {
            arena.max_occupied = arena.occupied;
        }
    }

    return aligned_address;
}

pushToArena :: inline (arena : *Arena, $type : Type, count := 1, alignment := 0) -> *type #must {
    memory : *type = pushToArena(arena, size_of(type) * count, alignment);

    init :: initializer_of(type);
    #if init {
        memory_it := memory;
        for 0 .. count - 1 {
            init(memory_it);
            memory_it += 1;
        }
    }

    return memory;
}

resetArena :: (arena : *Arena, $zero_memory := true) {
    assert(arena.memory, "Create arena first");

    #if zero_memory {
        memset(arena.memory, 0, arena.occupied);
    }

    arena.occupied = 0;
}

autoResetArenaScopeUsage :: (arena : *Arena, $zero_memory := true) #expand {
    __arena_marker := arena.occupied;
    `defer resetArenaToMarker(arena, __arena_marker, zero_memory);
}

#scope_file

resetArenaToMarker :: (arena : *Arena, marker : s64, $zero_memory := true) {
    assert(arena.memory, "Create arena first");

    #if zero_memory {
        memset(arena.memory + marker, 0, arena.occupied - marker);
    }

    arena.occupied = marker;
}
