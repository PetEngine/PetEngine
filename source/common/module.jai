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

formatHex :: inline (value : $T, minimum_digits := 1) -> Basic.FormatInt {
    #assert type_info(T).type == .INTEGER;

    return .{
        value            = value,
        base             = 16,
        minimum_digits   = minimum_digits,
        digits_per_comma = 4,
        comma_string     = "'",
    };
}

formatInline :: inline (value : $T) -> Basic.FormatStruct {
    INFO :: type_info(T);
    #assert INFO.type == .STRUCT;

    return .{
        value = value,
        use_long_form_if_more_than_this_many_members = INFO.members.count
    };
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
