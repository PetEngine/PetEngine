Texture :: struct {
    ALL_MIPS    : u8 : 0xFF;
    MAX_SAMPLES : u8 : 0xFF;

    MAX_MIPS_SUPPORTED : u8 : 16;

    Dimension :: enum u8 {
        _1D;
        _2D;
        _3D;
    }

    // Order: uncompressed: little-endian
    //        packed:       from the least-significant to the most-significant
    Format :: enum u8 {
        UNKNOWN :: 0;

        // Uncompressed
        RGBA8_UNORM;
        RGBA8_SRGB;
        BGRA8_UNORM;
        BGRA8_SNORM;
        BGRA8_SRGB;

        // Packed
        RGB10A2_UNORM;

        // Depth/stencil
        D32;
        S8;

        // Compressed
        BC1_UNORM;
        BC1_SRGB;
        BC1_A1_UNORM;
        BC1_A1_SRGB;
        BC2_UNORM;
        BC2_SRGB;
        BC3_UNORM;
        BC3_SRGB;
        BC4_UNORM;
        BC4_SNORM;
        BC5_UNORM;
        BC5_SNORM;
        BC6H_UFLOAT;
        BC6H_SFLOAT;
        BC7_UNORM;
        BC7_SRGB;

        // Planar
    }

    Flags :: enum_flags u8 {
        ARRAY;
        CUBE;

        // Not explicitly settable
        SWAPCHAIN;
    }

    Usage :: enum_flags u8 {
        SHADER_READ;     // DirectX: SRV. Vulkan, OpenGL: Sampled image.
        SHADER_WRITE;    // DirectX: UAV. Vulkan, OpenGL: Storage image.
        COLOR_TARGET;    // DirectX: RTV. Vulkan, OpenGL: Color attachment.
        DEPTH_TARGET;    // DirectX: DSV. Vulkan, OpenGL: Depth stencil attachment.
        DEPTH_READ_ONLY; // Only depth test, no depth write.
    }

    FormatFlags :: enum_flags u8 {
        COMPRESSED;
        PACKED;
        COLOR;
        DEPTH;
        STENCIL;
        INTEGER;
        SRGB;
        HDR;
    }

    ClearValue :: union {
        color_f32 : v4f;
        color_u32 : v4u;
        color_s32 : v4s;
        struct {
            depth   : f32;
            stencil : u32;
        }
    }

    dimension       : Dimension;
    format          : Format;
    flags           : Flags;
    usages          : Usage;
    width           : u16;
    height          : u16;
    union {
        depth       : u16;
        array_size  : u16;
    }
    samples_count   : u8;
    mips_count      : u8;
    clear_value     : ClearValue;
    name            : string;
    current_owner   : QueueType;
    possible_owners : StaticArray(QueueType, Device.QUEUE_TYPES_COUNT);
}

createTexture :: (
    format              : Texture.Format,
    width               : u16,
    height              : u16                = 0,
    depth_or_array_size : u16                = 0,
    samples_count       : u8                 = 1,
    mips_count          : u8                 = 1,
    flags               : Texture.Flags      = 0,
    clear_value         : Texture.ClearValue = .{},
    usages              : Texture.Usage,
    lifetime            : ResourceManager.Lifetime,
    name                : string,
    possible_owners     : ..QueueType = .[ .GRAPHICS ]
) -> *Texture #must {
    assert(!resourceMemoryCommitted(lifetime), "You cannot create %1 texture after %1 memory is committed", lifetime);

    assert(!(flags & .SWAPCHAIN),
           "You cannot explicitly set SWAPCHAIN flag");
    assert(depth_or_array_size > 0 || !(flags & .ARRAY),
           "Number of elements in texture array cannot be 0");
    assert((usages & (.COLOR_TARGET | .DEPTH_TARGET)) != (.COLOR_TARGET | .DEPTH_TARGET),
           "COLOR_TARGET and DEPTH_TARGET usages cannot be combined");
    assert((usages & (.DEPTH_TARGET | .DEPTH_READ_ONLY)) == (.DEPTH_TARGET | .DEPTH_READ_ONLY) || !(usages & .DEPTH_READ_ONLY),
           "DEPTH_READ_ONLY usage should be used with DEPTH_TARGET usage");
    assert(samples_count ==  1
        || samples_count ==  2
        || samples_count ==  4
        || samples_count ==  8
        || samples_count == 16
        || samples_count == 32
        || samples_count == 64
        || samples_count == Texture.MAX_SAMPLES);
    assert(possible_owners.count > 0);

    assert(width > 0);
    assert(width == height || !(flags & .CUBE),
           "Cube textures must have identical width and height");

    max_mips_count := maxMipsCount(width, height, depth_or_array_size * cast,no_check(u16) !(flags & .ARRAY));
    if mips_count == Texture.ALL_MIPS {
        mips_count = max_mips_count;
    } else {
        assert(0 < mips_count && mips_count <= max_mips_count,
               "Too many MIP levels requested: %, maximum allowed: %",
               mips_count,
               max_mips_count);
    }

    dimension : Texture.Dimension = ---;
    /**/ if flags & .ARRAY          then dimension = ifx height > 0 then ._2D else ._1D;
    else if depth_or_array_size > 0 then dimension = ._3D;
    else if height > 0              then dimension = ._2D;
    else                                 dimension = ._1D;
    assert((dimension != ._3D) || !(flags & .ARRAY), "Texture arrays cannot consist of 3D textures");

    assert(name.count <= ResourceManager.MAX_RESOURCE_NAME_LENGTH,
           "Max texture name length (%) > ResourceManager.MAX_RESOURCE_NAME_LENGTH (%)",
           name.count, ResourceManager.MAX_RESOURCE_NAME_LENGTH);

    manager := context.pet.render.resource_manager;

    texture := manager.pushPlatformTexture(lifetime);

    texture.dimension             = dimension;
    texture.format                = format;
    texture.flags                 = flags;
    texture.usages                = usages;
    texture.width                 = width;
    texture.height                = height;
    texture.depth                 = depth_or_array_size;
    texture.samples_count         = samples_count;
    texture.mips_count            = mips_count;
    texture.clear_value           = clear_value;
    texture.current_owner         = possible_owners[0];
    texture.possible_owners.count = cast(u32) possible_owners.count;
    memcpy(texture.possible_owners.data.data, possible_owners.data, possible_owners.count * size_of(QueueType));

    manager.createPlatformTexture(texture, lifetime, name);

    return texture;
}

textureFormatFlags :: (format : Texture.Format) -> Texture.FormatFlags {
    if #complete format == {
        case .UNKNOWN;       return 0;
        case .RGBA8_UNORM;   return .COLOR;
        case .RGBA8_SRGB;    return .COLOR | .SRGB;
        case .BGRA8_UNORM;   return .COLOR;
        case .BGRA8_SNORM;   return .COLOR;
        case .BGRA8_SRGB;    return .COLOR | .SRGB;
        case .RGB10A2_UNORM; return .COLOR | .PACKED;
        case .D32;           return .DEPTH;
        case .S8;            return .STENCIL | .INTEGER;
        case .BC1_UNORM;     return .COMPRESSED | .COLOR;
        case .BC1_SRGB;      return .COMPRESSED | .COLOR | .SRGB;
        case .BC1_A1_UNORM;  return .COMPRESSED | .COLOR;
        case .BC1_A1_SRGB;   return .COMPRESSED | .COLOR | .SRGB;
        case .BC2_UNORM;     return .COMPRESSED | .COLOR;
        case .BC2_SRGB;      return .COMPRESSED | .COLOR | .SRGB;
        case .BC3_UNORM;     return .COMPRESSED | .COLOR;
        case .BC3_SRGB;      return .COMPRESSED | .COLOR | .SRGB;
        case .BC4_UNORM;     return .COMPRESSED | .COLOR;
        case .BC4_SNORM;     return .COMPRESSED | .COLOR;
        case .BC5_UNORM;     return .COMPRESSED | .COLOR;
        case .BC5_SNORM;     return .COMPRESSED | .COLOR;
        case .BC6H_UFLOAT;   return .COMPRESSED | .COLOR | .HDR;
        case .BC6H_SFLOAT;   return .COMPRESSED | .COLOR | .HDR;
        case .BC7_UNORM;     return .COMPRESSED | .COLOR;
        case .BC7_SRGB;      return .COMPRESSED | .COLOR | .SRGB;
    }

    assertMessage("Invalid Texture.Format value: %", format);
    return 0;
}

maxMipsCount :: inline (width : u16, height : u16, depth : u16) -> u8 {
    all_bits := width | height | depth;
    assert(all_bits != 0);

    max_mips : u16 = 0;
    #if CPU == .X64 {
        #asm { bsr.w max_mips, all_bits; }
    } else {
        notImplemented();
    }
    return cast,no_check(u8) (max_mips + 1);
}
