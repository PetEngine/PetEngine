#scope_file

#import "Compiler";
#import "Basic";
#import "String";
#import "File";
#import "File_Utilities";
#import "Check";
#if OS == .WINDOWS {
    #import "Windows";
} else if OS == .POSIX {
    #import "POSIX";
} else {
    #assert false "Not implemented";
}

BuildArguments :: struct {
    optimized  : bool;
    debug_info : bool;
    verbose    : bool;
}

#run {
    context.print_style.default_format_struct.use_newlines_if_long_form = true;

    compiler_version : Version_Info = ---;
    compiler_version_str := compiler_get_version_info(*compiler_version);
    if compareCompilerVersions(compiler_version, .{ 0, 1, 81 }) < 0 {
        compiler_report(join("Compiler version you are using is ", compiler_version_str, ", minimal supported is 0.1.081",, allocator = temp));
    }

    build_options := get_build_options();

    //
    // Disable output for the current (build) workspace
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

    workspace_name := tprint("%/%", OS, ifx build_arguments.optimized then "optimized" else "debug");
    to_lower_in_place(workspace_name);

    intermediate_path := join(project_folder, "/intermediates/", workspace_name,, allocator = temp);
    output_path       := join(project_folder, "/output/",        workspace_name,, allocator = temp);
    build_filename    := join(project_folder, "/source/engine/first.jai",,        allocator = temp);

    import_paths : [..] string;
    {
        import_paths.allocator = temp;
        array_add(*import_paths, ..build_options.import_path);
        array_add(*import_paths, "../source");
    }

    vk_sdk_path := getVulkanSDKPath();
    print("Vulkan SDK path: \"%\"\n", vk_sdk_path);

    additional_linker_arguments : [..] string;
    {
        additional_linker_arguments.allocator = temp;
        array_add(*additional_linker_arguments, ..build_options.additional_linker_arguments);

        #if OS == .WINDOWS {
            array_add(*additional_linker_arguments,
                      join("/LIBPATH:", vk_sdk_path, "/Lib",, allocator = temp),
                      "/LIBPATH:../third_party/spirv_reflect");

            if build_arguments.optimized {
                array_add(*additional_linker_arguments, "/LTCG"); // For SPIRV-Reflect
            }

            if !build_arguments.optimized || build_arguments.debug_info {
                array_add(*additional_linker_arguments, "/DEBUG:FULL"); // For RemedyBG
            }
        } else {
            array_add(*additional_linker_arguments,
                      join("--library-path=", vk_sdk_path, "/Lib",, allocator = temp),
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

    build_options.use_visual_studio_message_format        = true;
    build_options.dead_code_elimination                   = .ALL;
    build_options.backtrace_on_crash                      = .OFF;
//  build_options.prevent_compile_time_calls_from_runtime = true; // Does not work properly yet
    build_options.info_flags                              = .POLYMORPH_DEDUPLICATE; // | .POLYMORPH_MATCH;
    build_options.text_output_flags                       = .OUTPUT_TIMING_INFO;    // | .OUTPUT_LINK_LINE;
    build_options.output_executable_name                  = "engine";
    build_options.output_path                             = output_path;
    build_options.intermediate_path                       = intermediate_path;
    build_options.entry_point_name                        = "main";
    build_options.import_path                             = import_paths;
    build_options.additional_linker_arguments             = additional_linker_arguments;

    //
    // Configuration specific options
    //

    if build_arguments.optimized {
        set_optimization(*build_options, .VERY_OPTIMIZED, build_arguments.debug_info);
        build_options.backend = .LLVM;
    } else {
        set_optimization(*build_options, .VERY_DEBUG, true);
        build_options.arithmetic_overflow_check = .FATAL;
    }

    //
    // Create and initialize workspace
    //

    workspace := compiler_create_workspace(workspace_name);
    defer compiler_destroy_workspace(workspace);

    set_build_options(build_options, workspace);

    compiler_begin_intercept(workspace);
    {
        add_build_string(tprint("DEBUG_BUILD            :: %;", !build_arguments.optimized), workspace);
        add_build_string(tprint("PRINT_VERBOSE_MESSAGES :: %;", build_arguments.verbose),    workspace);
        add_build_file(build_filename, workspace);

        while true {
            message := compiler_wait_for_message();

            if message.kind == {
                case .TYPECHECKED;
                    do_error_checking(null, message);

                case .COMPLETE;
                    break;
            }
        }
    }
    compiler_end_intercept(workspace);

    //
    // Post-build copies
    //

    if build_arguments.optimized {
        copy_file(join(vk_sdk_path, "/Bin/shaderc_shared.dll",, allocator = temp),
                  join(output_path,     "/shaderc_shared.dll",, allocator = temp));
    } else {
        copy_file(join(vk_sdk_path, "/Bin/shaderc_sharedd.dll",, allocator = temp),
                  join(output_path,     "/shaderc_sharedd.dll",, allocator = temp));
    }
}

gatherBuildArguments :: (build_options : *Build_Options) -> BuildArguments {
    arguments : BuildArguments;

    for command_line_argument : build_options.compile_time_command_line {
        if command_line_argument == {
            // @TODO: Use #insert when it will be supported inside 'if == {' block
            case "optimized";  arguments.optimized  = true;
            case "debug_info"; arguments.debug_info = true;
            case "verbose";    arguments.verbose    = true;
            case;
                unhandled : bool;
                for type_info(BuildArguments).members {
                    if it.name == command_line_argument {
                        unhandled = true;
                        break;
                    }
                }

                if unhandled {
                    compiler_report(join("Unhandled command line argument (found in BuildArguments): ", command_line_argument,, allocator = temp));
                } else {
                    compiler_report(join("Unknown command line argument: ", command_line_argument,, allocator = temp));
                }
        }
    }

    return arguments;
}

getVulkanSDKPath :: () -> string {
    path := to_string(getenv("VULKAN_SDK"));
    if !path {
        path = to_string(getenv("VK_SDK_PATH"));
        if !path {
            compiler_report("Neither VULKAN_SDK nor VK_SDK_PATH environment variables were found. Install Vulkan SDK first.");
        }
    }

    for 0 .. path.count - 1 {
        if path[it] == #char "\\" {
            path[it] = #char "/";
        }
    }

    return path;
}

compareCompilerVersions :: (left : Version_Info, right : Version_Info) -> s8 {
    if left.major < right.major return -1;
    if left.major > right.major return  1;
    if left.minor < right.minor return -1;
    if left.minor > right.minor return  1;
    if left.micro < right.micro return -1;
    if left.micro > right.micro return  1;
    return 0;
}
