#scope_file

BuildArguments :: struct {
    optimized     : bool;
    no_debug_info : bool;
    verbose       : bool;
}

CONFIG_STRING :: #string END
DEBUG_BUILD            :: %;
PRINT_VERBOSE_MESSAGES :: %;
END;

#run {
    checkCompilerVersion(.{0, 2, 2});

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
                      "/SUBSYSTEM:WINDOWS",
                      "/MANIFEST:EMBED",
                      "/MANIFESTINPUT:windows.manifest",
                      "/IGNORE:4216", // LNK4216: Exported entry point WinMainCRTStartup
                      join("/LIBPATH:", vk_sdk_path, "/Lib",, allocator = temp),
                      "/LIBPATH:../third_party/spirv_reflect");

            if build_arguments.optimized {
                array_add(*additional_linker_arguments, "/LTCG"); // For SPIRV-Reflect
                array_add(*additional_linker_arguments, "/STACK:0x100000,0x100000");
            }

            if !build_arguments.optimized || !build_arguments.no_debug_info {
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

    check(make_directory_if_it_does_not_exist(intermediate_path, true));
    check(make_directory_if_it_does_not_exist(output_path, true));

    //
    // Common build options
    //

    build_options.use_visual_studio_message_format        = true;
    build_options.dead_code_elimination                   = .ALL;
    build_options.runtime_support_definitions             = .OMIT;
    build_options.backtrace_on_crash                      = .OFF;
    build_options.prevent_compile_time_calls_from_runtime = false; // @TODO: Replace with true when it will work properly
    build_options.info_flags                              = .POLYMORPH_DEDUPLICATE; // | .POLYMORPH_MATCH;
    build_options.text_output_flags                       = .OUTPUT_TIMING_INFO;    // | .OUTPUT_LINK_LINE;
    build_options.output_executable_name                  = "engine";
    build_options.output_path                             = output_path;
    build_options.intermediate_path                       = intermediate_path;
    build_options.import_path                             = import_paths;
    build_options.additional_linker_arguments             = additional_linker_arguments;

    //
    // Configuration specific options
    //

    if build_arguments.optimized {
        set_optimization(*build_options, .VERY_OPTIMIZED, !build_arguments.no_debug_info);
        build_options.backend = .LLVM;
    } else {
        set_optimization(*build_options, .VERY_DEBUG, true);
        build_options.arithmetic_overflow_check = .FATAL;
    }

    //
    // Check CPU
    //

    #if CPU == .X64 {
        machine_options := get_machine_options_x86(*build_options);
        cpu_info        := get_cpu_info();

        X64_FEATURES :: x86_Feature_Flag.[
            .TSC,
            .CX8, .CMOV, .MOVBE,
            .ABM, .BMI1,
            .SSE, .SSE2, .SSE3, .SSSE3, .SSE4_1, .SSE4_2, .AVX, .FMA
        ];

        for X64_FEATURES {
            if !check_feature(machine_options.features.leaves, it) {
                feature_supported := check_feature(cpu_info.feature_leaves, it);
                check(feature_supported, "Required feature % is not supported", it, print_sys_error = false);

                print("Enabling required feature % which is not enabled by default, but is supported on this CPU\n", it);
                enable_feature(*machine_options.features.leaves, it);
            }
        }

        features_to_check_string : string;
        {
            builder := String_Builder.{ allocator = temp };

            append(*builder, "FEATURES_TO_CHECK :: Machine_X64.x86_Feature_Flag.[\n");
            for X64_FEATURES {
                print(*builder, "    .%,\n", it);
            }
            append(*builder, "];");

            features_to_check_string = builder_to_string(*builder,, allocator = temp);
        }
    }

    //
    // Do some platform specific stuff we cannot do through the code
    //

    #if OS == .WINDOWS {
        prepareManifest(build_options.output_executable_name);
    }

    //
    // Create and initialize workspace
    //

    workspace := compiler_create_workspace(workspace_name);
    defer compiler_destroy_workspace(workspace);

    set_build_options(build_options, workspace);

    compiler_begin_intercept(workspace);
    {
        add_build_string(tprint(CONFIG_STRING, !build_arguments.optimized, build_arguments.verbose), workspace);
        add_build_string(features_to_check_string, workspace);
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

    #if OS == .WINDOWS {
        check(DeleteFileA("windows.manifest"));
    }

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

    info := type_info(BuildArguments);
    assert(info.type == .STRUCT);

    for command_line_argument : build_options.compile_time_command_line {
        member : *Type_Info_Struct_Member;
        for * info.members {
            if it.name == command_line_argument {
                member = it;
                break;
            }
        }

        if member {
            (cast(*bool) *arguments + member.offset_in_bytes).* = true;
        } else {
            compiler_report(join("Unknown command line argument: ", command_line_argument,, allocator = temp));
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

checkCompilerVersion :: (minimal_supported_version : Version_Info) {
    compareCompilerVersions :: (left : Version_Info, right : Version_Info) -> s8 {
        if left.major < right.major return -1;
        if left.major > right.major return  1;
        if left.minor < right.minor return -1;
        if left.minor > right.minor return  1;
        if left.micro < right.micro return -1;
        if left.micro > right.micro return  1;
        return 0;
    }

    compiler_version : Version_Info = ---;
    compiler_version_str := compiler_get_version_info(*compiler_version);
    if compareCompilerVersions(compiler_version, minimal_supported_version) < 0 {
        message := tprint("Compiler version you are using is %, minimal supported is %.%.%",
                          compiler_version_str,
                          minimal_supported_version.major,
                          minimal_supported_version.minor,
                          FormatInt.{ value = minimal_supported_version.micro, minimum_digits = 3 });
        compiler_report(message);
    }
}

#if OS == .WINDOWS {
    prepareManifest :: (application_name : string) {
        //
        // Write manifest file
        //
MANIFEST_FORMAT_STRING :: #string XML
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <assemblyIdentity language="neutral" name="%" processorArchitecture="*" type="win32" version="1.0.0.0" />
  <application>
    <windowsSettings>
      <activeCodePage xmlns="http://schemas.microsoft.com/SMI/2019/WindowsSettings">UTF-8</activeCodePage>
    </windowsSettings>
  </application>
</assembly>
XML;
        manifest := tprint(MANIFEST_FORMAT_STRING, application_name);

        // We cannot use FILE_ATTRIBUTE_TEMPORARY | FILE_FLAG_DELETE_ON_CLOSE because:
        // "general error c1010070: Failed to load and parse the manifest. The process cannot access the file because it is being used by another process."
        file := CreateFileA("windows.manifest", GENERIC_WRITE, 0, null, CREATE_NEW, FILE_ATTRIBUTE_HIDDEN, null);
        check(file != INVALID_HANDLE_VALUE);

        check(WriteFile(file, manifest.data, cast(u32) manifest.count, null, null));

        check(CloseHandle(file));

        //
        // Add mt.exe to PATH
        //

        program_files_path := to_string(getenv("ProgramFiles(x86)"));

        search_path := join(program_files_path, "\\Windows Kits\\10\\bin\\10.*\0",, allocator = temp);

        find_data : WIN32_FIND_DATAA;
        find_handle := FindFirstFileExA(search_path.data, .FindExInfoBasic, *find_data, .FindExSearchLimitToDirectories, null, 0);
        check(find_handle != INVALID_HANDLE_VALUE);

        Version :: [4] u32;

        max :: (a : Version, b : Version) -> Version {
            for 0 .. a.count - 1 {
                if a[it] > b[it] return a;
                if a[it] < b[it] return b;
            }
            return a;
        }

        latest_version : Version;
        while true {
            check(find_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY);

            dirname := to_string(find_data.cFileName.data);

            version : Version;
            for * version {
                it.*, success:, dirname = string_to_int(dirname, T = u32);
                check(success);

                if dirname && dirname[0] == #char "." {
                    advance(*dirname);
                } else {
                    break;
                }
            }

            latest_version = max(version, latest_version);

            if !FindNextFileA(find_handle, *find_data) {
                check(GetLastError() == ERROR_NO_MORE_FILES);
                break;
            }
        }

        mt_folder := tprint("%\\Windows Kits\\10\\bin\\%.%.%.%\\x64\0",
                            program_files_path,
                            latest_version[0],
                            latest_version[1],
                            latest_version[2],
                            latest_version[3]);
        print("mt.exe location: \"%\"\n", mt_folder);

        path_value := to_string(getenv("PATH"));
        if !contains(path_value, mt_folder) {
            new_path_value := join(path_value, ";", mt_folder,, allocator = temp);
            check(SetEnvironmentVariableA("PATH", new_path_value.data));
        }
    }
}

check :: (expression : Code, format := "", args: ..Any, $print_sys_error := true, location := #caller_location) #expand {
    result := #insert expression;

    success : bool = ---;
    #if type_of(result) == {
        case bool; success = result;
        case BOOL; success = result == TRUE;
        case s32;  success = result == TRUE;
        case u32;  success = result != 0;
        case;
            compiler_report(tprint("Unhandled type: %", type_of(result)));
    }

    if success return;

    #if OS == .WINDOWS && print_sys_error {
        sys_error_code := GetLastError();
    }

    builder := String_Builder.{ allocator = temp };

    if format {
        if args.count > 0 {
            print(*builder, format, ..args);
        } else {
            append(*builder, format);
        }
    } else {
        root := compiler_get_nodes(expression);
        print_expression(*builder, root);
    }

    #if OS == .WINDOWS && print_sys_error {
        if sys_error_code != ERROR_SUCCESS {
            sys_error_message_buffer : [1024] u8 = ---;
            sys_error_message_length := FormatMessageA(FORMAT_MESSAGE_IGNORE_INSERTS | FORMAT_MESSAGE_FROM_SYSTEM,
                                                       null,
                                                       sys_error_code,
                                                       MAKELANGID(LANG_ENGLISH, SUBLANG_ENGLISH_US),
                                                       cast,no_check(**u8) sys_error_message_buffer.data,
                                                       sys_error_message_buffer.count,
                                                       null);
            sys_error_message_length -= ".\r\n".count;
            assert(sys_error_message_length > 0);

            sys_error_message := string.{ sys_error_message_length, sys_error_message_buffer.data };
            print(*builder, ". System error (%): %", sys_error_code, sys_error_message);
        }
    }

    message := builder_to_string(*builder);
    compiler_report(message, loc = location);
}

#if OS == .WINDOWS {
    TRUE :: 1;

    ERROR_SUCCESS       :: 0;
    ERROR_NO_MORE_FILES :: 18;

    SUBLANG_ENGLISH_US : u16 : 0x01;

    WIN32_FIND_DATAA :: struct {
        dwFileAttributes   : u32;
        ftCreationTime     : FILETIME;
        ftLastAccessTime   : FILETIME;
        ftLastWriteTime    : FILETIME;
        nFileSizeHigh      : u32;
        nFileSizeLow       : u32;
        dwReserved0        : u32;
        dwReserved1        : u32;
        cFileName          : [MAX_PATH] u8;
        cAlternateFileName : [14]       u8;
        dwFileType         : u32; // Obsolete. Do not use.
        dwCreatorType      : u32; // Obsolete. Do not use
        wFinderFlags       : u16; // Obsolete. Do not use
    }

    SetEnvironmentVariableA :: (
        lpName  : LPCSTR,
        lpValue : LPCSTR
    ) -> BOOL #foreign kernel32;

    kernel32 :: #library,system "kernel32";
}

#import "Compiler";
#import "Basic";
#import "String";
#import "File";
#import "File_Utilities";
#import "Check";
#import "Program_Print";
#if CPU == .X64 {
    #import "Machine_X64";
}
#if OS == .WINDOWS {
    #import "Windows";
} else if OS == .POSIX {
    #import "POSIX";
} else {
    #assert false "Not implemented";
}
