#module_parameters(VK_ENABLE_BETA_EXTENSIONS := false)(DEBUG_BUILD : bool);

f32 :: float32;
f64 :: float64;

s8_array_to_string :: inline (array : [] s8) -> string #no_context {
    str : string = ---;
    str.data  = cast(*u8) array.data;
    str.count = array.count;

    return str;
}

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
}

advance :: inline (str : *string, amount : s64 = 1) {
    assert(amount > 0, "amount should be > 0. amount = %", amount);
    assert(str.count >= amount, "str.count should be >= amount. str.count = %, amount = %", str.count, amount);

    str.data  += amount;
    str.count -= amount;
}

substring :: inline (source : string, index : s64, $$count : s64 = -1) -> string {
    if index >= source.count {
        return "";
    }

    assert(index >=  0, "index should be >= 0, index = %", index);
    assert(count >= -1, "count should be >= -1, count = %", count);

    substr : string = ---;
    substr.data  = source.data + index;

    #if is_constant(count) {
        #if count == -1 {
            substr.count = source.count - index;
        } else {
            assert(count <= source.count - index);
            substr.count = count;
        }
    } else {
        if count == -1 {
            substr.count = source.count - index;
        } else {
            assert(count <= source.count - index);
            substr.count = count;
        }
    }

    return substr;
}

#load "arena.jai";
#load "debug.jai";
#load "math.jai";
#load "static_array.jai";
#load "thread.jai";
#load "vulkan/vulkan.jai";
#if OS == .WINDOWS {
    #load "windows.jai";
} else {
    notImplemented();
}

Basic         :: #import "Basic";
Compiler      :: #import "Compiler";
Program_Print :: #import "Program_Print";
