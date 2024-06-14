#module_parameters(VK_ENABLE_BETA_EXTENSIONS := false)(DEBUG_BUILD : bool, PRINT_VERBOSE_MESSAGES : bool);

#scope_export

f32 :: float32;
f64 :: float64;

#if OS == .WINDOWS {
    asciiToWide :: (wide_string : *[] WCHAR, ascii_string : string, $null_terminated : bool) #no_context {
        wide_string.count = ascii_string.count;

        for 0 .. ascii_string.count - 1 {
            wide_string.*[it] = ascii_string[it];
        }

        #if null_terminated {
            wide_string.count += 1;
            wide_string.*[ascii_string.count] = 0;
        }
    }

    asciiToWide :: (wide_string : *[$wide_string_capacity] WCHAR, $$ascii_string : string, $null_terminated : bool) {
        #if null_terminated {
            #if is_constant(ascii_string) {
                #assert wide_string_capacity > ascii_string.count;
            } else {
                assert(wide_string_capacity > ascii_string.count);
            }
        } else {
            #if is_constant(ascii_string) {
                #assert wide_string_capacity >= ascii_string.count;
            } else {
                assert(wide_string_capacity >= ascii_string.count);
            }
        }

        for 0 .. ascii_string.count - 1 {
            wide_string.*[it] = ascii_string[it];
        }

        #if null_terminated {
            wide_string.*[ascii_string.count] = 0;
        }
    }

    wideToAscii :: (
        wide_string : *WCHAR,
        length      : s64,
        allocate    : (user_data : *$T, bytes : s64) -> *void,
        user_data   : *T
    ) -> string {
        ascii_string := string.{ length, allocate(user_data, length) };

        for 0 .. ascii_string.count - 1 {
            ascii_string[it] = cast(u8) wide_string[it];
        }

        return ascii_string;
    }

    wideToAscii :: (ascii_string : *string, ascii_string_capacity : s64, wide_string : *WCHAR, length : s64) {
        assert(length <= ascii_string_capacity);
        ascii_string.count = length;

        for 0 .. ascii_string.count - 1 {
            ascii_string.*[it] = cast(u8) wide_string[it];
        }
    }

    wideLength :: inline (wide_string : [$wide_string_capacity] WCHAR) -> s64 #no_context {
        length := 0;
        for wide_string {
            if it == 0 break;
            length += 1;
        }
        return length;
    }
}

advance :: inline (str : *string, amount : s64 = 1) {
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

formatHex :: inline (value : Any, minimum_digits := 1) -> Basic.FormatInt {
    return .{
        value            = value,
        base             = 16,
        minimum_digits   = minimum_digits,
        digits_per_comma = 4,
        comma_string     = "'",
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
    #load "windows.jai";
} else {
    notImplemented();
}

#scope_module

Basic  :: #import "Basic";
Math   :: #import "Math";
String :: #import "String";
