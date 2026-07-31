#scope_file

GraphicsAPI :: enum u8 {
    VULKAN;
}

BuildArguments :: struct {
    optimized     : bool;
    no_debug_info : bool;
    verbose       : bool;
    graphics_api  : GraphicsAPI = .VULKAN;
}

#run {
    checkCompilerVersion(.{0, 2, 30});

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
        array_add(*import_paths, "../source", "../third_party");
        array_add(*import_paths, ..build_options.import_path);
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
                      "/IGNORE:4216", // LNK4216: Exported entry point WinMainCRTStartup
                      "/STACK:0x100000,0x100000",
                      join("/LIBPATH:", vk_sdk_path, "/Lib",, allocator = temp));

            if build_arguments.optimized {
                array_add(*additional_linker_arguments, "/LTCG"); // For SPIRV-Reflect
            }

            if !build_arguments.no_debug_info {
                array_add(*additional_linker_arguments, "/DEBUG:FULL"); // For RemedyBG
            }
        } else {
            array_add(*additional_linker_arguments,
                      "-z stack-size=0x100000",
                      join("--library-path=", vk_sdk_path, "/Lib",, allocator = temp));
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
    build_options.runtime_support_definitions             = .OMIT;
    build_options.backtrace_on_crash                      = .OFF;
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
        build_options.dead_code_elimination                   = .ALL;
        build_options.prevent_compile_time_calls_from_runtime = true;
        build_options.backend                                 = .LLVM;
    } else {
        set_optimization(*build_options, .VERY_DEBUG, !build_arguments.no_debug_info);
        build_options.arithmetic_overflow_check               = .FATAL;
        build_options.dead_code_elimination                   = .NONE;
        build_options.prevent_compile_time_calls_from_runtime = true;
        build_options.enable_bytecode_inliner                 = false;
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
    // Create and initialize workspace
    //

    workspace := compiler_create_workspace(workspace_name);
    defer compiler_destroy_workspace(workspace);

    set_build_options(build_options, workspace);

    compilation_failed : bool;
    compiler_begin_intercept(workspace);
    {
        addDeclarations(workspace);
        addConfigDefines(build_arguments, workspace);
        #if CPU == .X64 {
            add_build_string(features_to_check_string, workspace);
        }
        add_build_file(build_filename, workspace);

        while true {
            message := compiler_wait_for_message();

            if message.kind == {
                case .TYPECHECKED;
                    do_error_checking(null, message);

                case .COMPLETE;
                    compilation_failed = (cast(*Message_Complete) message).error_code != .NONE;
                    break;
            }
        }
    }
    compiler_end_intercept(workspace);
    if compilation_failed return;

    //
    // Post-build copies
    //

    if build_arguments.optimized {
        copy_file("../third_party/shaderc/bin/shaderc_shared.dll",
                  join(output_path, "/shaderc_shared.dll",, allocator = temp));
    } else {
        copy_file("../third_party/shaderc/bin/shaderc_sharedd.dll",
                  join(output_path, "/shaderc_sharedd.dll",, allocator = temp));
    }
    copy_file("../third_party/nvtt/bin/nvtt30205.dll",
              join(output_path, "/nvtt30205.dll",, allocator = temp));

    //
    // Do some platform specific stuff we cannot do through the code
    //

    #if OS == .WINDOWS {
        addManifest(build_options.output_path, build_options.output_executable_name);
    }
}

gatherBuildArguments :: (build_options : *Build_Options) -> BuildArguments {
    arguments : BuildArguments;

    INFO :: type_info(BuildArguments);
    #assert INFO.type == .STRUCT;

    for command_line_argument : build_options.compile_time_command_line {
        for * member : INFO.members {
            if member.flags & (.CONSTANT | .OVERLAY) continue;

            if member.type.type == {
                case .BOOL;
                    if member.name == command_line_argument {
                        (cast(*bool, *arguments) + member.offset_in_bytes).* = true;
                        continue command_line_argument;
                    }

                case .ENUM;
                    enum_info := cast(*Type_Info_Enum, member.type);
                    if enum_info.enum_type_flags & .FLAGS {
                        compiler_report(tprint("enum_flags are not supported in command line arguments: %", enum_info.name));
                    }

                    for enum_info.names {
                        if !equal_nocase(it, command_line_argument) continue;

                        memory := cast(*void, *arguments) + member.offset_in_bytes;
                        value  := enum_info.values[it_index];

                        if enum_info.runtime_size == {
                            case 1;
                                if enum_info.internal_type.signed {
                                    cast(*s8, memory).* = cast(s8, value);
                                } else {
                                    cast(*u8, memory).* = cast(u8, value);
                                }

                            case 2;
                                if enum_info.internal_type.signed {
                                    cast(*s16, memory).* = cast(s16, value);
                                } else {
                                    cast(*u16, memory).* = cast(u16, value);
                                }

                            case 4;
                                if enum_info.internal_type.signed {
                                    cast(*s32, memory).* = cast(s32, value);
                                } else {
                                    cast(*u32, memory).* = cast(u32, value);
                                }

                            case 8;
                                if enum_info.internal_type.signed {
                                    cast(*s64, memory).* = cast(s64, value);
                                } else {
                                    cast(*u64, memory).* = cast(u64, value);
                                }

                            case;
                                compiler_report(tprint("Unexpected size of an enum %: % bytes", enum_info.name, enum_info.runtime_size));
                        }

                        continue command_line_argument;
                    }
            }
        }

        compiler_report(join("Unknown command line argument: ", command_line_argument,, allocator = temp));
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
    addManifest :: (output_path : string, application_name : string) {
        //
        // Generate
        //

        manifest := tprint(MANIFEST_FORMAT_STRING, application_name);

        //
        // Write
        //

        exe_path := join(output_path, "/", application_name, ".exe",, allocator = temp);

        utf16_exe_path, success := utf8_to_wide(exe_path,, allocator = temp);
        check(success, "utf8_to_wide(\"%\") has failed", exe_path);

        handle := BeginUpdateResourceW(utf16_exe_path, FALSE);
        check(handle != null, "BeginUpdateResourceW(\"%\", FALSE) has failed", exe_path);

        RESOURCE_ID :: cast(*u16) 1; // resource ID == 1 allows to skip some stuff
        language_id := MAKELANGID(LANG_ENGLISH, SUBLANG_DEFAULT);

        check(UpdateResourceW(handle, RT_MANIFEST, RESOURCE_ID, language_id, manifest.data, cast(u32) manifest.count));

        check(EndUpdateResourceW(handle, FALSE));
    }

    MANIFEST_FORMAT_STRING :: #string XML
<?xml version="1.0" encoding="UTF-8"?>
<asm:assembly xmlns:asm="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
    <asm:assemblyIdentity type="win32" name="%" processorArchitecture="amd64" version="1.0.0.0" />
        <comp:compatibility xmlns:comp="urn:schemas-microsoft-com:compatibility.v1">
            <comp:application>
                <!-- Windows 10 and Windows 11 -->
                <comp:supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}" />
            </comp:application>
        </comp:compatibility>
    <asm:application>
        <asm:windowsSettings xmlns:ws05="http://schemas.microsoft.com/SMI/2005/WindowsSettings"
                             xmlns:ws16="http://schemas.microsoft.com/SMI/2016/WindowsSettings"
                             xmlns:ws19="http://schemas.microsoft.com/SMI/2019/WindowsSettings"
                             xmlns:ws20="http://schemas.microsoft.com/SMI/2020/WindowsSettings">
            <ws05:disableTheming>false</ws05:disableTheming>
            <ws05:dpiAware>true</ws05:dpiAware>
            <ws16:dpiAwareness>permonitorv2, permonitor, system</ws16:dpiAwareness>
            <ws16:longPathAware>true</ws16:longPathAware>
            <ws19:activeCodePage>UTF-8</ws19:activeCodePage>
            <ws20:heapType>SegmentHeap</ws20:heapType>
        </asm:windowsSettings>
    </asm:application>
    <asm:trustInfo>
        <asm:security>
            <asm:requestedPrivileges>
                <asm:requestedExecutionLevel level="asInvoker" uiAccess="false" />
            </asm:requestedPrivileges>
        </asm:security>
    </asm:trustInfo>
</asm:assembly>
XML;
}

check :: (expression : Code, format := "", args: ..Any, $print_sys_error := true, location := #caller_location) #expand {
    result := #insert expression;

    success : bool = ---;
    #if type_of(result) == {
        case bool;    success = result;
        case BOOL;    success = result != FALSE;
        case HRESULT; success = result == 0;
        case u32;     success = result != 0;
        case;
            compiler_report(tprint("Unhandled type: %", type_of(result)));
    }

    if success return;

    IS_HRESULT :: type_of(result) == HRESULT;

    #if OS == .WINDOWS && print_sys_error {
        #if IS_HRESULT {
            sys_error_code := cast,no_check(u32) result;
        } else {
            sys_error_code : u32 = GetLastError();
        }
    }

    builder := String_Builder.{ allocator = temp };

    if format {
        if args.count > 0 {
            print(*builder, format, ..args);
        } else {
            append(*builder, format);
        }
    } else if #compile_time {
        root := compiler_get_nodes(expression);
        print_expression(*builder, root);
    }

    #if OS == .WINDOWS && print_sys_error {
        if sys_error_code != ERROR_SUCCESS {
            sys_error_message_buffer : [1024] u8 = ---;
            sys_error_message_length := FormatMessageA(FORMAT_MESSAGE_IGNORE_INSERTS | FORMAT_MESSAGE_FROM_SYSTEM,
                                                       null,
                                                       sys_error_code,
                                                       MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
                                                       cast,no_check(**u8) sys_error_message_buffer.data,
                                                       sys_error_message_buffer.count,
                                                       null);

            #if !IS_HRESULT {
                sys_error_message_length -= ".\r\n".count;
            }
            assert(sys_error_message_length > 0);

            sys_error_message := string.{ sys_error_message_length, sys_error_message_buffer.data };
            #if IS_HRESULT {
                print(*builder, ". System error (0x%): %", formatInt(sys_error_code, base = 16), sys_error_message);
            } else {
                print(*builder, ". System error (%): %", sys_error_code, sys_error_message);
            }
        }
    }

    message := builder_to_string(*builder);
    if #compile_time {
        compiler_report(message, loc = location);
    } else {
        assert(false, message, loc = location);
    }
}

addDeclarations :: (workspace : Workspace) {
    builder := String_Builder.{ allocator = temp };

    root := compiler_get_nodes(GraphicsAPI);
    assert(root.kind == .IDENT);

    root_decl := cast(*Code_Ident, root).resolved_declaration;
    print_expression(*builder, root_decl);

    add_build_string(builder_to_string(*builder,, temp), workspace);
}

addConfigDefines :: (build_arguments : BuildArguments, workspace : Workspace) {
    builder := String_Builder.{ allocator = temp };

    CONFIG_STRING :: #string END
DEBUG_BUILD            :: %;
PRINT_VERBOSE_MESSAGES :: %;
GRAPHICS_API           :: %.%;
END;

    add_build_string(tprint(CONFIG_STRING,
                            !build_arguments.optimized,
                            build_arguments.verbose,
                            type_of(build_arguments.graphics_api),
                            build_arguments.graphics_api),
                     workspace);
}

#if OS == .WINDOWS {
    FALSE : BOOL : 0;

    ERROR_SUCCESS :: 0;

    BeginUpdateResourceW :: (
        pFileName                : *u16,
        bDeleteExistingResources : BOOL
    ) -> HANDLE #foreign kernel32;

    RT_MANIFEST :: cast(*u16) 24;

    UpdateResourceW :: (
        hUpdate   : HANDLE,
        lpType    : *u16,
        lpName    : *u16,
        wLanguage : WORD,
        lpData    : *void,
        cbData    : DWORD
    ) -> BOOL #foreign kernel32;

    EndUpdateResourceW :: (
        hUpdate  : HANDLE,
        fDiscard : BOOL
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
    #import "Windows_Utf8";
} else if OS == .POSIX {
    #import "POSIX";
} else {
    #assert false "Not implemented";
}
