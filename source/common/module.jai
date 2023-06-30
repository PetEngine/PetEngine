#module_parameters(VK_ENABLE_BETA_EXTENSIONS := false)(DEBUG_BUILD : bool);

f32 :: float32;
f64 :: float64;

s8_array_to_string :: inline (array : [] s8) -> string #no_context {
    str : string = ---;
    str.data  = cast(*u8) array.data;
    str.count = array.count;

    return str;
}

#load "arena.jai";
#load "debug.jai";
#load "math.jai";
#load "static_array.jai";
#load "vulkan/vulkan.jai";
#if OS == .WINDOWS {
    #load "windows.jai";
} else {
    notImplemented();
}

Basic         :: #import "Basic";
Compiler      :: #import "Compiler";
Program_Print :: #import "Program_Print";
