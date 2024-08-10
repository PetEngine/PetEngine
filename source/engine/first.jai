#scope_export

ENGINE_NAME    :: "PetEngine";
ENGINE_VERSION :: #run makeEngineVersion(ENGINE_VERSION_MAJOR, ENGINE_VERSION_MINOR, ENGINE_VERSION_PATCH);

ENGINE_VERSION_MAJOR :: 0;
ENGINE_VERSION_MINOR :: 1;
ENGINE_VERSION_PATCH :: 0;

#assert ENGINE_VERSION_MAJOR <= 0x00FF;
#assert ENGINE_VERSION_MINOR <= 0x00FF;
#assert ENGINE_VERSION_PATCH <= 0x00FF;

makeEngineVersion :: inline (major : u32, minor : u32, patch : u32) -> u32 {
    return (major << 16) | (minor << 8) | patch;
}

#scope_module

#add_context pet : struct {
    thread : struct {
        name : string;
        kind : ThreadKind;
    };

    arenas : struct {
        persistent : Arena;
        per_frame  : Arena;
    };

    core : struct {
        window_manager : *WindowManager;
        initial_time   : Basic.Apollo_Time;
    };

    render : struct {
        device           : *Device;
        resource_manager : *ResourceManager;
        asset_manager    : *AssetManager;
        shader_manager   : *ShaderManager;
        binding_manager  : *BindingManager;
    };

    initGlobals :: (new_context : *Context) {
        #insert -> string {
            builder := Basic.String_Builder.{ allocator = Basic.temp };

            info := type_info(type_of(Context.pet.core));
            assert(info.type == .STRUCT);

            for info.members {
                if it.type.type == .POINTER {
                    Basic.print(*builder, "assert(context.pet.core.%1, \"%1 should be created\");\n", it.name);
                }
                Basic.print(*builder, "new_context.pet.core.%1 = context.pet.core.%1;\n", it.name);
            }

            info = type_info(type_of(Context.pet.render));
            assert(info.type == .STRUCT);

            for info.members {
                Basic.print(*builder, "assert(context.pet.render.%1, \"%1 should be created\");\n", it.name);
                Basic.print(*builder, "new_context.pet.render.%1 = context.pet.render.%1;\n", it.name);
            }

            return Basic.builder_to_string(*builder,, allocator = Basic.temp);
        }
    }
};

//
// PerViewUniform
//

PerViewUniform :: struct {
    MAX_VERSIONS :: 1;

    // @Cleanup: Move to camera.jai
    CAMERA_NEAR :: 0.1;
    CAMERA_FAR  :: 100.0;
    CAMERA_FOV  :: #run degToRad(60.0);

    Data :: struct {
        camera_pos : v3f = .{ 2.0, 10.0, -17.0 };
        __padding0 : f32;

        camera_dir : v3f = .{ -0.1, -0.2, 0.9 };
        __padding1 : f32;

        view_matrix     : m4x4;
        inv_view_matrix : m4x4;

        proj_matrix     : m4x4;
        inv_proj_matrix : m4x4;

        view_proj_matrix     : m4x4;
        inv_view_proj_matrix : m4x4;
    } #no_padding

    buffer         : *Buffer;
    handles        : StaticArray([MAX_VERSIONS] BindingHandle, Device.MAX_FRAME_BUFFERING);
    version        : s32 = -1;
    aligned_stride : u32;
    data           : Data;
}

createPerViewUniform :: (uniform : *PerViewUniform) {
    uniform.aligned_stride = alignUpWithPowerOfTwo(cast(u32) size_of(PerViewUniform.Data), context.pet.render.binding_manager.uniform_buffer_offset_alignment);

    buffer_size := uniform.aligned_stride * PerViewUniform.MAX_VERSIONS * Device.MAX_FRAME_BUFFERING;
    uniform.buffer = createBuffer(buffer_size, .PERSISTENT, .UPLOAD, .UNIFORM, "Per view");
}

bindPerViewUniform :: (uniform : *PerViewUniform) {
    uniform.handles.count = cast(s64) context.pet.render.device.frame_buffering;

    offset : u32;
    for * uniform.handles {
        for * it.* {
            it.* = pushBinding(.PERSISTENT, uniform.buffer, offset, size_of(PerViewUniform.Data));
            offset += uniform.aligned_stride;
        }
    }
}

resetPerViewUniform :: inline (uniform : *PerViewUniform) {
    // @TODO: #FrameBuffering.
    assert(uniform.handles.count == cast(s64) context.pet.render.device.frame_buffering, "It's illegal to change frame buffering for now");
    uniform.version = -1;
}

commitPerViewUniform :: (uniform : *PerViewUniform) {
    uniform.version += 1;
    assert(uniform.version < PerViewUniform.MAX_VERSIONS);

    offset := (context.pet.render.device.frame_index * PerViewUniform.MAX_VERSIONS + uniform.version)
            * cast(s32) uniform.aligned_stride;

    memcpy(uniform.buffer.mapped_memory + offset, *uniform.data, size_of(PerViewUniform.Data));
}

//
// PerFrameUniform
//

PerFrameUniform :: struct {
    Data :: struct {
        frame : u32;
        time  : f32;
        dtime : f32;
    } #no_padding

    buffer         : *Buffer;
    aligned_stride : u32;
    data           : Data;
}

createPerFrameUniform :: (uniform : *PerFrameUniform) {
    uniform.aligned_stride = alignUpWithPowerOfTwo(cast(u32) size_of(PerFrameUniform.Data), context.pet.render.binding_manager.uniform_buffer_offset_alignment);

    buffer_size := uniform.aligned_stride * Device.MAX_FRAME_BUFFERING;
    uniform.buffer = createBuffer(buffer_size, .PERSISTENT, .UPLOAD, .UNIFORM, "Per frame");
}

bindPerFrameUniform :: inline (uniform : *PerFrameUniform) {
    offset := context.pet.render.device.frame_index * uniform.aligned_stride;
    pushBinding(.PER_FRAME, uniform.buffer, offset, size_of(PerFrameUniform.Data));
}

commitPerFrameUniform :: inline (uniform : *PerFrameUniform) {
    offset := context.pet.render.device.frame_index * uniform.aligned_stride;
    memcpy(uniform.buffer.mapped_memory + offset, *uniform.data, size_of(PerFrameUniform.Data));
}

//
// Main
//

petMain :: () {
    context.pet.thread.name = "Main";
    context.pet.thread.kind = .MAIN;

    context.pet.core.initial_time = Basic.current_time_monotonic();

    // @TODO: #Settings. Get persistent arena capacity from settings.
    createArena(*context.pet.arenas.persistent, gigaBytes(1), "Persistent");
    defer destroyArena(*context.pet.arenas.persistent);

    // @TODO: #Settings. Get per frame arena capacity from settings.
    createArena(*context.pet.arenas.per_frame, megaBytes(512), "Per frame");
    defer destroyArena(*context.pet.arenas.per_frame);

    convertExchangeAssetsToRuntime();

    createWindowManager();
    defer destroyWindowManager();

    // @TODO: #Settings.
    //    - Get graphics API from settings.
    //    - Get render resolution from settings.
    //    - Get buffering from settings.
    createDevice(.VULKAN, .{ 960, 540 }, .DOUBLE);
    defer destroyDevice();

    createResourceManager();
    defer destroyResourceManager();

    createAssetManager();

    createShaderManager();
    defer destroyShaderManager();

    createBindingManager();
    defer destroyBindingManager();

    shaders_hot_reload : ShadersHotReload;
    createShadersHotReload(*shaders_hot_reload);
    defer destroyShadersHotReload(*shaders_hot_reload);

    // @TODO: #Settings. Get surface dimension from settings.
    window := createWindow(surface = .{ 960, 540 });
    initWindowData(window);

    createInput(window);
    defer destroyInput();

    per_view_uniform : PerViewUniform;
    createPerViewUniform(*per_view_uniform);

    per_frame_uniform : PerFrameUniform;
    createPerFrameUniform(*per_frame_uniform);

    depth_buffer := createTexture(.D32,
                                  context.pet.render.device.render_resolution.width,
                                  context.pet.render.device.render_resolution.height,
                                  clear_value = .{ depth = 0.0 },
                                  .DEPTH_TARGET,
                                  .PERSISTENT,
                                  "Depth");

    depth_buffer_dsv := createTextureView(depth_buffer, .DEPTH_TARGET, lifetime = .PERSISTENT);

    depth_sampler := createSampler(.{ anisotropy = Sampler.MAX_ANISOTROPY }, .PERSISTENT, "Depth sampler");

    // Create persistent buffers and textures here...

    commitResourceMemory(.PERSISTENT);
    defer resetResourceMemory(.PERSISTENT);

    // All persistent bindings should be pushed after persistent resource memory commit
    bindPerViewUniform(*per_view_uniform);

    defer resetBindings(.PERSISTENT);

    // @TODO: #Scene.
    defer {
        resetResourceMemory(.PER_SCENE);
        resetAssetManagerAssets();
        resetBindings(.PER_SCENE);
    }

    floor := createFloor(depth_buffer.format);
    heart := createHeart(depth_buffer.format);

    command_buffer := createCommandBuffer(.GRAPHICS);

    showWindow(window);
    while processAllWindowsEvents() {
        resetArena(*context.pet.arenas.per_frame);
        Basic.reset_temporary_storage();

        if window.flags & .MINIMIZED continue;

        updateHeart(*heart, *window.input);

        beginFrame();
        {
            // Reset
            {
                // @TODO: #PerFrameResources. Delete unused per frame resources memory when number of swapchain buffers is decreased.
                resetResourceMemory(.PER_FRAME);
                resetAssetManager();
                resetShaderManager();
                resetBindings(.PER_FRAME);
                resetCommandBuffer(*command_buffer);
                resetPerViewUniform(*per_view_uniform);
            }

            // Create per frame resources here...

            // Commit
            {
                // @TODO: #PerFrameResources. Should we be able to upload data to per frame resources?
                //        Maybe we want to restrict it?
                //        Also it seems like we have to restrict having any owners other than .GRAPHICS for per frame resources
                //        since we do not want to release memory which is in use by async queues.
                commitResourceMemory(.PER_FRAME);
            }

            // @TODO: #Scene. New scene
            if window.input.keyboard[Input.Key.O] & .PRESSED {
                // Reset
                resetResourceMemory(.PER_SCENE);
                resetAssetManagerAssets();
                resetBindings(.PER_SCENE);

                // Create per scene resources here...
                loadHeartMesh(*heart);

                // Commit
                commitResourceMemory(.PER_SCENE);

                // @Important: Should be after per scene memory commit
                processRequestedAssets();
            }

            // Update per frame uniform
            bindPerFrameUniform(*per_frame_uniform);
            per_frame_uniform.data.frame += 1;
            {
                time_now := cast(f32) Basic.to_float64_seconds(Basic.current_time_monotonic() - context.pet.core.initial_time);
                per_frame_uniform.data.dtime = time_now - per_frame_uniform.data.time;
                per_frame_uniform.data.time  = time_now;
            }
            commitPerFrameUniform(*per_frame_uniform);

            back_buffer_view := getBackBufferView(window, .COLOR_TARGET);
            back_buffer      := back_buffer_view.texture;

            // Update per view uniform
            {
                using per_view_uniform.data;

                speed := 8.0;
                if window.input.keyboard[Input.Key.LEFT_SHIFT] & .DOWN {
                    speed *= 4.0;
                }

                if window.input.keyboard[Input.Key.W] & .DOWN then camera_pos.z += speed * per_frame_uniform.data.dtime;
                if window.input.keyboard[Input.Key.S] & .DOWN then camera_pos.z -= speed * per_frame_uniform.data.dtime;
                if window.input.keyboard[Input.Key.A] & .DOWN then camera_pos.x -= speed * per_frame_uniform.data.dtime;
                if window.input.keyboard[Input.Key.D] & .DOWN then camera_pos.x += speed * per_frame_uniform.data.dtime;
                if window.input.keyboard[Input.Key.E] & .DOWN then camera_pos.y += speed * per_frame_uniform.data.dtime;
                if window.input.keyboard[Input.Key.Q] & .DOWN then camera_pos.y -= speed * per_frame_uniform.data.dtime;

                if window.input.mouse.button_right & .DOWN {
                    camera_dir = rotationY(window.input.mouse.dx * per_frame_uniform.data.dtime) * camera_dir;
                    camera_dir = rotationX(window.input.mouse.dy * per_frame_uniform.data.dtime) * camera_dir;
                } else {
                    angleXY : v2f;
                    if window.input.keyboard[Input.Key.LEFT]  & .DOWN then angleXY.x -= speed * per_frame_uniform.data.dtime;
                    if window.input.keyboard[Input.Key.RIGHT] & .DOWN then angleXY.x += speed * per_frame_uniform.data.dtime;
                    if window.input.keyboard[Input.Key.UP]    & .DOWN then angleXY.y -= speed * per_frame_uniform.data.dtime;
                    if window.input.keyboard[Input.Key.DOWN]  & .DOWN then angleXY.y += speed * per_frame_uniform.data.dtime;

                    camera_dir = rotationY(angleXY.x) * camera_dir;
                    camera_dir = rotationX(angleXY.y) * camera_dir;
                }
                camera_dir = normalize(camera_dir);

                view_matrix, inv_view_matrix = lookToMatrixAndItsInverse(camera_pos, camera_dir);
                proj_matrix, inv_proj_matrix = perspectiveProjectionMatrixFromFovAndItsInverse(cast(f32) back_buffer.width / cast(f32) back_buffer.height,
                                                                                               PerViewUniform.CAMERA_FOV,
                                                                                               PerViewUniform.CAMERA_NEAR,
                                                                                               PerViewUniform.CAMERA_FAR);
                view_proj_matrix     = proj_matrix     * view_matrix;
                inv_view_proj_matrix = inv_view_matrix * inv_proj_matrix;
            }
            commitPerViewUniform(*per_view_uniform);

            beginRendering(*command_buffer,
                           .[ .{ back_buffer_view, .CLEAR, .STORE } ],
                           *(DepthTargetDesc.{ view = depth_buffer_dsv, depth_load_action = .CLEAR, depth_store_action = .NONE }));
            {
                drawFloor(*command_buffer, *floor, *per_view_uniform);
                drawHeart(*command_buffer, *heart, *per_view_uniform);
            }
            endRendering(*command_buffer);
        }
        endFrame();
    }

    waitDeviceIdle();
}

operator! :: Basic.operator!;
operator- :: Basic.operator-;
operator> :: Basic.operator>;

#import "common"()(DEBUG_BUILD = DEBUG_BUILD, PRINT_VERBOSE_MESSAGES = PRINT_VERBOSE_MESSAGES);

#load "assets/converter.jai";
#load "assets/manager.jai";
#load "core/input.jai";
#load "core/window.jai";
#load "render/binding_manager.jai";
#load "render/command_buffer.jai";
#load "render/device.jai";
#load "render/mesh.jai";
#load "render/resource_manager.jai";
#load "render/shader.jai";
#load "shader_compiler/compiler.jai";
#load "shader_compiler/hot_reload.jai";
#load "floor.jai";
#load "heart.jai";

Basic      :: #import "Basic"()(ENABLE_ASSERT = DEBUG_BUILD, TEMP_ALLOCATOR_POISON_FREED_MEMORY = DEBUG_BUILD);
String     :: #import "String";
Reflection :: #import "Reflection";
Atomics    :: #import "Atomics";

#scope_file

#if OS == .WINDOWS {
    #program_export
    WinMainCRTStartup :: () #c_call {
        first_context : Context;

        // _STACK_TRACE is defined by the compiler based on Build_Options.stack_trace
        #if _STACK_TRACE {
            this_frame_info := Stack_Trace_Procedure_Info.{
                name              = #procedure_name(),
                location          = #location(#this),
                procedure_address = cast(*void) #this,
            };

            this_frame := Stack_Trace_Node.{
                info        = *this_frame_info,
                line_number = cast(u32) #location(#this).line_number,
            };

            first_context.stack_trace = *this_frame;
        }

        push_context first_context {
            initRuntimeAndCallEntryPoint();
        }

        exitProcess(0);
    }

    getWindowsCommandLine :: () {
        command_line : [] s8;
        command_line.data = GetCommandLineA();
        assert(command_line.data, print_sys_error = true);

        command_line.count = ntStringLength(command_line.data);
        assert(command_line.count > 0, "Command line is empty, that's impossible");

        // Parse command line
        quote_opened             : bool;
        skip_quote               : bool;
        emplace_new_command_line := true;
        for command_line {
            if emplace_new_command_line {
                __command_line_arguments.count += 1;

                emplace_new_command_line = false;
            }

            if it == {
                case #char "\\";
                    if it_index < command_line.count - 1 && command_line[it_index + 1] == #char "\"" {
                        skip_quote = true;
                    }

                case #char "\"";
                    if skip_quote {
                        skip_quote = false;
                    } else {
                        quote_opened = !quote_opened;
                    }

                case #char " ";
                    if !quote_opened {
                        emplace_new_command_line = true;
                    }
            }
        }

        __command_line_arguments.data = Basic.alloc(__command_line_arguments.count * size_of(*u8));
        assert(__command_line_arguments.data, print_sys_error = true);

        // Fill __command_line_arguments
        quote_opened                 = false;
        skip_quote                   = false;
        emplace_new_command_line     = true;
        command_line_arguments_index : s64;
        for command_line {
            if emplace_new_command_line {
                __command_line_arguments[command_line_arguments_index] = cast(*u8) *command_line[it_index];
                command_line_arguments_index += 1;

                emplace_new_command_line = false;
            }

            if it == {
                case #char "\\";
                    if it_index < command_line.count - 1 && command_line[it_index + 1] == #char "\"" {
                        skip_quote = true;
                    }

                case #char "\"";
                    if skip_quote {
                        skip_quote = false;
                    } else {
                        quote_opened = !quote_opened;
                    }

                case #char " ";
                    if !quote_opened {
                        emplace_new_command_line = true;
                    }
            }
        }
    }

    reopenStdHandle :: ($std_handle : u32) -> HANDLE {
        #if std_handle == {
            case STD_INPUT_HANDLE;  NAME :: "CONIN$";
            case STD_OUTPUT_HANDLE; NAME :: "CONOUT$";
            case STD_ERROR_HANDLE;  NAME :: "CONOUT$";
            case;                   #assert false "Invalid std_handle value";
        }

        file_handle := CreateFileA(cast(*s8) NAME.data,
                                   GENERIC_READ | GENERIC_WRITE,
                                   FILE_SHARE_READ | FILE_SHARE_WRITE,
                                   null,
                                   OPEN_EXISTING,
                                   FILE_ATTRIBUTE_NORMAL,
                                   null);

        assert(file_handle != INVALID_HANDLE_VALUE, print_sys_error = true);

        debugCheck(SetStdHandle(std_handle, file_handle), print_sys_error = true);
        return file_handle;
    }
} else {
    #program_export
    main :: (argc : s32, argv : **s8) -> s32 #c_call {
        __command_line_arguments.count = argc;
        __command_line_arguments.data  = argv;

        first_context : Context;

        // _STACK_TRACE is defined by the compiler based on Build_Options.stack_trace
        #if _STACK_TRACE {
            this_frame_info := Stack_Trace_Procedure_Info.{
                name              = #procedure_name(),
                location          = #location(#this),
                procedure_address = cast(*void) #this,
            };

            this_frame := Stack_Trace_Node.{
                info        = *this_frame_info,
                line_number = cast(u32) #location(#this).line_number,
            };

            first_context.stack_trace = *this_frame;
        }

        push_context first_context {
            initRuntimeAndCallEntryPoint();
        }

        return errno;
    }
}

initRuntimeAndCallEntryPoint :: () {
    context.context_info = type_info(Context);

    context.print_style.default_format_int.digits_per_comma                                = 3;
    context.print_style.default_format_int.comma_string                                    = "'";
    context.print_style.default_format_float.thousand_separators                           = true;
    context.print_style.default_format_float.thousand_separator_character                  = #char "'";
    context.print_style.default_format_struct.use_long_form_if_more_than_this_many_members = -1;
    context.print_style.default_format_struct.use_newlines_if_long_form                    = true;
    context.print_style.default_format_absolute_pointer.minimum_digits                     = 16;
    context.print_style.default_format_absolute_pointer.comma_string                       = "'";

    context.allocator = .{ Allocator.rpmalloc_allocator_proc, null };

    context.allocator.proc(.STARTUP, 0, 0, null, context.allocator.data);
    defer context.allocator.proc(.SHUTDOWN, 0, 0, null, context.allocator.data);

    temporary_storage : Temporary_Storage;
    context.temporary_storage = *temporary_storage;

    // TEMPORARY_STORAGE_SIZE is defined by the compiler based on Build_Options.temporary_storage_size
    temporary_storage_data := Allocator.rpaligned_alloc(DEFAULT_CACHE_LINE_SIZE, TEMPORARY_STORAGE_SIZE);
    defer Allocator.rpfree(temporary_storage_data);

    set_initial_data(context.temporary_storage, TEMPORARY_STORAGE_SIZE, temporary_storage_data);

    #if OS == .WINDOWS {
        getWindowsCommandLine();
        defer Basic.free(__command_line_arguments.data);

        #if DEBUG_BUILD {
            console_was_allocated : bool;

            stdin_handle  := INVALID_HANDLE_VALUE;
            stdout_handle := INVALID_HANDLE_VALUE;
            stderr_handle := INVALID_HANDLE_VALUE;

            if !AttachConsole(ATTACH_PARENT_PROCESS) {
                debugCheck(AllocConsole(), print_sys_error = true);

                stdin_handle  = reopenStdHandle(STD_INPUT_HANDLE);
                stdout_handle = reopenStdHandle(STD_OUTPUT_HANDLE);
                stderr_handle = reopenStdHandle(STD_ERROR_HANDLE);

                console_was_allocated = true;
            }

            defer if console_was_allocated {
                debugCheck(CloseHandle(stderr_handle), print_sys_error = true);
                debugCheck(CloseHandle(stdout_handle), print_sys_error = true);
                debugCheck(CloseHandle(stdin_handle), print_sys_error = true);

                debugCheck(FreeConsole(), print_sys_error = true);
            }
        }
    }

    no_inline petMain();
}
