TextureManager :: struct {
    MemoryKind :: enum u8 {
        PERSISTENT;
        PERSISTENT_RESOLUTION_DEPENDENT;

        PER_LEVEL;
        PER_LEVEL_RESOLUTION_DEPENDENT;

        PER_FRAME;
    }
}

createTextureManager :: (device : *Device) -> *TextureManager #must {
    manager : *TextureManager;

    if #complete device.graphics_api == {
        case .VULKAN;
            manager = createVulkanTextureManager(cast(*VulkanDevice) device);
    }

    return manager;
}

destroyTextureManager :: (device : *Device, manager : *TextureManager) {
    if #complete device.graphics_api == {
        case .VULKAN;
            destroyVulkanTextureManager(cast(*VulkanDevice) device, cast(*VulkanTextureManager) manager);
    }
}

commitTextureMemory :: (device : *Device, manager : *TextureManager, $memory_kind : TextureManager.MemoryKind) {
    if #complete device.graphics_api == {
        case .VULKAN;
            commitVulkanTextureMemory(cast(*VulkanDevice) device, cast(*VulkanTextureManager) manager, memory_kind);
    }
}

resetTextureMemory :: (device : *Device, manager : *TextureManager, $memory_kind : TextureManager.MemoryKind) {
    if #complete device.graphics_api == {
        case .VULKAN;
            resetVulkanTextureMemory(cast(*VulkanDevice) device, cast(*VulkanTextureManager) manager, memory_kind);
    }
}

resizeResolutionDependentTextures :: (device : *Device, manager : *TextureManager) {
    if #complete device.graphics_api == {
        case .VULKAN;
            resizeResolutionDependentVulkanTextures(cast(*VulkanDevice) device, cast(*VulkanTextureManager) manager);
    }
}

Texture :: struct {
    ALL_MIPS : u8 : 0xFF;

    Dimension :: enum u8 {
        _1D;
        _2D;
        _3D;
    }

    Flags :: enum_flags u16 {
        ARRAY;
        CUBE;

        COHERENT;
        NONCOHERENT;
        COLOR_TARGET;
        DEPTH_STENCIL;
        READ_ONLY;

        // Not explicitly settable
        SWAPCHAIN;
        RESOLUTION_DEPENDENT;
    }

    // Order: xyzw
    Format :: enum u8 {
        UNKNOWN :: 0;

        // Uncompressed
        RGB8_UNORM;
        RGB8_SNORM;
        BGR8_UNORM;
        BGR8_SNORM;
        RGBA8_UNORM;
        BGRA8_UNORM;
        RGB10A2_UNORM;

        // Depth/stencil
        D32;
        S8;

        // Compressed
        BC7_UNORM;

        // @TODO: Planar
    }

    FormatFlags :: enum_flags u8 {
        UNCOMPRESSED;
        COMPRESSED;
        COLOR;
        DEPTH;
        STENCIL;
    }

    // @TODO: #Math. Make it vector
    ClearValue :: union {
        color_f32 : [4] f32;
        color_u32 : [4] u32;
        color_s32 : [4] s32;
        struct {
            depth   : f32;
            stencil : u32;
        }
    };

    dimension             : Dimension;
    format                : Format;
    flags                 : Flags;
    width                 : u16;
    height                : u16;
    union {
        depth             : u16;
        array_size        : u16;
    };
    samples_count         : u8;
    mips_count            : u8;
    name                  : string;
    possible_owners_count : u32;
    possible_owners       : [#run Basic.enum_highest_value(QueueType) + 1] QueueType;
    current_owner         : QueueType;
}

createTexture :: (
    device              : *Device,
    manager             : *TextureManager,
    format              : Texture.Format,
    width               : u16,
    height              : u16           = 0,
    depth_or_array_size : u16           = 0,
    samples_count       : u8            = 1,
    mips_count          : u8            = 1,
    flags               : Texture.Flags,
    name                : string,
    $memory_kind        : TextureManager.MemoryKind,
    possible_owners     : ..QueueType = .[ .GRAPHICS ]
) -> *Texture #must {
    assert(width > 0);
    assert(!(flags & .SWAPCHAIN),
           "You cannot explicitly set SWAPCHAIN flag");
    assert(!(flags & .RESOLUTION_DEPENDENT),
           "You cannot explicitly set RESOLUTION_DEPENDENT flag. You can set it by passing appropriate memory kind");
    assert(depth_or_array_size > 0 || !(flags & .ARRAY),
           "Number of elements in array of textures cannot be 0"); // @TODO: Dynamic arrays?
    assert((flags & (.COLOR_TARGET | .DEPTH_STENCIL)) != (.COLOR_TARGET | .DEPTH_STENCIL),
           "COLOR_TARGET and DEPTH_STENCIL flags cannot be combined");
    assert((flags & (.DEPTH_STENCIL | .READ_ONLY)) == (.DEPTH_STENCIL | .READ_ONLY) || !(flags & .READ_ONLY),
           "READ_ONLY flags can be combined only with DEPTH_STENCIL flag");
    assert(samples_count ==  1 ||
           samples_count ==  2 ||
           samples_count ==  4 ||
           samples_count ==  8 ||
           samples_count == 16 ||
           samples_count == 32 ||
           samples_count == 64);
    assert(possible_owners.count > 0);

    #if memory_kind == .PERSISTENT_RESOLUTION_DEPENDENT || memory_kind == .PER_LEVEL_RESOLUTION_DEPENDENT {
        assert(!(flags & .CUBE),
               "Cube textures cannot be resolution dependent");
        assert(mips_count == 1,
               "Resolution dependent textures can only have 1 mip level since there are some uncertainty in how we should handle mip levels count > 1 in some cases. e.g. on resize");

        flags |= .RESOLUTION_DEPENDENT;

        back_buffer := getBackBuffer(device);

        width  = back_buffer.width;
        height = back_buffer.height;
    } else {
        assert(width == height || !(flags & .CUBE),
               "Cube textures must have identical width and height");

        max_mips_count := maxMipsCount(width, height, depth_or_array_size * cast,no_check(u16) (flags & .ARRAY));
        if mips_count == Texture.ALL_MIPS {
            mips_count = max_mips_count;
        } else {
            assert(0 < mips_count && mips_count <= max_mips_count,
                   "Too many MIP levels requested: %, maximum allowed: %",
                   mips_count,
                   max_mips_count);
        }
    }

    texture : *Texture;

    if #complete device.graphics_api == {
        case .VULKAN;
            texture = createVulkanTexture(cast(*VulkanDevice) device,
                                          cast(*VulkanTextureManager) manager,
                                          format,
                                          width,
                                          height,
                                          depth_or_array_size,
                                          samples_count,
                                          mips_count,
                                          flags,
                                          name,
                                          memory_kind,
                                          ..possible_owners);
    }

    assert((texture.dimension != ._3D) || !(texture.flags & .ARRAY),
           "Texture arrays cannot consist of 3D textures");

    return texture;
}

textureFormatFlags :: (format : Texture.Format) -> Texture.FormatFlags #no_context {
    if #complete format == {
        case .UNKNOWN;       return 0;
        case .RGB8_UNORM;    return .UNCOMPRESSED | .COLOR;
        case .RGB8_SNORM;    return .UNCOMPRESSED | .COLOR;
        case .BGR8_UNORM;    return .UNCOMPRESSED | .COLOR;
        case .BGR8_SNORM;    return .UNCOMPRESSED | .COLOR;
        case .RGBA8_UNORM;   return .UNCOMPRESSED | .COLOR;
        case .BGRA8_UNORM;   return .UNCOMPRESSED | .COLOR;
        case .RGB10A2_UNORM; return .UNCOMPRESSED | .COLOR;
        case .D32;           return .UNCOMPRESSED | .DEPTH;
        case .S8;            return .UNCOMPRESSED | .STENCIL;
        case .BC7_UNORM;     return .COMPRESSED   | .COLOR;
    }
    return 0;
}

#scope_file

#load "../platform/vulkan/texture.jai";

// We may not to check for all_bits != 0 since we have assert for width > 0 in createTexture
maxMipsCount :: (width : u16, height : u16, depth : u16) -> u8 #no_context {
    all_bits := width | height | depth;
    max_mips : u16 = 0;
    #asm { bsr.w max_mips, all_bits; }
    return cast,no_check(u8) max_mips;
}
