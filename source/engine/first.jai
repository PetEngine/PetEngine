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
    thread_name      : string;
    thread_kind      : ThreadKind;
    persistent_arena : Arena;
    per_frame_arena  : Arena;
};

PerViewUniform :: struct {
    MAX_VERSIONS :: 1;
    BUFFER_SIZE  : u32 : cast(u32) size_of(Data) * MAX_VERSIONS * Device.MAX_FRAME_BUFFERING;

    Data :: struct {
        camera_pos : v3f;
        __padding0 : f32;

        view_matrix     : m3x4;
        inv_view_matrix : m3x4;

        proj_matrix     : m4x4;
        inv_proj_matrix : m4x4;

        view_proj_matrix     : m4x4;
        inv_view_proj_matrix : m4x4;
    } #no_padding

    buffer  : *Buffer;
    handles : StaticArray([MAX_VERSIONS] BindingHandle, Device.MAX_FRAME_BUFFERING);
    version : s32 = -1;
    data    : Data;
}

bindPerViewUniform :: (
    device           : *Device,
    binding_manager  : *BindingManager,
    resource_manager : *ResourceManager,
    uniform          : *PerViewUniform
) {
    uniform.handles.count = cast(s64) device.frame_buffering;

    offset : u32;
    for * uniform.handles {
        for * it.* {
            it.* = pushBinding(device, binding_manager, resource_manager, .PERSISTENT, uniform.buffer, offset, size_of(PerViewUniform.Data));
            offset += size_of(PerViewUniform.Data);
        }
    }
}

resetPerViewUniform :: inline (device : *Device, uniform : *PerViewUniform) {
    // @TODO: #FrameBuffering.
    assert(uniform.handles.count == cast(s64) device.frame_buffering, "It's illegal to change frame buffering for now");
    uniform.version = -1;
}

commitPerViewUniform :: (device : *Device, uniform : *PerViewUniform) {
    uniform.version += 1;
    assert(uniform.version < PerViewUniform.MAX_VERSIONS);

    offset := (device.frame_index * PerViewUniform.MAX_VERSIONS + uniform.version)
            * size_of(PerViewUniform.Data);

    memcpy(uniform.buffer.mapped_memory + offset, *uniform.data, size_of(PerViewUniform.Data));
}

PerFrameUniform :: struct {
    BUFFER_SIZE : u32 : cast(u32) size_of(Data) * Device.MAX_FRAME_BUFFERING;

    Data :: struct {
        frame : u32;
        time  : f32;
        dtime : f32;
    } #no_padding

    buffer : *Buffer;
    data   : Data;
}

bindPerFrameUniform :: inline (
    device           : *Device,
    binding_manager  : *BindingManager,
    resource_manager : *ResourceManager,
    uniform          : *PerFrameUniform
) {
    offset := device.frame_index * size_of(PerFrameUniform.Data);
    pushBinding(device, binding_manager, resource_manager, .PER_FRAME, uniform.buffer, offset, size_of(PerFrameUniform.Data));
}

commitPerFrameUniform :: inline (device : *Device, uniform : *PerFrameUniform) {
    offset := device.frame_index * size_of(PerFrameUniform.Data);
    memcpy(uniform.buffer.mapped_memory + offset, *uniform.data, size_of(PerFrameUniform.Data));
}

PushConstants :: struct {
    per_view_uniform_index : u32;
} #no_padding

petMain :: () {
    initial_time := Basic.current_time_monotonic();

    context.pet.thread_name = "Main";
    context.pet.thread_kind = .MAIN;

    // @TODO: #Settings. Get persistent arena capacity from settings.
    createArena(*context.pet.persistent_arena, gigaBytes(1), "Persistent");
    defer destroyArena(*context.pet.persistent_arena);

    // @TODO: #Settings. Get per frame arena capacity from settings.
    createArena(*context.pet.per_frame_arena, megaBytes(512), "Per frame");
    defer destroyArena(*context.pet.per_frame_arena);

    convertExchangeAssetsToRuntime();

    window_manager := createWindowManager();
    defer destroyWindowManager(window_manager);

    // @TODO: #Settings. Get surface dimension from settings.
    window := createWindow(window_manager, surface_width = 960, surface_height = 540);
    defer destroyWindow(window);

    createInput(window);
    defer destroyInput();

    // @TODO: #Settings.
    //    - Get graphics API from settings.
    //    - Get buffering from settings.
    //    - Get render resolution from settings.
    device := createDevice(.VULKAN, window, .DOUBLE, .P_NATIVE);
    defer destroyDevice(device);

    resource_manager := createResourceManager(device);
    defer destroyResourceManager(device, resource_manager);

    asset_manager := createAssetManager(device, resource_manager);

    shader_manager := createShaderManager(device, resource_manager);
    defer destroyShaderManager(device, shader_manager);

    binding_manager := createBindingManager(device, resource_manager);
    defer destroyBindingManager(device, binding_manager);

    shaders_hot_reload : ShadersHotReload;
    createShadersHotReload(*shaders_hot_reload, device, shader_manager, binding_manager);
    defer destroyShadersHotReload(*shaders_hot_reload);

    per_view_uniform := PerViewUniform.{
        buffer = createBuffer(device, resource_manager, PerViewUniform.BUFFER_SIZE, .PERSISTENT, .UPLOAD, .UNIFORM, "Per view")
    };

    per_frame_uniform := PerFrameUniform.{
        buffer = createBuffer(device, resource_manager, PerFrameUniform.BUFFER_SIZE, .PERSISTENT, .UPLOAD, .UNIFORM, "Per frame")
    };

    depth_buffer := createTexture(device,
                                  resource_manager,
                                  .D32,
                                  device.render_resolution.width,
                                  device.render_resolution.height,
                                  clear_value = .{ depth = 1.0 },
                                  .DEPTH_TARGET | .SHADER_READ,
                                  .PERSISTENT,
                                  "Depth");

    depth_buffer_srv := createTextureView(device, resource_manager, depth_buffer, .SHADER_READ, lifetime = .PERSISTENT);

    depth_sampler := createSampler(device, resource_manager, .{ anisotropy = Sampler.MAX_ANISOTROPY }, .PERSISTENT, "Depth sampler");

    // Create persistent buffers and textures here...

    commitResourceMemory(device, resource_manager, .PERSISTENT);
    defer resetResourceMemory(device, resource_manager, .PERSISTENT);

    // All persistent bindings should be pushed after persistent resource memory commit
    bindPerViewUniform(device, binding_manager, resource_manager, *per_view_uniform);

    defer resetBindings(device, binding_manager, .PERSISTENT);

    test_shader           := createShader(device, shader_manager, binding_manager, "test", .[ getBackBuffer(device).format ]);
    push_constants_handle := getPushConstantsHandle(test_shader, "g_push_constants");

    command_buffer := createCommandBuffer(device, .GRAPHICS);

    mesh : Mesh;

    showWindow(window);
    while processWindowEvents(window) {
        resetArena(*context.pet.per_frame_arena);
        Basic.reset_temporary_storage();

        if window.flags & .MINIMIZED continue;

        //
        // Update
        //

        //
        // Render
        //

        beginFrame(device, window);
        {
            // Reset
            {
                // @TODO: #PerFrameResources. Delete unused per frame resources memory when number of swapchain buffers is decreased.
                resetResourceMemory(device, resource_manager, .PER_FRAME);
                resetAssetManager(device, asset_manager);
                resetShaderManager(device, shader_manager);
                resetBindings(device, binding_manager, .PER_FRAME);
                resetCommandBuffer(device, *command_buffer, binding_manager);
                resetPerViewUniform(device, *per_view_uniform);
            }

            // Create per frame resources here...

            // Commit
            {
                // @TODO: #PerFrameResources. Should we be able to upload data to per frame resources?
                //        Maybe we want to restrict it?
                //        Also it seems like we have to restrict having any owners other than .GRAPHICS for per frame resources
                //        since we do not want to release memory which is in use by async queues.
                commitResourceMemory(device, resource_manager, .PER_FRAME);
            }

            // Open new scene
            if window.input.keyboard[Input.Key.O] & .PRESSED {
                // Reset
                resetResourceMemory(device, resource_manager, .PER_SCENE);
                resetBindings(device, binding_manager, .PER_SCENE);

                // Create per scene resources here...
                mesh = loadMesh(device, asset_manager, resource_manager, "HumanHeart_OBJ");

                // Commit
                commitResourceMemory(device, resource_manager, .PER_SCENE);
            }

            // Update per frame uniform
            bindPerFrameUniform(device, binding_manager, resource_manager, *per_frame_uniform);
            per_frame_uniform.data.frame += 1;
            {
                time_now := cast(f32) Basic.to_float64_seconds(Basic.current_time_monotonic() - initial_time);
                per_frame_uniform.data.dtime = time_now - per_frame_uniform.data.time;
                per_frame_uniform.data.time  = time_now;
            }
            commitPerFrameUniform(device, *per_frame_uniform);

            // Update per view uniform
            per_view_uniform.data.camera_pos  = v3f.{ 1.0, 2.0, 3.0 } * (1.0 + device.frame_index);
            per_view_uniform.data.view_matrix = identity(m3x4) * (1.0 + device.frame_index);
            per_view_uniform.data.proj_matrix = .{
                 1.0,  2.0,  3.0,  4.0,
                 5.0,  6.0,  7.0,  8.0,
                 9.0, 10.0, 11.0, 12.0,
                13.0, 14.0, 15.0, 16.0,
            };
            commitPerViewUniform(device, *per_view_uniform);

            back_buffer_view := getBackBufferView(device, .COLOR_TARGET);
            back_buffer      := back_buffer_view.texture;

            clearTexture(device, *command_buffer, depth_buffer);

            beginRendering(device, *command_buffer, .[
                .{
                    view         = back_buffer_view,
                    load_action  = .CLEAR,
                    store_action = .STORE,
                },
            ]);
            {
                setViewport(device, *command_buffer, *(Viewport.{ 0.0, 0.0, cast(f32) back_buffer.width, cast(f32) back_buffer.height, 0.0, 1.0 }), back_buffer.height);
                setScissorRect(device, *command_buffer, *(ScissorRect.{ 0, 0, back_buffer.width, back_buffer.height }));

                setShader(device, *command_buffer, shader_manager, binding_manager, test_shader);

                setPushConstants(device, *command_buffer, push_constants_handle, *(PushConstants.{
                    per_view_uniform_index = per_view_uniform.handles[device.frame_index][per_view_uniform.version].descriptor,
                }));

                drawPrimitives(device, *command_buffer, 4);
            }
            endRendering(device, *command_buffer);
        }
        endFrame(device);
    }

    waitDeviceIdle(device);
}

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

Basic      :: #import "Basic"()(ENABLE_ASSERT = DEBUG_BUILD, TEMP_ALLOCATOR_POISON_FREED_MEMORY = DEBUG_BUILD);
String     :: #import "String";
Reflection :: #import "Reflection";

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

        command_line.count = c_style_strlen(cast(*u8) command_line.data);
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
    context.print_style.default_format_struct.use_long_form_if_more_than_this_many_members = -1;
    context.print_style.default_format_struct.use_newlines_if_long_form                    = true;
    context.print_style.default_format_absolute_pointer.minimum_digits                     = 16;
    context.print_style.default_format_absolute_pointer.comma_string                       = "'";

    temporary_storage : Temporary_Storage;
    context.temporary_storage = *temporary_storage;

    // TEMPORARY_STORAGE_SIZE is defined by the compiler based on Build_Options.temporary_storage_size
    temporary_storage_data : [TEMPORARY_STORAGE_SIZE] u8 #align 64;
    set_initial_data(context.temporary_storage, TEMPORARY_STORAGE_SIZE, temporary_storage_data.data);

    context.allocator = .{ Allocator.rpmalloc_allocator_proc, null };

    context.allocator.proc(.STARTUP, 0, 0, null, context.allocator.data);
    defer context.allocator.proc(.SHUTDOWN, 0, 0, null, context.allocator.data);

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

#if !DEBUG_BUILD {
    Allocator :: #import "rpmalloc"(ENABLE_STATISTICS    = DEBUG_BUILD,
                                    ENABLE_ASSERTS       = DEBUG_BUILD,
                                    ENABLE_VALIDATE_ARGS = DEBUG_BUILD,
                                    LINUX_FREE_ADVICE    = .FREE);
} else {
    Allocator :: #import "rpmalloc"(ENABLE_STATISTICS    = DEBUG_BUILD,
                                    ENABLE_ASSERTS       = DEBUG_BUILD,
                                    ENABLE_VALIDATE_ARGS = DEBUG_BUILD,
                                    LINUX_FREE_ADVICE    = .DONTNEED);
}
