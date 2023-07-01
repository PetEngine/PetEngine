#import "Compiler";
#import "Basic";
#import "String";
#import "File";
#import "File_Utilities";
#import "Process";

Configuration :: enum u8 {
    DEBUG                   :: 0;
    RELEASE                 :: 1;
    RELEASE_WITH_DEBUG_INFO :: 2;
}

BuildArguments :: struct {
    configuration   := Configuration.DEBUG;
    compile_shaders := false;
}

gatherBuildArguments :: (build_options : *Build_Options) -> BuildArguments {
    arguments : BuildArguments;

    for build_options.compile_time_command_line {
        if it == {
            case "debug";
                arguments.configuration = .DEBUG;
            case "release";
                arguments.configuration = .RELEASE;
            case "release_with_debug_info";
                arguments.configuration = .RELEASE_WITH_DEBUG_INFO;
            case "shaders";
                arguments.compile_shaders = true;
            case;
                compiler_report(join("Unknown command line argument: ", it, allocator = temporary_allocator));
        }
    }

    return arguments;
}

#run {
    build_options := get_build_options();

    //
    // First of all, let's disable output for the current (build) workspace
    //

    set_build_options_dc(.{ do_output = false });

    //
    // Gather build arguments
    //

    build_arguments := gatherBuildArguments(*build_options);

    //
    // Make some strings
    //

    project_folder : string = ---;
    {
        project_folder = #location().fully_pathed_filename;
        project_folder.count = find_index_from_right(project_folder, #char "/");
        assert(project_folder.count != -1);
        project_folder.count = find_index_from_right(project_folder, #char "/");
        assert(project_folder.count != -1);
    }

    workspace_name : string = ---;
    {
        builder : String_Builder;
        print_to_builder(*builder, "%/%", OS, build_arguments.configuration);
        workspace_name = builder_to_string(*builder);
        to_lower_in_place(workspace_name);
    }

    intermediate_path   := join(project_folder, "/intermediates/", workspace_name, allocator = temporary_allocator);
    output_path         := join(project_folder, "/output/",        workspace_name, allocator = temporary_allocator);
    shaders_input_path  := join(project_folder, "/source/shaders",                 allocator = temporary_allocator);
    shaders_output_path := join(output_path,    "/shaders",                        allocator = temporary_allocator);
    build_filename      := join(project_folder, "/source/engine/first.jai",        allocator = temporary_allocator);

    import_paths : [1 /* build_options.import_path.count */ + 1] string = ---;
    {
        for build_options.import_path {
            import_paths[it_index] = it;
        }
        import_paths[build_options.import_path.count + 0] = "../source";
    }

    additional_linker_arguments : [0 /* build_options.additional_linker_arguments.count */ + 2] string = ---;
    {
        for build_options.additional_linker_arguments {
            additional_linker_arguments[it_index] = it;
        }

        #if OS == .WINDOWS {
            additional_linker_arguments[build_options.additional_linker_arguments.count + 0] = "/LIBPATH:../third_party/vulkan";
            if build_arguments.configuration == {
                case .DEBUG; #through;
                case .RELEASE_WITH_DEBUG_INFO;
                    additional_linker_arguments[build_options.additional_linker_arguments.count + 1] = "/DEBUG:FULL"; // For RemedyBG
                case;
                    additional_linker_arguments[build_options.additional_linker_arguments.count + 1] = "";
            }
        } else {
            additional_linker_arguments[build_options.additional_linker_arguments.count + 0] = "--library-path=../third_party/vulkan";
            additional_linker_arguments[build_options.additional_linker_arguments.count + 1] = "";
        }
    }

    //
    // Create must have directories
    //

    success := make_directory_if_it_does_not_exist(intermediate_path, true);
    assert(success);

    success = make_directory_if_it_does_not_exist(output_path, true);
    assert(success);

    //
    // Common build options
    //

    build_options.output_type                      = .EXECUTABLE;
    build_options.use_visual_studio_message_format = true;
    build_options.dead_code_elimination            = .ALL;
    build_options.backtrace_on_crash               = .OFF;
    build_options.info_flags                       = .POLYMORPH_DEDUPLICATE;
                                                // | .POLYMORPH_MATCH;
    build_options.text_output_flags                = .OUTPUT_TIMING_INFO;
    build_options.output_executable_name           = "engine";
    build_options.output_path                      = output_path;
    build_options.intermediate_path                = intermediate_path;
    build_options.entry_point_name                 = "main";
    build_options.import_path                      = import_paths;
    build_options.additional_linker_arguments      = additional_linker_arguments;

    //
    // Configuration specific options
    //

    if #complete build_arguments.configuration == {
        case .DEBUG;
            set_optimization(*build_options, .VERY_DEBUG, true);
            build_options.debug_for_expansions = true;
            build_options.backend              = .X64;

        case .RELEASE;
            set_optimization(*build_options, .VERY_OPTIMIZED, false);
            build_options.backend = .LLVM;

        case .RELEASE_WITH_DEBUG_INFO;
            set_optimization(*build_options, .VERY_OPTIMIZED, true);
            build_options.backend = .LLVM;
    }

    //
    // Create and initialize workspace
    //

    workspace := compiler_create_workspace(workspace_name);
    defer compiler_destroy_workspace(workspace);

    set_build_options(build_options, workspace);
    add_build_file(build_filename, workspace);

    //
    // Compile shaders
    //

    if build_arguments.compile_shaders {
        write_string("Compiling shaders...\n");
        defer write_string("Done.\n\n");

        state : struct {
            input_root      : string;
            output_root     : string;
            build_arguments : *BuildArguments;

            input_filenames  : [..] string;
            output_filenames : [..] string;
        } = .{
            input_root      = shaders_input_path,
            output_root     = shaders_output_path,
            build_arguments = *build_arguments
        };

        defer {
            for state.output_filenames free(it.data);
            array_free(state.output_filenames);

            for state.input_filenames  free(it.data);
            array_free(state.input_filenames);
        }

        visit_files(state.input_root, true, *state, (info : *File_Visit_Info, state : *$T) {
            array_add(*state.input_filenames, copy_string(info.full_name));

            relative_path := slice(info.full_name, state.input_root.count, info.full_name.count - state.input_root.count);
            output_file   := join(state.output_root, relative_path, ".spv");
            array_add(*state.output_filenames, output_file);

            output_folder : string = ---;
            output_folder.data  = output_file.data;
            output_folder.count = find_index_from_right(output_file, #char "/");
            assert(output_folder.count != -1);

            success := make_directory_if_it_does_not_exist(output_folder, true);
            assert(success);
        });

        debug_info_argunent : string = ---;
        if state.build_arguments.configuration == {
            case .DEBUG; #through;
            case .RELEASE_WITH_DEBUG_INFO;
                debug_info_argunent = "-g";
            case;
                debug_info_argunent = "-g0";
        }

        for state.output_filenames {
            process_result, stdout, stderr := run_command("glslangValidator",
                                                          join("-I", state.input_root, allocator = temporary_allocator),
                                                          debug_info_argunent,
                                                          "-o", it,
                                                          "-t",
                                                          "--glsl-version", "460",
                                                          "--enhanced-msgs",
                                                          "--target-env", "vulkan1.3",
                                                          state.input_filenames[it_index],
                                                          capture_and_return_output = true,
                                                          print_captured_output     = true);

            if process_result.exit_code != 0 || stderr || contains(stdout, "ERROR:") {
                compiler_report("Shader compilation has failed");
            }
        }
    }
}
