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

#add_context pet : struct {
    persistent_arena : Arena;
    per_frame_arena  : Arena;
};

main :: () {
    // @TODO: #Settings. Get persistent arena capacity from settings.
    createArena(*context.pet.persistent_arena, gigaBytes(1), "Persistent");
    defer destroyArena(*context.pet.persistent_arena);

    // @TODO: #Settings. Get per frame arena capacity from settings.
    createArena(*context.pet.per_frame_arena, megaBytes(512), "Per frame");
    defer destroyArena(*context.pet.per_frame_arena);

    window_manager := createWindowManager();
    defer destroyWindowManager(window_manager);

    // @TODO: #Settings. Get surface dimension from settings.
    window := createWindow(window_manager, surface_width = 960, surface_height = 540);
    defer destroyWindow(window);

    // @TODO: #Settings. Get graphics API from settings.
    device := createDevice(.VULKAN, window);
    defer destroyDevice(device);

    texture_manager := createTextureManager(device);
    defer destroyTextureManager(device, texture_manager);

    shader_manager := createShaderManager(device);
    defer destroyShaderManager(device, shader_manager);

    depth_buffer := createTexture(device,
                                  texture_manager,
                                  .D32,
                                  window.surface.width,
                                  window.surface.height,
                                  flags = .DEPTH_STENCIL | .COHERENT,
                                  "Depth buffer",
                                  .PERSISTENT_RESOLUTION_DEPENDENT);

    // Create persistent textures here...

    commitTextureMemory(device, texture_manager, .PERSISTENT);
    defer resetTextureMemory(device, texture_manager, .PERSISTENT);

    commitTextureMemory(device, texture_manager, .PERSISTENT_RESOLUTION_DEPENDENT);
    defer resetTextureMemory(device, texture_manager, .PERSISTENT_RESOLUTION_DEPENDENT);

    triangle_shader := createShader(device, shader_manager, "triangle");

    command_buffer := createCommandBuffer(device, .GRAPHICS);

    showWindow(window);

    while processWindowEvents(window) {
        if window.flags & .RESIZED {
            recreateSwapchain(device, window);
            resizeResolutionDependentTextures(device, texture_manager);
        }

        beginFrame(device);
        {
            // @TODO: #PerFrameTextures. Delete unused per frame texture memory when number of swapchain buffers decreased.

            resetTextureMemory(device, texture_manager, .PER_FRAME);

            // Create per frame textures here...

            // @Cleanup: #PerFrameTextures. Should we be able to upload data to per frame textures?
            //           Maybe we want to restrict to upload data to per frame textures?
            //           Also it seems like we have to restrict having any owners other than .GRAPHICS for per frame textures
            //           since we do not want tot release memory which is in use by async queues.
            commitTextureMemory(device, texture_manager, .PER_FRAME);

            back_buffer := getBackBuffer(device);

            // @TODO: #Settings. Get back buffer clear color from settings.
            clearTexture(device, *command_buffer, back_buffer,  .{ color_f32 = .[ 0.3, 0.3, 0.3, 0.0 ] });
            clearTexture(device, *command_buffer, depth_buffer, .{ depth = 1.0 });

            beginRendering(device, *command_buffer, back_buffer);
            {
                setViewport(device, *command_buffer, *Viewport.{ 0.0, 0.0, cast(f32) back_buffer.width, cast(f32) back_buffer.height, 0.0, 1.0 }, back_buffer.height);
                setScissorRect(device, *command_buffer, *ScissorRect.{ 0, 0, back_buffer.width, back_buffer.height });
                setShader(device, *command_buffer, triangle_shader);
                drawPrimitives(device, *command_buffer, 3);
            }
            endRendering(device, *command_buffer);
        }
        endFrame(device);

        resetArena(*context.pet.per_frame_arena);
        Basic.reset_temporary_storage();
    }

    waitDeviceIdle(device);
}

DEBUG_BUILD :: #run -> bool {
    llvm_options := Compiler.get_build_options().llvm_options;

    return llvm_options.bitcode_optimization_setting == .O0
        || llvm_options.bitcode_optimization_setting == .O1;
};

#import "common"()(DEBUG_BUILD = DEBUG_BUILD);

#load "core/window.jai";
#load "render/device.jai";
#load "render/command_buffer.jai";
#load "render/texture.jai";
#load "render/shader.jai";

String :: #import "String";
File   :: #import "File";

#scope_file

Basic    :: #import "Basic"()(ENABLE_ASSERT = DEBUG_BUILD);
Compiler :: #import "Compiler";
