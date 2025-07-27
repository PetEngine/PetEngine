Settings :: struct {
    PATH :: "settings\\engine.ini";

    arenas : struct {
        persistent_capacity : s64 = #run gigaBytes(1);
        per_frame_capacity  : s64 = #run megaBytes(512);
    };

    asset_manager : struct {
        upload_ring_buffer_capacity : u32 = #run megaBytes(512);
    };

    render : struct {
        resolution      : Resolution     = .{ 1920, 1080 };
        gpu             : string;
        frame_buffering : FrameBuffering = .DOUBLE;
        vsync           : bool           = true;
        tearing_allowed : bool;
        scaling         : ScalingMode    = .ASPECT_RATIO;
    };

    window : struct {
        resolution : Resolution = .{ 960, 540 };
    };
}
#assert validateSettingsFormat() "Settings validation is failed";

loadSettings :: () {
    createArena(*g_settings_scratch_arena, megaBytes(1), "Settings scratch");

    temp_context := context;
    temp_context.pet.arenas.per_frame = g_settings_scratch_arena;
    push_context,defer_pop temp_context;

    file_data, error := readEntireFile(Settings.PATH, pushToArena, *g_settings_scratch_arena);
    if error != .NONE {
        return;
    }

    if deserializeSettings(*file_data, *g_settings_to_commit) {
        g_committed_settings = g_settings_to_commit;
    } else {
        warningMessage("There were errors during parsing settings file. Default settings will be used.");
        g_settings_to_commit = .{};
    }
}

destroySettings :: () {
    destroyArena(*g_settings_scratch_arena);
}

commitSettings :: () {
    {
        scopedLock(*g_committed_settings_mutex);
        g_committed_settings = g_settings_to_commit;

        // @Continue: #Settings. Apply settings
    }

    file, error := openFile(Settings.PATH, .WRITE | .TRUNCATE | .SEQ, true);
    assert(error == .NONE);
    defer closeFile(*file);

    settings := readSettings();

    builder : Basic.String_Builder;
    serializeSettings(*builder, settings);

    writeFile(file, *builder);
}

readSetting :: ($setting : string) -> $T #modify {
    info := getMemberTypeInfo(type_info(Settings), setting);
    if info {
        T = Compiler.get_type(info);
        return true;
    }
    return false, String.join("\"Settings.", setting, "\" is not found",, allocator = Basic.temp);
} {
    _ = setting; // #CodeGenWorkaround. Otherwise readSetting with the same T returns the same value.
    scopedLock(*g_committed_settings_mutex, true);
    return #insert -> string {
        return String.join("g_committed_settings.", setting, ";",, allocator = Basic.temp);
    };
}

readSettings :: () -> Settings {
    scopedLock(*g_committed_settings_mutex, true);
    return g_committed_settings;
}

writeSetting :: ($setting : string, value : $T) #modify {
    info := getMemberTypeInfo(type_info(Settings), setting);
    if info {
        T = Compiler.get_type(info);
        return true;
    }
    return false, String.join("\"Settings.", setting, "\" is not found",, allocator = Basic.temp);
} {
    _ = setting; // #CodeGenWorkaround.
    #insert -> string {
        return String.join("g_settings_to_commit.", setting, " = value;",, allocator = Basic.temp);
    }
}

writeSettings :: (value : Settings) {
    g_settings_to_commit = value;
}

#scope_file

getMemberTypeInfo :: (info : *Type_Info, setting : string) -> *Type_Info #compile_time {
    assert(info.type == .STRUCT);
    struct_info := cast(*Type_Info_Struct) info;

    found, left, right := String.split_from_left(setting, #char ".");

    found_info : *Type_Info;
    for struct_info.members {
        if filterOutMember(it) continue;

        if it.name == left {
            found_info = it.type;
            break;
        }
    }

    if found && found_info {
        return getMemberTypeInfo(found_info, right);
    }

    return found_info;
}

serializeSettings :: (builder : *Basic.String_Builder, settings : Settings) {
    old_int_digits_per_comma      := context.print_style.default_format_int.digits_per_comma;
    old_float_thousand_separators := context.print_style.default_format_float.thousand_separators;
    context.print_style.default_format_int.digits_per_comma      = 0;
    context.print_style.default_format_float.thousand_separators = false;
    defer {
        context.print_style.default_format_int.digits_per_comma      = old_int_digits_per_comma;
        context.print_style.default_format_float.thousand_separators = old_float_thousand_separators;
    }

    for type_info(Settings).members {
        if filterOutMember(it) continue;

        assert(it.type.type == .STRUCT);
        Basic.print(builder, "[%]\n", it.name);

        struct_info    := cast(*Type_Info_Struct) it.type;
        section_memory := (cast(*void) *settings) + it.offset_in_bytes;
        serializeSection(builder, struct_info, it.name, section_memory);
    }
}

serializeSection :: (
    builder        : *Basic.String_Builder,
    struct_info    : *Type_Info_Struct,
    section_name   : string,
    section_memory : *void
) {
    assert(struct_info.members.count > 0, "Settings do not support empty structs");

    // First, print all non struct members
    for struct_info.members {
        if filterOutMember(it, .REJECT_STRUCTS) continue;

        value_memory := section_memory + it.offset_in_bytes;

        if it.type.type == .STRING {
            typed_value := Any.{ it.type, value_memory };
            Basic.print(builder, "% = \"%\"\n", it.name, typed_value);
        } else {
            typed_value := Any.{ it.type, value_memory };
            Basic.print(builder, "% = %\n", it.name, typed_value);
        }
    }
    Basic.append(builder, "\n");

    // Next, print all struct members
    for struct_info.members {
        if filterOutMember(it, .REJECT_NON_STRUCTS) continue;

        inner_section_name := String.join(section_name, ".", it.name,, allocator = Basic.temp);
        Basic.print(builder, "[%]\n", inner_section_name);

        inner_struct_info    := cast(*Type_Info_Struct) it.type;
        inner_section_memory := section_memory + it.offset_in_bytes;
        serializeSection(builder, inner_struct_info, inner_section_name, inner_section_memory);
    }
}

deserializeSettings :: (stream : *string, settings : *Settings) -> bool {
    struct_info   := type_info(Settings);
    struct_offset := 0;

    while stream.* {
        line := getLine(stream);

        // Skip an empty line or a comment
        if !line || line[0] == #char ";" {
            continue;
        }

        if line[0] == #char "[" {
            advance(*line);

            section_name_start := advanceWhile(*line, (char : u8) -> bool #no_context {
                return char != #char "]";
            });

            if !line || line[0] != #char "]" {
                errorMessage("Expected ']', got '%'", ifx line then string.{ 1, line.data } else "<EOL>");
                return false;
            }

            section_name := string.{ line.data - section_name_start, section_name_start };
            trim(*section_name);

            if !section_name {
                errorMessage("Section name is empty");
                return false;
            }

            struct_info, struct_offset = getSectionTypeInfoAndOffset(section_name);
            if !struct_info || struct_offset < 0 {
                errorMessage("\"Settings.%\" struct is not found", section_name);
                return false;
            }

            continue;
        }

        name, value, success := splitToNameAndValue(*line);
        if !success continue; // Just skip this setting

        setting_type_info : *Type_Info_Struct_Member;
        for * struct_info.members {
            if filterOutMember(it.*, .REJECT_STRUCTS) continue;

            if it.name == name {
                setting_type_info = it;
                break;
            }
        }

        if !setting_type_info {
            errorMessage("\"%\" setting is not found", name);
            continue; // Just skip this setting
        }

        setting_memory := (cast(*void) settings) + struct_offset + setting_type_info.offset_in_bytes;

        if value[0] == #char "\"" {
            if setting_type_info.type.type != .STRING {
                errorMessage("\"%\" setting type mismatch. In the file: %, in the code: %", name, Type_Info_Tag.STRING, setting_type_info.type.type);
                continue; // Just skip this setting
            }

            advance(*value);
            string_value_start := advanceWhile(*value, (char : u8) -> bool #no_context {
                return char != #char "\"";
            });
            string_value := string.{ value.data - string_value_start, string_value_start };

            // `string_value` as well entire file data is in `g_settings_scratch_arena`, so we can do no copy!
            (cast(*string) setting_memory).* = string_value;
        } else if isDigit(value[0]) || value[0] == #char "-" || value[0] == #char "+" {
            if setting_type_info.type.type == {
                case .INTEGER;
                    int_info := cast(*Type_Info_Integer) setting_type_info.type;

                    assert(int_info.runtime_size == 1 || int_info.runtime_size == 2 || int_info.runtime_size == 4 || int_info.runtime_size == 8,
                           "Invalid integer runtime size: %",
                           int_info.runtime_size);

                    if int_info.signed {
                        int_value, success := Basic.string_to_int(value, T = s64);
                        if success {
                            if int_info.runtime_size == {
                                case 1; (cast(*s8)  setting_memory).* = cast(s8)  int_value;
                                case 2; (cast(*s16) setting_memory).* = cast(s16) int_value;
                                case 4; (cast(*s32) setting_memory).* = cast(s32) int_value;
                                case 8; (cast(*s64) setting_memory).* = int_value;
                            }
                        } else {
                            errorMessage("Failed to parse \"%\" int setting (signed)");
                        }
                    } else {
                        int_value, success := Basic.string_to_int(value, T = u64);
                        if success {
                            memcpy(setting_memory, *int_value, int_info.runtime_size);
                        } else {
                            errorMessage("Failed to parse \"%\" int setting (unsigned)");
                        }
                    }

                case .FLOAT;
                    assert(setting_type_info.type.runtime_size == 4 || setting_type_info.type.runtime_size == 8,
                           "Invalid float runtime size: %",
                           setting_type_info.type.runtime_size);

                    if setting_type_info.type.runtime_size == {
                        case 4;
                            float_value, success := Basic.string_to_float(value);
                            if success {
                                (cast(*f32) setting_memory).* = float_value;
                            } else {
                                errorMessage("Failed to parse \"%\" setting (type: f32)");
                            }

                        case 8;
                            float_value, success := Basic.string_to_float64(value);
                            if success {
                                (cast(*f64) setting_memory).* = float_value;
                            } else {
                                errorMessage("Failed to parse \"%\" setting (type: f64)");
                            }
                    }

                case;
                    errorMessage("\"%\" setting type mismatch. In the file: INTEGER or FLOAT, in the code: %", name, setting_type_info.type.type);
            }
        } else if isAlpha(value[0]) {
            if setting_type_info.type.type == {
                case .BOOL;
                    if value == {
                        case "true";
                            (cast(*bool) setting_memory).* = true;

                        case "false";
                            (cast(*bool) setting_memory).* = false;

                        case;
                            errorMessage("Invalid value for setting \"%s\": %. Allowed: true or false (case sensitive)", name, value);
                    }

                case .ENUM;
                    enum_info := cast(*Type_Info_Enum) setting_type_info.type;
                    assert(!(enum_info.enum_type_flags & .FLAGS));

                    value_found : bool;
                    for enum_info.names {
                        if it == value {
                            value_found = true;

                            assert(enum_info.runtime_size == 1 || enum_info.runtime_size == 2 || enum_info.runtime_size == 4 || enum_info.runtime_size == 8,
                                   "Invalid enum runtime size: %",
                                   enum_info.runtime_size);

                            if enum_info.internal_type.signed {
                                if enum_info.runtime_size == {
                                    case 1; (cast(*s8)  setting_memory).* = cast(s8)  enum_info.values[it_index];
                                    case 2; (cast(*s16) setting_memory).* = cast(s16) enum_info.values[it_index];
                                    case 4; (cast(*s32) setting_memory).* = cast(s32) enum_info.values[it_index];
                                    case 8; (cast(*s64) setting_memory).* = enum_info.values[it_index];
                                }
                            } else {
                                memcpy(setting_memory, *enum_info.values[it_index], enum_info.runtime_size);
                            }

                            break;
                        }
                    }

                    if !value_found {
                        errorMessage("Enum value (\"%\") for setting \"%\" is not found", value, name);
                    }

                case;
                    errorMessage("\"%\" setting type mismatch. In the file: BOOL or ENUM, in the code: %", name, setting_type_info.type.type);
            }
        } else {
            errorMessage("Unexpected start of the value: \"%\" (value = \"%\")", value[0], value);
        }
    }

    return true;
}

getSectionTypeInfoAndOffset :: (name : string, offset := 0, info := type_info(Settings)) -> (info : *Type_Info_Struct, offset : s64) {
    right_struct_name := name;

    left_struct_name_start := advanceWhile(*right_struct_name, (char : u8) -> bool #no_context {
        return char != #char ".";
    });

    left_struct_name := string.{ right_struct_name.data - left_struct_name_start, left_struct_name_start };

    if right_struct_name {
        advance(*right_struct_name, ".".count);

        for info.members {
            if filterOutMember(it, .REJECT_NON_STRUCTS) continue;

            if it.name == left_struct_name {
                result_info, result_offset := getSectionTypeInfoAndOffset(right_struct_name, offset + it.offset_in_bytes, cast(*Type_Info_Struct) it.type);
                return result_info, result_offset;
            }
        }
    } else {
        for info.members {
            if filterOutMember(it, .REJECT_NON_STRUCTS) continue;

            if it.name == left_struct_name {
                return cast(*Type_Info_Struct) it.type, offset + it.offset_in_bytes;
            }
        }
    }

    return null, -1;
}

splitToNameAndValue :: (line : *string) -> (name : string, value : string, success : bool) {
    name_start := advanceWhile(line, (char : u8) -> bool #no_context {
        return char != #char "=";
    });

    if !line.* || line.*[0] != #char "=" {
        errorMessage("Expected '=', got '%'", ifx line.* then string.{ 1, line.data } else "<EOL>");
        return "", "", false;
    }

    name := string.{ line.data - name_start, name_start };
    trimRight(*name);

    if !name {
        errorMessage("Name is empty");
        return "", "", false;
    }

    advance(line, "=".count);
    trimLeft(line);

    value := line.*;
    if !value {
        errorMessage("Value is empty");
        return "", "", false;
    }

    return name, value, true;
}

Filter :: enum u8 {
    REJECT_STRUCTS :: 1;
    REJECT_NON_STRUCTS;
}
filterOutMember :: (info : Type_Info_Struct_Member, $filter : Filter = 0) -> bool {
    if info.flags & .CONSTANT return true;

    #if filter == {
        case .REJECT_STRUCTS;
            if info.type.type == .STRUCT return true;

        case .REJECT_NON_STRUCTS;
            if info.type.type != .STRUCT return true;
    }

    for info.notes {
        if it == "ignore_in_settings" {
            return true;
        }
    }

    return false;
}

validateSettingsFormat :: (info := type_info(Settings), parent_name := "Settings") -> bool {
    valid := true;

    for info.members {
        if filterOutMember(it) continue;

        full_name := String.join(parent_name, ".", it.name,, allocator = Basic.temp);

        if it.type.type == {
            case .STRUCT;
                valid &&= validateSettingsFormat(cast(*Type_Info_Struct) it.type, full_name);

            case .ENUM;
                enum_info := cast(*Type_Info_Enum) it.type;
                if enum_info.enum_type_flags & .FLAGS {
                    errorMessage("enum_flags are not supported in Settings. Field: %", full_name);
                    valid = false;
                }
        }
    }

    return valid;
}

g_committed_settings       : Settings;
g_settings_to_commit       : Settings;
g_committed_settings_mutex : Mutex;
g_settings_scratch_arena   : Arena;
