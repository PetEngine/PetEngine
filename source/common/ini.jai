#scope_export

iniSerialize :: (builder : *Basic.String_Builder, data : $T) {
    old_int_digits_per_comma      := context.print_style.default_format_int.digits_per_comma;
    old_float_thousand_separators := context.print_style.default_format_float.thousand_separators;
    context.print_style.default_format_int.digits_per_comma      = 0;
    context.print_style.default_format_float.thousand_separators = false;
    defer {
        context.print_style.default_format_int.digits_per_comma      = old_int_digits_per_comma;
        context.print_style.default_format_float.thousand_separators = old_float_thousand_separators;
    }

    INFO :: type_info(T);
    #assert INFO.type == .STRUCT "data should be struct";

    serializeSection(builder, INFO, "", *data);
}

iniDeserialize :: (stream : *string, data : *$T, arena_for_strings_in_data : *Arena) {
    INFO :: type_info(T);
    #assert INFO.type == .STRUCT "data should be struct";

    struct_info   := INFO;
    struct_offset : s64;
    section_name  : string;

    skip_until_next_section : bool;

    while stream.* {
        line := getLine(stream);

        // Skip an empty line or a comment
        if !line || line[0] == #char ";" || line[0] == #char "#" {
            continue;
        }

        if line[0] == #char "[" {
            skip_until_next_section = false;
            advance(*line);

            section_name_start := advanceWhile(*line, (char : u8) -> bool #no_context {
                return char != #char "]";
            });

            if !line || line[0] != #char "]" {
                errorMessage("Expected ']', got '%'", ifx line then string.{ 1, line.data } else "<EOL>");
                skip_until_next_section = true;
                continue;
            }

            section_name = .{ line.data - section_name_start, section_name_start };
            trim(*section_name);

            if !section_name {
                errorMessage("Section name is empty");
                skip_until_next_section = true;
                continue;
            }

            struct_info, struct_offset = getSectionTypeInfoAndOffset(section_name, INFO);
            if !struct_info || struct_offset < 0 {
                errorMessage("\"%.%\" struct is not found", T, section_name);
                skip_until_next_section = true;
                continue;
            }

            continue;
        }

        if skip_until_next_section continue;

        name, value, success := splitToNameAndValue(*line);
        if !success continue;

        entry_type_info : *Type_Info_Struct_Member;
        for * struct_info.members {
            if filterOutMember(it.*, .REJECT_STRUCTS) continue;

            if it.name == name {
                entry_type_info = it;
                break;
            }
        }

        entry_full_name := ifx  section_name
                           then Basic.sprint("%.%.%", T, section_name, name,, allocator = Basic.temp)
                           else Basic.sprint("%.%", T, name,, allocator = Basic.temp);

        if !entry_type_info {
            errorMessage("\"%\" entry is not found", entry_full_name);
            continue;
        }

        entry_memory := (cast(*void) data) + struct_offset + entry_type_info.offset_in_bytes;

        if value[0] == #char "\"" {
            if entry_type_info.type.type != .STRING {
                errorMessage("\"%\" entry type mismatch. In the file: STRING, in the code: %",
                             entry_full_name,
                             entry_type_info.type.type);
                continue;
            }

            advance(*value);
            string_value_start := advanceWhile(*value, (char : u8) -> bool #no_context {
                return char != #char "\"";
            });
            string_value := string.{ value.data - string_value_start, string_value_start };

            string_entry := cast(*string) entry_memory;
            string_entry.count = string_value.count;
            string_entry.data  = pushToArena(arena_for_strings_in_data, u8, string_value.count);
            memcpy(string_entry.data, string_value.data, string_value.count);
        } else if isDigit(value[0]) || value[0] == #char "-" || value[0] == #char "+" {
            if entry_type_info.type.type == {
                case .INTEGER;
                    int_info := cast(*Type_Info_Integer) entry_type_info.type;

                    assert(int_info.runtime_size == 1 || int_info.runtime_size == 2 || int_info.runtime_size == 4 || int_info.runtime_size == 8,
                           "Invalid integer runtime size: %",
                           int_info.runtime_size);

                    if int_info.signed {
                        int_value, success := Basic.string_to_int(value, T = s64);
                        if success {
                            if int_info.runtime_size == {
                                case 1; (cast(*s8)  entry_memory).* = cast(s8)  int_value;
                                case 2; (cast(*s16) entry_memory).* = cast(s16) int_value;
                                case 4; (cast(*s32) entry_memory).* = cast(s32) int_value;
                                case 8; (cast(*s64) entry_memory).* = int_value;
                            }
                        } else {
                            errorMessage("Failed to parse \"%\" int entry (signed)", entry_full_name);
                        }
                    } else {
                        int_value, success := Basic.string_to_int(value, T = u64);
                        if success {
                            memcpy(entry_memory, *int_value, int_info.runtime_size);
                        } else {
                            errorMessage("Failed to parse \"%\" int entry (unsigned)", entry_full_name);
                        }
                    }

                case .FLOAT;
                    assert(entry_type_info.type.runtime_size == 4 || entry_type_info.type.runtime_size == 8,
                           "Invalid float runtime size: %",
                           entry_type_info.type.runtime_size);

                    if entry_type_info.type.runtime_size == {
                        case 4;
                            float_value, success := Basic.string_to_float(value);
                            if success {
                                (cast(*f32) entry_memory).* = float_value;
                            } else {
                                errorMessage("Failed to parse \"%\" entry (type: f32)", entry_full_name);
                            }

                        case 8;
                            float_value, success := Basic.string_to_float64(value);
                            if success {
                                (cast(*f64) entry_memory).* = float_value;
                            } else {
                                errorMessage("Failed to parse \"%\" entry (type: f64)", entry_full_name);
                            }
                    }

                case;
                    errorMessage("\"%\" entry type mismatch. In the file: INTEGER or FLOAT, in the code: %",
                                 entry_full_name,
                                 entry_type_info.type.type);
            }
        } else if isAlpha(value[0]) {
            if entry_type_info.type.type == {
                case .BOOL;
                    if value == {
                        case "true";
                            (cast(*bool) entry_memory).* = true;

                        case "false";
                            (cast(*bool) entry_memory).* = false;

                        case;
                            errorMessage("Invalid value for entry \"%s\": %. Allowed: true or false (case sensitive)",
                                         entry_full_name,
                                         value);
                    }

                case .ENUM;
                    enum_info := cast(*Type_Info_Enum) entry_type_info.type;

                    assert(enum_info.runtime_size == 1 || enum_info.runtime_size == 2 || enum_info.runtime_size == 4 || enum_info.runtime_size == 8,
                           "Invalid enum runtime size: %",
                           enum_info.runtime_size);

                    if enum_info.enum_type_flags & .FLAGS {
                        enum_flags_values  : u64;
                        at_least_one_found : bool;

                        while value {
                            flag_name_start := advanceWhile(*value, (char : u8) -> bool #no_context {
                                return char != #char "|";
                            });

                            flag_name := string.{ value.data - flag_name_start, flag_name_start };
                            trimRight(*flag_name);

                            if flag_name == "0" continue;

                            value_found : bool;
                            for enum_info.names {
                                if it == flag_name {
                                    enum_flags_values  |= cast,no_check(u64) enum_info.values[it_index];
                                    at_least_one_found |= true;
                                    value_found         = true;
                                    break;
                                }
                            }

                            if !value_found {
                                errorMessage("Enum flags value (\"%\") for entry \"%\" is not found", flag_name, entry_full_name);
                            }

                            if !value break;

                            if value[0] == #char "|" {
                                advance(*value);
                            }

                            trimLeft(*value);
                        }

                        memcpy(entry_memory, *enum_flags_values, enum_info.runtime_size);
                    } else {
                        value_found : bool;
                        for enum_info.names {
                            if it == value {
                                value_found = true;

                                if enum_info.internal_type.signed {
                                    if enum_info.runtime_size == {
                                        case 1; (cast(*s8)  entry_memory).* = cast(s8)  enum_info.values[it_index];
                                        case 2; (cast(*s16) entry_memory).* = cast(s16) enum_info.values[it_index];
                                        case 4; (cast(*s32) entry_memory).* = cast(s32) enum_info.values[it_index];
                                        case 8; (cast(*s64) entry_memory).* = enum_info.values[it_index];
                                    }
                                } else {
                                    memcpy(entry_memory, *enum_info.values[it_index], enum_info.runtime_size);
                                }

                                break;
                            }
                        }

                        if !value_found {
                            errorMessage("Enum value (\"%\") for entry \"%\" is not found", value, entry_full_name);
                        }
                    }

                case;
                    errorMessage("\"%\" entry type mismatch. In the file: bool, enum or enum_flags, in the code: %",
                                 entry_full_name,
                                 entry_type_info.type.type);
            }
        } else {
            errorMessage("Unexpected start of the value: \"%\" (value = \"%\")", value[0], value);
        }
    }
}

#scope_file

serializeSection :: (
    builder        : *Basic.String_Builder,
    struct_info    : *Type_Info_Struct,
    section_name   : string,
    section_memory : *void
) {
    at_least_one_non_struct_member_was_serialized : bool;

    // First, print all non struct members
    for struct_info.members {
        if filterOutMember(it, .REJECT_STRUCTS) continue;
        at_least_one_non_struct_member_was_serialized = true;

        value_memory := section_memory + it.offset_in_bytes;

        Basic.append(builder, it.name);
        Basic.append(builder, " = ");

        if it.type.type == .STRING {
            Basic.append(builder, "\"");
            Basic.append(builder, (cast(*string) value_memory).*);
            Basic.append(builder, "\"");
        } else {
            Basic.print_item_to_builder(builder, Any.{ it.type, value_memory }, false);
        }

        Basic.append(builder, "\n");
    }

    if at_least_one_non_struct_member_was_serialized || section_name {
        Basic.append(builder, "\n");
    }

    // Next, print all struct members
    if section_name {
        for struct_info.members {
            if filterOutMember(it, .REJECT_NON_STRUCTS) continue;

            inner_section_name := String.join(section_name, ".", it.name,, allocator = Basic.temp);

            Basic.append(builder, "[");
            Basic.append(builder, inner_section_name);
            Basic.append(builder, "]\n");

            inner_struct_info    := cast(*Type_Info_Struct) it.type;
            inner_section_memory := section_memory + it.offset_in_bytes;
            serializeSection(builder, inner_struct_info, inner_section_name, inner_section_memory);
        }
    } else {
        for struct_info.members {
            if filterOutMember(it, .REJECT_NON_STRUCTS) continue;

            Basic.append(builder, "[");
            Basic.append(builder, it.name);
            Basic.append(builder, "]\n");

            inner_struct_info    := cast(*Type_Info_Struct) it.type;
            inner_section_memory := section_memory + it.offset_in_bytes;
            serializeSection(builder, inner_struct_info, it.name, inner_section_memory);
        }
    }
}

getSectionTypeInfoAndOffset :: (name : string, info : *Type_Info_Struct, offset := 0) -> (info : *Type_Info_Struct, offset : s64) {
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
                result_info, result_offset := getSectionTypeInfoAndOffset(right_struct_name,
                                                                          cast(*Type_Info_Struct) it.type,
                                                                          offset + it.offset_in_bytes);
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
        if it == "ini_ignore" {
            return true;
        }
    }

    return false;
}
