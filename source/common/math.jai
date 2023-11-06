#scope_export

isPowerOfTwo :: inline (value : $T) -> bool #no_context {
    #assert T != f32 && T != f64;

    return value && !(value & (value - 1));
}

alignDownWithPowerOfTwo :: inline (value : $T, alignment : T) -> T {
    #assert T != f32 && T != f64;
    assert(isPowerOfTwo(alignment));

    return value & ~(alignment - 1);
}

alignUpWithPowerOfTwo :: inline (value : $T, alignment : T) -> T {
    #assert T != f32 && T != f64;
    assert(isPowerOfTwo(alignment));

    mask := alignment - 1;
    return (value + mask) & ~mask;
}

kiloBytes :: inline ($$value : $T/Type.[s16, u16, s32, u32, s64, u64]) -> T #no_context {
    return value << 10;
}

megaBytes :: inline ($$value : $T/Type.[s32, u32, s64, u64]) -> T #no_context {
    return value << 20;
}

gigaBytes :: inline ($$value : $T/Type.[s32, u32, s64, u64]) -> T #no_context {
    return value << 30;
}

teraBytes :: inline ($$value : $T/Type.[s64, u64]) -> T #no_context {
    return value << 40;
}
