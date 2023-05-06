#module_parameters()(DEBUG_BUILD : bool);

f32 :: float32;
f64 :: float64;

#load "arena.jai";
#load "debug.jai";
#load "math.jai";
#load "vulkan/vulkan.jai";
#if OS == .WINDOWS {
    #load "windows.jai";
} else {
    notImplemented();
}

Basic :: #import "Basic";
