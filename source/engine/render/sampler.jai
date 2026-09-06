// @Important: Should be synced with defines in graphics_bindings.shader_header
Sampler :: enum u8 {
    TRILINEAR_CLAMP;
    TRILINEAR_WRAP;
    ANISOTROPIC_MAX_CLAMP;
    ANISOTROPIC_MAX_WRAP;
};

SamplerState :: struct {
    MAX_ANISOTROPY : u8 : 0xFF;
    MAX_LOD_NONE   : u8 : 0xFF;

    Filter :: enum u8 {
        POINT;
        LINEAR;
    }

    AddressMode :: enum u8 {
        CLAMP;
        WRAP;
        MIRROR;
        BORDER;
    }

    CompareOp :: enum u8 {
        OFF; // do not use compare op
        NEVER;
        LESS;
        EQUAL;
        LESS_OR_EQUAL;
        GREATER;
        NOT_EQUAL;
        GREATER_OR_EQUAL;
        ALWAYS;
    }

    BorderColor :: enum u8 {
        NONE;
        TRANSPARENT;
        BLACK;
        WHITE;
    }

    min_filter := Filter.POINT;
    mag_filter := Filter.POINT;
    mip_filter := Filter.POINT;

    address_mode_u := AddressMode.CLAMP;
    address_mode_v := AddressMode.CLAMP;
    address_mode_w := AddressMode.CLAMP;

    min_lod  : u8;
    max_lod  : u8 = MAX_LOD_NONE;
    lod_bias : f32;

    anisotropy : u8;

    compare_op := CompareOp.OFF;

    border_color := BorderColor.NONE;

    #overlay(min_filter) _alignment : [2] u64;
}
#assert size_of(SamplerState) == 16;

createSamplers :: () {
    assert(!resourceMemoryCommitted(.PERSISTENT),
           "You cannot create %1 sampler after %1 memory is committed",
           ResourceManager.Lifetime.PERSISTENT);

    SAMPLER_MAP :: SamplerState.[
        .{ min_filter = .LINEAR, mag_filter = .LINEAR, mip_filter = .LINEAR                                                                                                                   },
        .{ min_filter = .LINEAR, mag_filter = .LINEAR, mip_filter = .LINEAR, address_mode_u = .WRAP, address_mode_v = .WRAP, address_mode_w = .WRAP                                           },
        .{ min_filter = .LINEAR, mag_filter = .LINEAR, mip_filter = .LINEAR,                                                                         anisotropy = SamplerState.MAX_ANISOTROPY },
        .{ min_filter = .LINEAR, mag_filter = .LINEAR, mip_filter = .LINEAR, address_mode_u = .WRAP, address_mode_v = .WRAP, address_mode_w = .WRAP, anisotropy = SamplerState.MAX_ANISOTROPY },
    ];
    #assert SAMPLER_MAP.count == ResourceManager.MAX_SAMPLERS;

    #run {
        for SAMPLER_MAP {
            assert(it.min_lod <= it.max_lod);
            assert(it.anisotropy <= 2
                || it.anisotropy == 4
                || it.anisotropy == 8
                || it.anisotropy == 16
                || it.anisotropy == SamplerState.MAX_ANISOTROPY);
        }
    }

    for SAMPLER_MAP {
        #if #complete GRAPHICS_API == {
            case .VULKAN; createVulkanSampler(it, type_info(Sampler).names[it_index]);
        }
    }
}
