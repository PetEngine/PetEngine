#scope_file

#import "Compiler";
#import "Basic";
#import "String";
#import "File";

Configuration :: enum u8 {
    DEBUG;
    RELEASE;
    RELEASE_WITH_DEBUG_INFO;
}

BuildArguments :: struct {
    configuration : Configuration = .DEBUG;
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

    intermediate_path := join(project_folder, "/intermediates/", workspace_name, allocator = temporary_allocator);
    output_path       := join(project_folder, "/output/",        workspace_name, allocator = temporary_allocator);
    build_filename    := join(project_folder, "/source/engine/first.jai",        allocator = temporary_allocator);

    import_paths : [1 /* build_options.import_path.count */ + 1] string = ---;
    {
        for build_options.import_path {
            import_paths[it_index] = it;
        }
        import_paths[build_options.import_path.count + 0] = "../source";
    }

    additional_linker_arguments : [0 /* build_options.additional_linker_arguments.count */ + 4] string = ---;
    {
        for build_options.additional_linker_arguments {
            additional_linker_arguments[it_index] = it;
        }

        #if OS == .WINDOWS {
            additional_linker_arguments[build_options.additional_linker_arguments.count + 0] = "/LIBPATH:../third_party/vulkan";
            additional_linker_arguments[build_options.additional_linker_arguments.count + 1] = "/LIBPATH:../third_party/shaderc";
            additional_linker_arguments[build_options.additional_linker_arguments.count + 2] = "/LIBPATH:../third_party/spirv_reflect";
            if build_arguments.configuration == {
                case .DEBUG; #through;
                case .RELEASE_WITH_DEBUG_INFO;
                    additional_linker_arguments[build_options.additional_linker_arguments.count + 3] = "/DEBUG:FULL"; // For RemedyBG
                case;
                    additional_linker_arguments[build_options.additional_linker_arguments.count + 3] = "";
            }
        } else {
            additional_linker_arguments[build_options.additional_linker_arguments.count + 0] = "--library-path=../third_party/vulkan";
            additional_linker_arguments[build_options.additional_linker_arguments.count + 1] = "--library-path=../third_party/shaderc";
            additional_linker_arguments[build_options.additional_linker_arguments.count + 2] = "--library-path=../third_party/spirv_reflect";
            additional_linker_arguments[build_options.additional_linker_arguments.count + 3] = "";
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
}
