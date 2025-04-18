#module_parameters()(DEBUG_BUILD : bool);

#load "source/shaderc.jai";

#scope_module

size_t :: u64; // We target only 64-bit systems, so... whatever.

#if DEBUG_BUILD {
    shaderc :: #library "bin/shaderc_sharedd";
} else {
    shaderc :: #library "bin/shaderc_shared";
}
