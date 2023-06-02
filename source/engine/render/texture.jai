TextureManager :: struct {
    MemoryKind :: enum u8 {
        PERSISTENT;
        PER_LEVEL;
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

commitTextures :: (device : *Device, manager : *TextureManager, $memory_kind : TextureManager.MemoryKind) {
    if #complete device.graphics_api == {
        case .VULKAN;
            commitVulkanTextures(cast(*VulkanDevice) device, cast(*VulkanTextureManager) manager, memory_kind);
    }
}

resetTextures :: (device : *Device, manager : *TextureManager, $memory_kind : TextureManager.MemoryKind) {
    if #complete device.graphics_api == {
        case .VULKAN;
            resetVulkanTextures(cast(*VulkanDevice) device, cast(*VulkanTextureManager) manager, memory_kind);
    }
}

Texture :: struct {
    ALL_MIPS : u8 : 0xFF;

    Dimension :: enum u8 {
        _1D;
        _2D;
        _3D;
    }

    Flags :: enum_flags u8 {
        ARRAY;
        CUBE;

        COHERENT;
        NONCOHERENT;
        COLOR_TARGET;
        DEPTH_STENCIL;
        READ_ONLY;

        SWAPCHAIN;
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

    // @TODO: #Math. Make it vector
    ClearValue :: union {
        f32_ : [4] f32;
        u32_ : [4] u32;
    };

    dimension             : Dimension;
    flags                 : Flags;
    width                 : u16;
    height                : u16;
    union {
        depth             : u16;
        array_size        : u16;
    };
    samples_count         : u8;
    mips_count            : u8;
    format                : Format;
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
    assert(!(flags & .SWAPCHAIN), "You cannot explicitly set SWAPCHAIN flag");
    assert(!(flags & .ARRAY) || depth_or_array_size > 0); // @TODO: Dynamic arrays?
    assert(!(flags & .CUBE) || width == height, "Cube textures must have identical width and height");
    assert((flags & (Texture.Flags.COLOR_TARGET | .DEPTH_STENCIL)) != (Texture.Flags.COLOR_TARGET | .DEPTH_STENCIL),
           "COLOR_TARGET and DEPTH_STENCIL flags cannot be combined");
    assert((flags & (Texture.Flags.DEPTH_STENCIL | .READ_ONLY)) == (Texture.Flags.DEPTH_STENCIL | .READ_ONLY) || !(flags & .READ_ONLY),
           "READ_ONLY flags can be combined only with DEPTH_STENCIL flag");
    assert(samples_count ==  1 ||
           samples_count ==  2 ||
           samples_count ==  4 ||
           samples_count ==  8 ||
           samples_count == 16 ||
           samples_count == 32 ||
           samples_count == 64);
    assert(possible_owners.count > 0);

    max_mips_count := maxMipsCount(width, height, depth_or_array_size * cast,no_check(u16) (flags & .ARRAY));
    if mips_count == Texture.ALL_MIPS {
        mips_count = max_mips_count;
    } else {
        assert(0 < mips_count && mips_count <= max_mips_count,
               "Too many MIP levels requested: %, maximum allowed: %",
               mips_count,
               max_mips_count);
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

    assert(!(texture.flags & .ARRAY) || texture.dimension == ._1D || texture.dimension == ._2D,
           "Texture arrays cannot consist of 3D textures");

    return texture;
}

#scope_file

#load "../platform/vulkan/texture.jai";

// We may not to check for all_bits != 0 since we have assert for width > 0 in createTexture
maxMipsCount :: (width : u16, height : u16, depth : u16) -> u8 {
    all_bits := width | height | depth;
    max_mips : u16 = 0;
    #asm { bsr.w max_mips, all_bits; }
    return cast(u8) max_mips;
}
