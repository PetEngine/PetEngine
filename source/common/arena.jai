#scope_export

Arena :: struct {
    MEMORY_IS_ALLOCATED_FLAG : u64 : 0x8000_0000_0000_0000;
    MEMORY_ADDRESS_MASK      : u64 : MEMORY_IS_ALLOCATED_FLAG - 1;

    memory       : *void;
    occupied     : s64;
    capacity     : s64;
#if DEBUG_BUILD {
    max_occupied : s64;
}
    name         : string;
    name_memory  : [128] u8;
}

createArena :: (arena : *Arena, capacity : s64, $format : string, args : ..Any, alignment := DEFAULT_PAGE_SIZE) {
    assert(capacity > 0);

    memory := Allocator.rpaligned_alloc(alignment, capacity);
    assert(memory, print_sys_error = true);

    createArena(arena, memory, capacity, format, ..args);
    arena.memory |= Arena.MEMORY_IS_ALLOCATED_FLAG;
}

createArena :: (arena : *Arena, memory : *void, capacity : s64, $format : string, args : ..Any) {
    assert(memory);
    assert(capacity > 0);

    arena.memory   = memory;
    arena.occupied = 0;
    arena.capacity = capacity;

    #if DEBUG_BUILD {
        arena.max_occupied = 0;
    }

    makeArenaName(arena, format, ..args);
}

destroyArena :: (arena : *Arena) {
    if arena.memory & Arena.MEMORY_IS_ALLOCATED_FLAG {
        Allocator.rpfree(arena.memory & Arena.MEMORY_ADDRESS_MASK);
    }

    #if DEBUG_BUILD {
        debugMessage("%: max occupied bytes: % / %", arena.name, arena.max_occupied, arena.capacity);
    }

    memset(arena, 0, size_of(Arena));
}

createSubarena :: (arena : *Arena, subarena : *Arena, subarena_capacity : s64, $format : string, args : ..Any, alignment := 0) {
    makeSubarenaName(subarena, arena.*, format, ..args);

    subarena.memory   = pushToArena(arena, subarena_capacity, alignment);
    subarena.occupied = 0;
    subarena.capacity = subarena_capacity;

    #if DEBUG_BUILD {
        subarena.max_occupied = 0;
    }
}

pushToArena :: (arena : *Arena, bytes : s64, alignment := DEFAULT_ALIGNMENT) -> *void {
    assert(bytes > 0, "There is no sense in allocating <= 0 bytes");

    memory := arena.memory & Arena.MEMORY_ADDRESS_MASK;

    aligned_address := memory + arena.occupied;
    if alignment > 1 {
        aligned_address = alignUpWithPowerOfTwo(aligned_address, alignment);
    }

    assert(aligned_address + bytes <= memory + arena.capacity,
           "There is no enough space in \"%\" arena for % bytes. Aligned offset: % bytes, capacity: % bytes",
           arena.name,
           bytes,
           aligned_address - memory,
           arena.capacity);

    arena.occupied = aligned_address + bytes - memory;

    #if DEBUG_BUILD {
        if arena.occupied > arena.max_occupied {
            arena.max_occupied = arena.occupied;
        }
    }

    // @Speed: Add argument $zero_memory := true
    memset(aligned_address, 0, bytes);

    return aligned_address;
}

pushToArena :: (arena : *Arena, $type : Type, count := 1, alignment := 0) -> *type {
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

resetArena :: (arena : *Arena, to_offset := 0, $zero_memory := true) {
    #if zero_memory {
        memory := arena.memory & Arena.MEMORY_ADDRESS_MASK;
        memset(memory + to_offset, 0, arena.occupied - to_offset);
    }
    arena.occupied = to_offset;
}

autoResetArena :: (arena : *Arena, $zero_memory := true) #expand {
    __arena_marker := arena.occupied;
    `defer resetArena(arena, __arena_marker, zero_memory);
}

autoResetPerFrameArenas :: ($zero_memory := true, location := #caller_location) #expand {
    auto_reset_arena_offset   := context.pet.arenas.per_frame.occupied;
    auto_reset_storage_marker := Basic.get_temporary_storage_mark();

    `defer {
        resetArena(*context.pet.arenas.per_frame, auto_reset_arena_offset, zero_memory);
        Basic.set_temporary_storage_mark(auto_reset_storage_marker, location);
    }
}

#scope_file

// Seems legit for most ABIs
alignmentOf :: (info : *Type_Info) -> s64 #compile_time {
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
            return 1;

        case .STRUCT;
            max_primitive_alignment := 1;

            info_struct := cast(*Type_Info_Struct) info;
            for info_struct.members {
                if it.flags & (.CONSTANT | .IMPORTED) continue;
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

makeArenaName :: (arena : *Arena, $format : string, args : ..Any) {
    arena.name.count = 0;
    arena.name.data  = arena.name_memory.data;

    #if format {
        if args.count > 0 {
            builder := Basic.String_Builder.{ allocator = Basic.temp };
            defer Basic.free_buffers(*builder);

            Basic.print(*builder, format, ..args);

            buffer  := Basic.get_base_buffer(*builder);
            data_it := arena.name.data;
            while buffer {
                assert(arena.name.count + buffer.count <= Arena.name_memory.count,
                       "Arena name is too long, consider increasing Arena.name_memory");

                memcpy(data_it, Basic.get_buffer_data(buffer), buffer.count);
                data_it += buffer.count;

                arena.name.count += buffer.count;

                buffer = buffer.next;
            }
        } else {
            appendToString(*arena.name, Arena.name_memory.count, format);
        }

        appendToString(*arena.name, Arena.name_memory.count, " arena");
    }
}

makeSubarenaName :: (subarena : *Arena, arena : Arena, $format : string, args : ..Any) {
    subarena.name.count = 0;
    subarena.name.data  = subarena.name_memory.data;

    #if format {
        if arena.name {
            appendToString(*subarena.name, Arena.name_memory.count, arena.name, "/");
        }

        if args.count > 0 {
            builder := Basic.String_Builder.{ allocator = Basic.temp };
            defer Basic.free_buffers(*builder);

            Basic.print(*builder, format, ..args);

            buffer  := Basic.get_base_buffer(*builder);
            data_it := subarena.name.data + subarena.name.count;
            while buffer {
                assert(subarena.name.count + buffer.count <= Arena.name_memory.count,
                       "Subarena name is too long, consider increasing Arena.name_memory");

                memcpy(data_it, Basic.get_buffer_data(buffer), buffer.count);
                data_it += buffer.count;

                subarena.name.count += buffer.count;

                buffer = buffer.next;
            }
        } else {
            appendToString(*subarena.name, Arena.name_memory.count, format);
        }

        appendToString(*subarena.name, Arena.name_memory.count, " subarena");
    }
}
