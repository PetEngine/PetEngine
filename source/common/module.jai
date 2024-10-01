#module_parameters(VK_ENABLE_BETA_EXTENSIONS := false)(DEBUG_BUILD : bool, PRINT_VERBOSE_MESSAGES : bool);

#scope_export

f32 :: float32;
f64 :: float64;

DEFAULT_CACHE_LINE_SIZE :: 64;
DEFAULT_PAGE_SIZE       :: 4096;
DEFAULT_ALIGNMENT       :: size_of(*void);

ntStringLength :: inline (nt_string : [] $T/ALLOWED_CHAR_TYPES) -> s64 #no_context {
    for nt_string {
        if it == 0 {
            return it_index;
        }
    }
    return nt_string.count;
}

ntStringLength :: inline (nt_string : *$T/ALLOWED_CHAR_TYPES) -> s64 #no_context {
    start := nt_string;
    while nt_string.* {
        nt_string += 1;
    }
    return nt_string - start;
}

ntStringCompare :: (a : [] $T/ALLOWED_CHAR_TYPES, b : [] T) -> s64 {
    index := 0;
    count := min(a.count, b.count);
    a_it  := a.data;
    b_it  := b.data;

    while index < count && a_it.* && a_it.* == b_it.* {
        index += 1;
        a_it  += 1;
        b_it  += 1;
    }

    a_s64 : s64 = a_it.*;
    b_s64 : s64 = b_it.*;
    return a_s64 - b_s64;
}

ntStringCompare :: (a : *$T/ALLOWED_CHAR_TYPES, b : *T) -> s64 {
    while a.* && a.* == b.* {
        a += 1;
        b += 1;
    }

    a_s64 : s64 = a.*;
    b_s64 : s64 = b.*;
    return a_s64 - b_s64;
}

advance :: inline (str : *string, amount := 1) {
    assert(amount > 0, "amount should be > 0. amount = %", amount);
    assert(str.count >= amount, "str.count should be >= amount. str.count = %, amount = %", str.count, amount);

    str.data  += amount;
    str.count -= amount;
}

substring :: inline (source : string, offset : s64, $$count : s64 = -1) -> string {
    if offset >= source.count {
        return "";
    }

    assert(offset >=  0, "offset should be >= 0, offset = %", offset);
    assert(count  >= -1, "count should be >= -1, count = %", count);

    substr : string = ---;
    substr.data = source.data + offset;

    #if is_constant(count) {
        #if count == -1 {
            substr.count = source.count - offset;
        } else {
            assert(count <= source.count - offset);
            substr.count = count;
        }
    } else {
        if count == -1 {
            substr.count = source.count - offset;
        } else {
            assert(count <= source.count - offset);
            substr.count = count;
        }
    }

    return substr;
}

appendToString :: (dest : *string, dest_capacity : s64, to_append : ..string) {
    for to_append {
        assert(dest.count + it.count <= dest_capacity,
               "String overflow: occupied: %, requested to append: %, capacity: %",
               dest.count, it.count, dest_capacity);

        memcpy(dest.data + dest.count, it.data, it.count);
        dest.count += it.count;
    }
}

toView :: inline (data : *$T, count : s64) -> [] T #no_context {
    result : [] T = ---;
    result.data  = data;
    result.count = count;

    return result;
}

toView :: inline (data : *void, count : s64, $type : Type) -> [] type #no_context {
    result : [] type = ---;
    result.data  = data;
    result.count = count;

    return result;
}

formatHex :: inline (value : $T, minimum_digits := 1) -> Basic.FormatInt {
    assert(type_info(T).type == .INTEGER);

    return .{
        value            = value,
        base             = 16,
        minimum_digits   = minimum_digits,
        digits_per_comma = 4,
        comma_string     = "'",
    };
}

formatInline :: inline (value : $T) -> Basic.FormatStruct {
    ti := type_info(T);
    assert(ti.type == .STRUCT);

    return .{
        value = value,
        use_long_form_if_more_than_this_many_members = ti.members.count
    };
}

generatePlatformVtableInitialization :: (
    $vtable_storage_type         : Type,
    vtable_storage_instance_name : string,
    platform_name                : string
) -> string #compile_time {
    assert(#compile_time, "This function should be run only in compile time"); // @Cleanup: #CompileTime.

    assert(vtable_storage_instance_name);
    assert(platform_name);

    ti := type_info(vtable_storage_type);
    assert(ti.type == .STRUCT);

    builder := Basic.String_Builder.{ allocator = Basic.temp };

    for ti.members {
        if it.type.type == .PROCEDURE {
            vulkan_procedure_name := String.replace(it.name, "Platform", platform_name,, allocator = Basic.temp);
            Basic.print(*builder, "%.% = %;\n", vtable_storage_instance_name, it.name, vulkan_procedure_name);
        }
    }

    return Basic.builder_to_string(*builder,, allocator = Basic.temp);
}

#load "arena.jai";
#load "debug.jai";
#load "file.jai";
#load "math/common.jai";
#load "math/matrices.jai";
#load "math/vectors.jai";
#load "mutex.jai";
#load "static_array.jai";
#load "thread.jai";
#load "vulkan/vulkan.jai";
#if OS == .WINDOWS {
    #load "windows/windows.jai";
    #load "windows/unicode.jai";
} else {
    notImplemented();
}

#if DEBUG_BUILD {
    Allocator :: #import "rpmalloc"(ENABLE_STATISTICS    = DEBUG_BUILD,
                                    ENABLE_ASSERTS       = DEBUG_BUILD,
                                    ENABLE_VALIDATE_ARGS = DEBUG_BUILD,
                                    LINUX_FREE_ADVICE    = .DONTNEED);
} else {
    Allocator :: #import "rpmalloc"(ENABLE_STATISTICS    = DEBUG_BUILD,
                                    ENABLE_ASSERTS       = DEBUG_BUILD,
                                    ENABLE_VALIDATE_ARGS = DEBUG_BUILD,
                                    LINUX_FREE_ADVICE    = .FREE);
}
String   :: #import "String";
Compiler :: #import "Compiler";

#scope_module

Basic :: #import "Basic";
Math  :: #import "Math";

#scope_file

ALLOWED_CHAR_TYPES :: Type.[
    u8, u16, u32,
];
