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

    lifetime : ResourceManager.Lifetime;
    name     : string;
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

createSampler :: (state : SamplerState = .{}, lifetime : ResourceManager.Lifetime, name : string) -> *Sampler #must {
    assert(!resourceMemoryCommitted(lifetime), "You cannot create %1 sampler after %1 memory is committed", lifetime);

    assert(state.min_lod <= state.max_lod);
    assert(state.anisotropy <= 2
        || state.anisotropy == 4
        || state.anisotropy == 8
        || state.anisotropy == 16
        || state.anisotropy == Sampler.MAX_ANISOTROPY);

    manager := context.pet.render.resource_manager;

    sampler := manager.pushPlatformSampler(lifetime);
    sampler.lifetime = lifetime;

    manager.createPlatformSampler(sampler, *state, name);

    return sampler;
}
