#import "Compiler";
#import "Basic";
#import "String";
#import "File";
#import "File_Utilities";

Configuration :: enum u8 {
    DEBUG                   :: 0;
    RELEASE                 :: 1;
    RELEASE_WITH_DEBUG_INFO :: 2;
}

BuildArguments :: struct {
    configuration := Configuration.DEBUG;
}

gatherBuildArguments :: (build_options : *Build_Options) -> BuildArguments {
    arguments : BuildArguments;

    for build_options.compile_time_command_line {
        if it == {
            case "debug";                   arguments.configuration = .DEBUG;
            case "release";                 arguments.configuration = .RELEASE;
            case "release_with_debug_info"; arguments.configuration = .RELEASE_WITH_DEBUG_INFO;
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

    build_arguments := gatherBuildArguments(*build_options);

    //
    // Make some strings
    //

    builder : String_Builder;

    configuration_name := to_lower_copy((cast(*Type_Info_Enum) Configuration).names[build_arguments.configuration]);

    workspace_name : string = ---;
    {
        print_to_builder(*builder, "%/%", OS, configuration_name);
        workspace_name = builder_to_string(*builder);
        to_lower_in_place(workspace_name);
    }

    intermediate_path : string = ---;
    {
        print_to_builder(*builder, "../intermediates/%", workspace_name);
        intermediate_path = builder_to_string(*builder);
    }

    output_path : string = ---;
    {
        print_to_builder(*builder, "../output/%", workspace_name);
        output_path = builder_to_string(*builder);
    }

    normalized_build_filename : string = ---;
    {
        success : bool = ---;
        normalized_build_filename, success = get_absolute_path("../source/engine/first.jai");
        assert(success);
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

    build_options.output_type                         = .EXECUTABLE;
    build_options.runtime_storageless_type_info       = false;
    build_options.use_visual_studio_message_format    = true;
    build_options.use_natvis_compatible_types         = false;
    build_options.dead_code_elimination               = .ALL;
    build_options.backtrace_on_crash                  = .OFF;
    build_options.info_flags                          = .POLYMORPH_DEDUPLICATE;
                                                   // | .POLYMORPH_MATCH;
    build_options.text_output_flags                   = .OUTPUT_TIMING_INFO;
    build_options.output_executable_name              = "engine";
    build_options.output_path                         = output_path;
    build_options.intermediate_path                   = intermediate_path;
    build_options.entry_point_name                    = "main";
    build_options.import_path                         = .[ "D:/jai/modules", "../source" ];
    build_options.additional_linker_arguments         = .[ "/LIBPATH:../third_party/vulkan_1.3.243.0" ];

    //
    // Configuration specific options
    //

    if #complete build_arguments.configuration == {
        case .DEBUG;
            set_optimization(*build_options, .VERY_DEBUG, true);

        case .RELEASE;
            set_optimization(*build_options, .VERY_OPTIMIZED, false);

        case .RELEASE_WITH_DEBUG_INFO;
            set_optimization(*build_options, .VERY_OPTIMIZED, true);
    }

    //
    // Create and initialize workspace
    //

    workspace := compiler_create_workspace(workspace_name);
    defer compiler_destroy_workspace(workspace);

    set_build_options(build_options, workspace);
    add_build_file(normalized_build_filename, workspace);
}