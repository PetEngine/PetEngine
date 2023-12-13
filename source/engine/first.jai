// @TODO:
//    - @Cleanup: VkAllocationCallbacks -> #VkAllocationCallbacks.

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
    thread_name      : string;
    thread_kind      : ThreadKind;
    persistent_arena : Arena;
    per_frame_arena  : Arena;
};

PerViewUniform :: struct {
    camera_pos : v3f;
/*
    view_matrix     : m3x4;
    inv_view_matrix : m3x4;

    proj_matrix     : m4x4;
    inv_proj_matrix : m4x4;

    view_proj_matrix     : m4x4;
    inv_view_proj_matrix : m4x4;
*/
}

main :: () {
    {
        context.print_style.default_format_struct.use_long_form_if_more_than_this_many_members = -1;
        context.print_style.default_format_struct.use_newlines_if_long_form                    = true;
        context.print_style.default_format_absolute_pointer.minimum_digits                     = 16;
    }

    context.pet.thread_name = "Main";
    context.pet.thread_kind = .MAIN;

    // @TODO: #Settings. Get persistent arena capacity from settings.
    createArena(*context.pet.persistent_arena, gigaBytes(1), "persistent");
    defer destroyArena(*context.pet.persistent_arena);

    // @TODO: #Settings. Get per frame arena capacity from settings.
    createArena(*context.pet.per_frame_arena, megaBytes(512), "per frame");
    defer destroyArena(*context.pet.per_frame_arena);

    window_manager := createWindowManager();
    defer destroyWindowManager(window_manager);

    // @TODO: #Settings. Get surface dimension from settings.
    window := createWindow(window_manager, surface_width = 960, surface_height = 540);
    defer destroyWindow(window);

    createInput(window);
    defer destroyInput();

    // @TODO: #Settings.
    //    - Get graphics API from settings.
    //    - Get buffering value from settings.
    device := createDevice(.VULKAN, window, 2);
    defer destroyDevice(device);

    resource_manager := createResourceManager(device);
    defer destroyResourceManager(device, resource_manager);

    shader_manager := createShaderManager(device);
    defer destroyShaderManager(device, shader_manager);

    shaders_hot_reload : ShadersHotReload;
    initShadersHotReload(*shaders_hot_reload, device, shader_manager);
    defer destroyShadersHotReload(*shaders_hot_reload);

    per_view_uniform_buffer := createBuffer(device, resource_manager, size_of(PerViewUniform), .UNIFORM, name = "Per view", .PERSISTENT);

    depth_buffer := createTexture(device,
                                  resource_manager,
                                  .D32,
                                  window.surface.width,
                                  window.surface.height,
                                  usage = .DEPTH_TARGET | .SHADER_READ,
                                  "Depth",
                                  .PERSISTENT_RESOLUTION_DEPENDENT);

    // Create persistent buffers and textures here...

    commitResourceMemory(device, resource_manager, .PERSISTENT);
    defer resetResourceMemory(device, resource_manager, .PERSISTENT);

    commitResourceMemory(device, resource_manager, .PERSISTENT_RESOLUTION_DEPENDENT);
    defer resetResourceMemory(device, resource_manager, .PERSISTENT_RESOLUTION_DEPENDENT);

    triangle_shader := createShader(device, shader_manager, "triangle");

    command_buffer := createCommandBuffer(device, .GRAPHICS);

    showWindow(window);

    while processWindowEvents(window) {
        resetArena(*context.pet.per_frame_arena);
        Basic.reset_temporary_storage();

        //
        // Update
        //

        //
        // Render
        //

        if window.flags & .MINIMIZED {
            continue;
        }

        if window.flags & .RESIZED {
            recreateSwapchain(device, window);
            resizeResolutionDependentTextures(device, resource_manager);
        }

        beginFrame(device);
        {
            // Reset
            {
                resetCommandBuffer(device, *command_buffer);
                // @TODO: #PerFrameResources. Delete unused per frame resources memory when number of swapchain buffers is decreased.
                resetResourceMemory(device, resource_manager, .PER_FRAME);
                resetShaderManager(device, shader_manager);
            }

            // Create per frame buffers and textures here...

            // Commit
            {
                // @TODO: #PerFrameResources. Should we be able to upload data to per frame resources?
                //        Maybe we want to restrict it?
                //        Also it seems like we have to restrict having any owners other than .GRAPHICS for per frame resources
                //        since we do not want to release memory which is in use by async queues.
                commitResourceMemory(device, resource_manager, .PER_FRAME);
            }

            back_buffer := getBackBuffer(device);

            clearTexture(device, *command_buffer, depth_buffer, .{ depth = 1.0 });

            beginRendering(device, *command_buffer, .[
                .{
                    texture      = back_buffer,
                    load_action  = .CLEAR,
                    store_action = .STORE,
                    clear_value  = .{ as_f32 = .[ 0.3, 0.3, 0.3, 0.0 ] } // @TODO: #Settings. Get back buffer clear color from settings.
                },
            ]);
            {
                setViewport(device, *command_buffer, *Viewport.{ 0.0, 0.0, cast(f32) back_buffer.width, cast(f32) back_buffer.height, 0.0, 1.0 }, back_buffer.height);
                setScissorRect(device, *command_buffer, *ScissorRect.{ 0, 0, back_buffer.width, back_buffer.height });

                setShader(device, *command_buffer, triangle_shader);

                time := cast(f32) Basic.get_time();
                setPushConstants(device, *command_buffer, .FRAGMENT, *time);

                drawPrimitives(device, *command_buffer, 3);
            }
            endRendering(device, *command_buffer);
        }
        endFrame(device);
    }

    waitDeviceIdle(device);
}

DEBUG_BUILD :: #run -> bool {
    llvm_options := Compiler.get_build_options().llvm_options;

    return llvm_options.bitcode_optimization_setting == .O0
        || llvm_options.bitcode_optimization_setting == .O1;
};

#import "common"()(DEBUG_BUILD = DEBUG_BUILD);

#load "core/input.jai";
#load "core/window.jai";
#load "render/device.jai";
#load "render/command_buffer.jai";
#load "render/resource_manager.jai";
#load "render/shader.jai";
#load "shader_compiler/compiler.jai";
#load "shader_compiler/hot_reload.jai";

String     :: #import "String";
Reflection :: #import "Reflection";

#scope_file

Basic    :: #import "Basic"()(ENABLE_ASSERT = DEBUG_BUILD, TEMP_ALLOCATOR_POISON_FREED_MEMORY = DEBUG_BUILD);
Compiler :: #import "Compiler";
