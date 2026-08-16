#module_parameters(VK_ENABLE_BETA_EXTENSIONS := false)(DEBUG_BUILD : bool, PRINT_VERBOSE_MESSAGES : bool, GRAPHICS_API : GraphicsAPI) {
    GraphicsAPI :: enum u8 { // Not the best solution since we have this enum from add_build_string, but meh
        VULKAN;
    }
};

#scope_export

f32 :: float32;
f64 :: float64;

DEFAULT_CACHE_LINE_SIZE :: 64;
DEFAULT_PAGE_SIZE       :: 4096;
DEFAULT_ALIGNMENT       :: size_of(*void);

toView :: inline (data : *$T, count : s64) -> [] T #no_context {
    result : [] T = .{ count, data };
    return result;
}

toView :: inline (data : *void, count : s64, $type : Type) -> [] type #no_context {
    result : [] type = .{ count, data };
    return result;
}

formatHex :: inline (value : Any, minimum_digits := 1) -> Basic.FormatInt {
    assert(value.type.type == .INTEGER);
    format := context.print_style.default_format_int;
    format.value            = value;
    format.base             = 16;
    format.minimum_digits   = minimum_digits;
    format.digits_per_comma = 4;
    return format;
}

formatInline :: inline (value : Any) -> Basic.FormatStruct {
    assert(value.type.type == .STRUCT);
    format := context.print_style.default_format_struct;
    format.value                                        = value;
    format.use_long_form_if_more_than_this_many_members = maxOf(type_of(Basic.FormatStruct.use_long_form_if_more_than_this_many_members));
    return format;
}

reset :: inline (array : *[] $T, $zero_memory := true) #no_context {
    #if zero_memory {
        memset(array.data, 0, array.count * size_of(T));
    }
    array.count = 0;
}

reset :: inline (array : *[$capacity] $T) #no_context {
    memset(array.data, 0, array.count * size_of(T));
}

isTitghtlyPacked :: ($type : Type) -> bool #compile_time {
    INFO :: type_info(type);
    #assert INFO.type == .STRUCT;

    expected_offset : s64;
    for INFO.members {
        if it.flags & (.CONSTANT | .OVERLAY) continue;

        if expected_offset != it.offset_in_bytes {
            errorMessage("%.%: expected offset (%) != real offset (%)", type, it.name, expected_offset, it.offset_in_bytes);
            return false;
        }

        expected_offset += it.type.runtime_size;
    }

    if expected_offset != size_of(type) {
        errorMessage("%: expected size (%) != real size (%)", type, expected_offset, size_of(type));
        return false;
    }

    return true;
}

#load "arena.jai";
#load "debug.jai";
#load "file.jai";
#load "ini.jai";
#load "math/common.jai";
#load "math/matrices.jai";
#load "math/vectors.jai";
#load "mutex.jai";
#load "static_array.jai";
#load "string_utils.jai";
#load "thread.jai";
#if #complete GRAPHICS_API == {
    case .VULKAN; #load "vulkan/vulkan.jai";
}
#if OS == .WINDOWS {
    #load "windows/windows.jai";
    #load "windows/unicode.jai";
} else {
    notImplemented();
}

Allocator :: #import "rpmalloc"(ENABLE_STATISTICS    = DEBUG_BUILD,
                                ENABLE_ASSERTS       = DEBUG_BUILD,
                                ENABLE_VALIDATE_ARGS = DEBUG_BUILD,
                                LINUX_FREE_ADVICE    = .FREE);
String    :: #import "String";
Compiler  :: #import "Compiler";

#scope_module

Basic :: #import "Basic";
