Settings :: struct {
    PATH :: "settings\\engine.ini";

    arenas : struct {
        persistent_capacity : s64 = #run gigaBytes(1);
        per_frame_capacity  : s64 = #run megaBytes(512);
    } @read_only;

    asset_manager : struct {
        upload_ring_buffer_capacity : u32 = #run megaBytes(512);
    } @read_only;

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

loadSettings :: () {
    createArena(*g_settings_scratch_arena, megaBytes(1), "Settings scratch");

    temp_context := context;
    temp_context.pet.arenas.per_frame = g_settings_scratch_arena;
    push_context,defer_pop temp_context;

    file_data, error := readEntireFile(Settings.PATH, pushToArena, *g_settings_scratch_arena);
    if error != .NONE {
        return;
    }

    iniDeserialize(*file_data, *g_settings_to_commit, *g_settings_scratch_arena);
    g_committed_settings = g_settings_to_commit;
}

destroySettings :: () {
    destroyArena(*g_settings_scratch_arena);
}

commitSettings :: () {
    {
        scopedLock(*g_committed_settings_mutex);
        old_settings := g_committed_settings;
        g_committed_settings = g_settings_to_commit;
        applySettings(old_settings);
    }

    file, error := openFile(Settings.PATH, .WRITE | .TRUNCATE | .SEQ, true);
    assert(error == .NONE);
    defer closeFile(*file);

    settings := readSettings();

    builder : Basic.String_Builder;
    defer Basic.reset(*builder);

    iniSerialize(*builder, settings);

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
    info, read_only := getMemberTypeInfo(type_info(Settings), setting);
    if info {
        T = Compiler.get_type(info);
        if read_only {
            return false, String.join("\"Settings.", setting, "\" is read only",, allocator = Basic.temp);
        }
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

getMemberTypeInfo :: (info : *Type_Info, setting : string, read_only := false) -> (info : *Type_Info, read_only : bool) #compile_time {
    assert(info.type == .STRUCT);
    struct_info := cast(*Type_Info_Struct) info;

    found, left, right := String.split_from_left(setting, #char ".");

    found_info     : *Type_Info;
    this_read_only := read_only;
    for struct_info.members {
        if it.name == left {
            found_info = it.type;

            if !this_read_only {
                for it.notes {
                    if it == "read_only" {
                        this_read_only = true;
                        break;
                    }
                }
            }

            break;
        }
    }

    if found && found_info {
        found_info, this_read_only = getMemberTypeInfo(found_info, right, this_read_only);
    }

    return found_info, this_read_only;
}

// @TODO: #Settings.
//     - render.resolution
//     - render.gpu
//     - render.frame_buffering
applySettings :: (old_settings : Settings) {
    recreate_swap_chain := old_settings.render.vsync           != g_committed_settings.render.vsync
                        || old_settings.render.tearing_allowed != g_committed_settings.render.tearing_allowed
                        || old_settings.render.scaling         != g_committed_settings.render.scaling;

    for * context.pet.core.window_manager.windows {
        if !(it.flags & .GAME) continue;
        resizeWindow(it, g_committed_settings.window.resolution);

        if recreate_swap_chain {
            scheduleSwapChainReset(it);
        }
    }
}

g_committed_settings       : Settings;
g_settings_to_commit       : Settings;
g_committed_settings_mutex : Mutex;
g_settings_scratch_arena   : Arena;
