#module_parameters()(DEBUG_BUILD : bool);

#load "source/spirv.jai";
#load "source/spirv_reflect.jai";

#scope_module

size_t :: u64; // We target only 64-bit systems, so... whatever.

#if DEBUG_BUILD {
    spirv_reflect :: #library,no_dll "bin/spirv-reflectd";
} else {
    spirv_reflect :: #library,no_dll "bin/spirv-reflect";
}
