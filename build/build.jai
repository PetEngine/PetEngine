#scope_file

#import "Compiler";
#import "Basic";
#import "String";
#import "File";
#import "Check";

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

    import_paths : [..] string;
    {
        import_paths.allocator = temporary_allocator;
        array_add(*import_paths, ..build_options.import_path);
        array_add(*import_paths, "../source");
    }

    additional_linker_arguments : [..] string;
    {
        additional_linker_arguments.allocator = temporary_allocator;
        array_add(*additional_linker_arguments, ..build_options.additional_linker_arguments);

        #if OS == .WINDOWS {
            array_add(*additional_linker_arguments,
                      "/LIBPATH:../third_party/vulkan",
                      "/LIBPATH:../third_party/shaderc",
                      "/LIBPATH:../third_party/spirv_reflect");

            if #complete build_arguments.configuration == {
                case .DEBUG;
                    array_add(*additional_linker_arguments, "/DEBUG:FULL"); // For RemedyBG
                case .RELEASE;
                    array_add(*additional_linker_arguments, "/LTCG");       // For SPIRV-Reflect
                case .RELEASE_WITH_DEBUG_INFO;
                    array_add(*additional_linker_arguments, "/DEBUG:FULL"); // For RemedyBG
                    array_add(*additional_linker_arguments, "/LTCG");       // For SPIRV-Reflect
            }
        } else {
            array_add(*additional_linker_arguments,
                      "--library-path=../third_party/vulkan",
                      "--library-path=../third_party/shaderc",
                      "--library-path=../third_party/spirv_reflect");
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
    build_options.info_flags                       = .POLYMORPH_DEDUPLICATE; // | .POLYMORPH_MATCH;
    build_options.text_output_flags                = .OUTPUT_TIMING_INFO;    // | .OUTPUT_LINK_LINE;
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
            build_options.arithmetic_overflow_check = .FATAL;

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

    compiler_begin_intercept(workspace);
    {
        add_build_file(build_filename, workspace);

        while loop := true {
            message := compiler_wait_for_message();
            if message.kind == {
                case .TYPECHECKED;
                    do_error_checking(null, message);

                case .COMPLETE;
                    complete := cast(*Message_Complete) message;
                    if complete.error_code == {
                        case .NONE;               write_string("\nCompilation succeeded\n");
                        case .COMPILATION_FAILED; write_string("\nCompilation failed\n");
                    }
                    break loop;
            }
        }
    }
    compiler_end_intercept(workspace);
}
