#scope_export

// @TODO: #Arena.
//     - MEM_LARGE_PAGES?

Arena :: struct {
    memory       : *void;
    occupied     : s64;
    capacity     : s64;
#if DEBUG_BUILD {
    max_occupied : s64;
}
    name         : string;
    name_memory  : [128] u8;
}

createArena :: (arena : *Arena, capacity : s64, $format : string, args : ..Any, alignment := 0) {
    assert(capacity > 0);

    // Make a name
    {
        builder := Basic.String_Builder.{ allocator = Basic.temp };
        defer Basic.free_buffers(*builder);

        Basic.print(*builder, "% thread/", context.pet.thread.name);
        Basic.print(*builder, format, ..args);
        Basic.append(*builder, " arena");

        arena.name.data  = arena.name_memory.data;
        arena.name.count = 0;

        buffer  := Basic.get_base_buffer(*builder);
        data_it := arena.name.data;
        while buffer {
            assert(arena.name.count + buffer.count <= arena.name_memory.count,
                   "Arena name is too long, consider increasing Arena.name_memory");

            memcpy(data_it, Basic.get_buffer_data(buffer), buffer.count);
            data_it += buffer.count;

            arena.name.count += buffer.count;

            buffer = buffer.next;
        }
    }

    #if OS == .WINDOWS {
        system_info : SYSTEM_INFO = ---;
        GetNativeSystemInfo(*system_info);

        page_size              : s64 = system_info.dwPageSize;
        allocation_granularity : s64 = system_info.dwAllocationGranularity;
    } else {
        page_size : s64 : DEFAULT_PAGE_SIZE; // On Linux allocation_granularity == page_size
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

ALIGNMENT_WARNING_STRING :: #string END
Alignment for "%" will be ignored since it is not multiple of system allocation granularity.
    Alignment:              % bytes (% KB, % MB)
    Allocation granularity: % bytes (% KB, % MB)
END;

    #if OS == .WINDOWS {
        allocation_type := MEM_COMMIT | MEM_RESERVE;
        if !(arena.capacity & 0xFFFF) {
            allocation_type |= MEM_64K_PAGES;
        }

        if alignment > 1 {
            assert(isPowerOfTwo(alignment));
            assert(isPowerOfTwo(allocation_granularity));

            if !(alignment & (allocation_granularity - 1)) {
                if alignment & 0xFFFF {
                    allocation_type &= ~MEM_64K_PAGES;
                }

                mem_address_requirements := MEM_ADDRESS_REQUIREMENTS.{
                    Alignment = cast(SIZE_T) alignment
                };

                mem_extended_parameter := MEM_EXTENDED_PARAMETER.{
                    Type    = cast(u64) MEM_EXTENDED_PARAMETER_TYPE.MemExtendedParameterAddressRequirements,
                    Pointer = *mem_address_requirements
                };

                arena.memory = VirtualAlloc2(null, null, cast(SIZE_T) arena.capacity, allocation_type, PAGE_READWRITE, *mem_extended_parameter, 1);
            } else {
                warningMessage(ALIGNMENT_WARNING_STRING,
                               arena.name,
                               alignment,
                               bytesToKiloBytes(alignment),
                               bytesToMegaBytes(alignment),
                               allocation_granularity,
                               bytesToKiloBytes(allocation_granularity),
                               bytesToMegaBytes(allocation_granularity));

               arena.memory = VirtualAlloc(null, cast(SIZE_T) arena.capacity, allocation_type, PAGE_READWRITE);
            }
        } else {
            arena.memory = VirtualAlloc(null, cast(SIZE_T) arena.capacity, allocation_type, PAGE_READWRITE);
        }
    } else {
        notImplemented();
    }

    assert(arena.memory, print_sys_error = true);
}

createSubarena :: (arena : *Arena, subarena : *Arena, subarena_capacity : s64, $format : string, args : ..Any, alignment := 0) {
    // Make a name
    {
        builder := Basic.String_Builder.{ allocator = Basic.temp };
        defer Basic.free_buffers(*builder);

        Basic.print(*builder, "%/", arena.name);
        Basic.print(*builder, format, ..args);
        Basic.append(*builder, " subarena");

        subarena.name.data  = subarena.name_memory.data;
        subarena.name.count = 0;

        buffer  := Basic.get_base_buffer(*builder);
        data_it := subarena.name.data;
        while buffer {
            assert(subarena.name.count + buffer.count <= subarena.name_memory.count,
                   "Arena name is too long, consider increasing Arena.name_memory");

            memcpy(data_it, Basic.get_buffer_data(buffer), buffer.count);
            data_it += buffer.count;

            subarena.name.count += buffer.count;

            buffer = buffer.next;
        }
    }

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

    memset(arena, 0, size_of(Arena));
}

destroySubarena :: (subarena : *Arena) {
    assert(subarena.memory, "Create subarena first");

    #if DEBUG_BUILD {
        debugMessage("%: max occupied bytes: % / %", subarena.name, subarena.max_occupied, subarena.capacity);
    }

    memset(subarena, 0, size_of(Arena));
}

pushToArena :: (arena : *Arena, bytes : s64, alignment := DEFAULT_ALIGNMENT) -> *void #must {
    assert(arena.memory && arena.capacity, "Create arena first");
    assert(bytes > 0, "There is no sense in allocating <= 0 bytes");

    aligned_address := arena.memory + arena.occupied;
    if alignment > 1 {
        aligned_address = alignUpWithPowerOfTwo(aligned_address, alignment);
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

pushToArena :: (arena : *Arena, $type : Type, count := 1, alignment := 0) -> *type #must {
    memory : *type = ---;

    // @Important: Some WinAPI functions (CreateWindowExW for instance) fail
    //             if an address of a UTF-16 string is not aligned to size_of(WCHAR),
    //             so we have to take into account the alignment of the type
    //
    // This is the only way I figured out to get a type info of 'type'...
    ALIGNMENT_OF_TYPE :: #run alignmentOf(type_info(type_of(*memory)));

    if !alignment {
        alignment = ALIGNMENT_OF_TYPE;
    } else {
        assert(!(alignment % ALIGNMENT_OF_TYPE),
               "alignment should be multiple of alignment of the type: %. Given alignment: %",
               ALIGNMENT_OF_TYPE,
               alignment);
    }

    memory = pushToArena(arena, size_of(type) * count, alignment);

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

autoResetArena :: (arena : *Arena, $zero_memory := true) #expand {
    __arena_marker := arena.occupied;
    `defer resetArenaToMarker(arena, __arena_marker, zero_memory);
}

autoResetPerFrameArenas :: ($zero_memory := true, location := #caller_location) #expand {
    __arena_marker := context.pet.arenas.per_frame.occupied;
    __temp_marker  := Basic.get_temporary_storage_mark();

    `defer {
        resetArenaToMarker(*context.pet.arenas.per_frame, __arena_marker, zero_memory);
        Basic.set_temporary_storage_mark(__temp_marker, location);
    }
}

#scope_file

resetArenaToMarker :: (arena : *Arena, marker : s64, $zero_memory := true) {
    assert(arena.memory, "Create arena first");

    #if zero_memory {
        memset(arena.memory + marker, 0, arena.occupied - marker);
    }

    arena.occupied = marker;
}

// Seems legit for most ABIs
alignmentOf :: (info : *Type_Info) -> s64 #compile_time {
    assert(#compile_time, "This function should be run only in compile time"); // @Cleanup: #CompileTime.

    type := Compiler.get_type(info);

    is_variant : bool;
    while info.type == .VARIANT {
        info       = (cast(*Type_Info_Variant) info).variant_of;
        is_variant = true;
    }

    if info.type == {
        case .INTEGER; #through;
        case .FLOAT;   #through;
        case .ENUM;
            if info.runtime_size != 1 && info.runtime_size != 2 && info.runtime_size != 4 && info.runtime_size != 8 {
                if is_variant {
                    assertMessage("Unexpected % size: %. Type: %, variant of type: %",
                                  info.type,
                                  info.runtime_size,
                                  type,
                                  Compiler.get_type(info));
                } else {
                    assertMessage("Unexpected % size: %. Type: %", info.type, info.runtime_size, type);
                }
            }

            return info.runtime_size;

        case .BOOL;
            return size_of(bool);

        case .STRING;
            return alignmentOf(type_info(Newstring));

        case .POINTER;      #through;
        case .PROCEDURE;    #through;
        case .OVERLOAD_SET; // I have no idea what it is, but it seems like this is the type for some kind of procedure
            return size_of(*void);

        case .ANY;
            return alignmentOf(type_info(Any_Struct));

        case .VOID;
            assertMessage("void has no size and no alignment");
            return 1; // Or 0?

        case .STRUCT;
            max_primitive_alignment := 1;

            info_struct := cast(*Type_Info_Struct) info;
            for info_struct.members {
                max_primitive_alignment = max(max_primitive_alignment, alignmentOf(it.type));
            }

            return max_primitive_alignment;

        case .ARRAY;
            info_array := cast(*Type_Info_Array) info;
            if #complete info_array.array_type == {
                case .FIXED;
                    return alignmentOf(info_array.element_type);

                case .VIEW;
                    return alignmentOf(type_info(Array_View_64));

                case .RESIZABLE;
                    return alignmentOf(type_info(Resizable_Array));
            }
    }

    if is_variant {
        assertMessage("Unexpected type: %, variant of type: %. Info: %", type, Compiler.get_type(info), info.*);
    } else {
        assertMessage("Unexpected type: %. Info: %", type, info.*);
    }

    return 1;
}
