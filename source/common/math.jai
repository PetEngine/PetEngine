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

kiloBytes :: inline (value : $T/Type.[s16, u16, s32, u32, s64, u64]) -> T #no_context {
    return value << 10;
}

kiloBytes :: inline (value : $T/Type.[f32, f64]) -> T #no_context {
    return value * 1024.0;
}

megaBytes :: inline (value : $T/Type.[s32, u32, s64, u64]) -> T #no_context {
    return value << 20;
}

megaBytes :: inline (value : $T/Type.[f32, f64]) -> T #no_context {
    return value * 1_048_576.0;
}

gigaBytes :: inline (value : $T/Type.[s32, u32, s64, u64]) -> T #no_context {
    return value << 30;
}

gigaBytes :: inline (value : $T/Type.[f32, f64]) -> T #no_context {
    return value * 1_073_741_824.0;
}

teraBytes :: inline (value : $T/Type.[s64, u64]) -> T #no_context {
    return value << 40;
}

teraBytes :: inline (value : $T/Type.[f32, f64]) -> T #no_context {
    return value * 1_099_511_627_776.0;
}

min :: inline (a : $T, b : T) -> T #no_context {
    return ifx a < b then a else b;
}

min :: inline (first : $T, rest : ..T) -> T #no_context {
    result := first;
    for rest if it < result then result = it;
    return result;
}

max :: inline (a : $T, b : T) -> T #no_context {
    return ifx a > b then a else b;
}

max :: inline (first : $T, rest : ..T) -> T #no_context {
    result := first;
    for rest if it > result then result = it;
    return result;
}

clamp :: inline (v : $T, a : T, b : T) -> T #no_context {
    return max(a, min(v, b));
}

saturate :: inline (v : $T) -> T #no_context {
    return max(0, min(v, 1));
}

lerp :: inline (a : T, b : T, t : $T/Type.[f32, f64]) -> T #no_context {
    return a + (b - a) * t;
}

preciseLerp :: inline (a : T, b : T, t : $T/Type.[f32, f64]) -> T #no_context {
    return a * (1.0 - t) + b * t;
}

inverseLerp :: inline (a : T, b : T, v : $T/Type.[f32, f64]) -> T #no_context {
    return (v - a) / (b - a);
}

remap :: inline (old_a : T, old_b : T, old_v : $T/Type.[f32, f64], new_a : T, new_b : T) -> T #no_context {
    return lerp(new_a, new_b, inverseLerp(old_a, old_b, old_v));
}

saturatedRemap :: inline (old_a : T, old_b : T, old_v : $T/Type.[f32, f64], new_a : T, new_b : T) -> T #no_context {
    return lerp(new_a, new_b, saturate(inverseLerp(old_a, old_b, old_v)));
}
