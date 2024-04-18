Sampler :: struct {
    MAX_ANISOTROPY : u8 : 0xFF;
    MAX_LOD_NONE   : u8 : 0xFF;

    Filter :: enum u8 {
        POINT;
        LIENAR;
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

    name : string;
}

SamplerState :: struct {
    min_filter := Sampler.Filter.POINT;
    mag_filter := Sampler.Filter.POINT;
    mip_filter := Sampler.Filter.POINT;

    address_mode_u := Sampler.AddressMode.CLAMP;
    address_mode_v := Sampler.AddressMode.CLAMP;
    address_mode_w := Sampler.AddressMode.CLAMP;

    min_lod  : u8;
    max_lod  : u8 = Sampler.MAX_LOD_NONE;
    lod_bias : f32;

    anisotropy : u8;

    compare_op := Sampler.CompareOp.OFF;

    border_color := Sampler.BorderColor.NONE;

    #place min_filter;
    _alignment : [16] u8;
}
#assert size_of(SamplerState) == 16;

createSampler :: (
    device   : *Device,
    manager  : *ResourceManager,
    state    : SamplerState = .{},
    lifetime : ResourceManager.Lifetime,
    name     : string
) -> *Sampler {
    assert(state.min_lod <= state.max_lod);
    assert(state.anisotropy <= 2
        || state.anisotropy == 4
        || state.anisotropy == 8
        || state.anisotropy == 16
        || state.anisotropy == Sampler.MAX_ANISOTROPY);

    sampler := manager.pushPlatformSampler(device, manager, lifetime);

    manager.createPlatformSampler(device, manager, sampler, *state, lifetime, name);

    return sampler;
}
