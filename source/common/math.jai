#scope_export

isPowerOfTwo :: inline (value : $T) -> bool #no_context #modify { return T != f32 && T != f64; } {
    return value && !(value & (value - 1));
}

alignDownWithPowerOfTwo :: inline (value : $T, alignment : T) -> T #modify { return T != f32 && T != f64; } {
    assert(isPowerOfTwo(alignment));
    return value & ~(alignment - 1);
}

alignUpWithPowerOfTwo :: inline (value : $T, alignment : T) -> T #modify { return T != f32 && T != f64; } {
    assert(isPowerOfTwo(alignment));
    mask := alignment - 1;
    return (value + mask) & ~mask;
}

kiloByte :: inline ($$value : $T) -> T #no_context #modify { return T != f32 && T != f64; } {
    return value << 10;
}

megaByte :: inline ($$value : $T) -> T #no_context #modify { return T != f32 && T != f64; } {
    return value << 20;
}

gigaByte :: inline ($$value : $T) -> T #no_context #modify { return T != f32 && T != f64; } {
    return value << 30;
}

teraByte :: inline ($$value : $T) -> T #no_context #modify { return T != f32 && T != f64; } {
    return value << 40;
}
