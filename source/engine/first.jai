#scope_export

ENGINE_NAME    :: "PetEngine";
ENGINE_VERSION :: #run makeEngineVersion(ENGINE_VERSION_MAJOR, ENGINE_VERSION_MINOR, ENGINE_VERSION_PATCH);

ENGINE_VERSION_MAJOR : u32 : 0;
ENGINE_VERSION_MINOR : u32 : 1;
ENGINE_VERSION_PATCH : u32 : 0;

#assert ENGINE_VERSION_MAJOR <= 0x00FF;
#assert ENGINE_VERSION_MINOR <= 0x00FF;
#assert ENGINE_VERSION_PATCH <= 0x00FF;

makeEngineVersion :: inline (major : u32, minor : u32, patch : u32) -> u32 {
    return (major << 16) | (minor << 8) | patch;
}

#scope_module

#add_context pet_engine_state : struct {
    persistent_arena : Arena;
    per_frame_arena  : Arena;
};

main :: ()
{
    // @TODO: #Settings. Get persistent arena capacity from settings.
    createArena(*context.pet_engine_state.persistent_arena, gigaByte(1), "Persistent");
    defer destroyArena(*context.pet_engine_state.persistent_arena);

    // @TODO: #Settings. Get per frame arena capacity from settings.
    createArena(*context.pet_engine_state.per_frame_arena, megaByte(512), "Per frame");
    defer destroyArena(*context.pet_engine_state.per_frame_arena);

    window_manager := createWindowManager();
    defer destroyWindowManager(window_manager);

    // @TODO: #Settings. Get surface dimension from settings.
    window := createWindow(window_manager, surface_width = 960, surface_height = 540);
    defer destroyWindow(window);

    device := createDevice(.VULKAN, window);
    defer destroyDevice(device);

    showWindow(window);

    while processWindowEvents(window) {
        beginFrame(device);
        endFrame(device);

        resetArena(*context.pet_engine_state.per_frame_arena);
        Basic.reset_temporary_storage();
    }
}

DEBUG_BUILD :: #run -> bool {
    llvm_options := Compiler.get_build_options().llvm_options;

    return llvm_options.bitcode_optimization_setting == .O0
        || llvm_options.bitcode_optimization_setting == .O1;
};

#import "common"()(DEBUG_BUILD = DEBUG_BUILD);

#load "core/window.jai";
#load "render/device.jai";

String :: #import "String";

#scope_file

Basic    :: #import "Basic"()(ENABLE_ASSERT = DEBUG_BUILD);
Compiler :: #import "Compiler";
