#scope_export

PI : f32 : Math.PI;

F32_EPSILON : f32 : 0h34C0_0000;           // 0h3400_0000 is too small and still fails sometimes
F64_EPSILON : f64 : 0h3CB0_0000_0000_0000;

Rect :: struct {
    x : s16;
    y : s16;
    using resolution : Resolution;
}

Resolution :: struct {
    width  : u16;
    height : u16;
}

isPowerOfTwo :: inline (value : $T) -> bool #no_context {
    #assert isAnyOf(T, .INTEGER, .ENUM, .POINTER);

    return value && !(value & (value - 1));
}

alignDownWithPowerOfTwo :: inline (value : $T, alignment : $U) -> T {
    #assert isAnyOf(T, .INTEGER, .ENUM, .POINTER);
    #assert isAnyOf(U, .INTEGER, .ENUM);
    assert(isPowerOfTwo(alignment));

    return value & ~(alignment - 1);
}

alignUpWithPowerOfTwo :: inline (value : $T, alignment : $U) -> T {
    #assert isAnyOf(T, .INTEGER, .ENUM, .POINTER);
    #assert isAnyOf(U, .INTEGER, .ENUM);
    assert(isPowerOfTwo(alignment));

    mask := alignment - 1;
    return (value + mask) & ~mask;
}

nextPowerOfTwo :: inline (value : $T/Type.[u8, u16, u32, u64]) -> T #no_context {
    value |= value >> 1;
    value |= value >> 2;
    value |= value >> 4;
    #if size_of(T) > 1 then value |= value >> 8;
    #if size_of(T) > 2 then value |= value >> 16;
    #if size_of(T) > 4 then value |= value >> 32;
    return value + 1;
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

bytesToKiloBytes :: inline (value : $T, $R := f32) -> R #no_context {
    return cast(R) (value / 1024.0);
}

bytesToMegaBytes :: inline (value : $T, $R := f32) -> R #no_context {
    return cast(R) (value / 1_048_576.0);
}

bytesToGigaBytes :: inline (value : $T, $R := f32) -> R #no_context {
    return cast(R) (value / 1_073_741_824.0);
}

bytesToTeraBytes :: inline (value : $T, $R := f32) -> R #no_context {
    return cast(R) (value / 1_099_511_627_776.0);
}

sign :: inline (value : $T/Type.[s8, s16, s32, s64, f32, f64]) -> T #no_context {
    return ifx value < 0 then -1 else
           ifx value > 0 then  1 else
           0;
}

sign :: inline (value : $T/Type.[u8, u16, u32, u64]) -> T #no_context {
    return value != 0;
}

abs :: inline (value : $T/Type.[f32, f64]) -> T #no_context {
    U :: #ifx T == f32 then u32 else u64;
    union { _float : T; uint : U; }
    _float = value;
    MASK : U : (1 << size_of(T)) - 1;
    uint &= MASK;
    return _float;
}

abs :: inline (value : $T/Type.[s8, s16, s32, s64]) -> T #no_context {
    MASK : T : (1 << size_of(T)) - 1;
    return value & MASK;
}

almostEquals :: (a : $T/Type.[f32, f64], b : T) -> bool #no_context {
    #if T == f32 {
        return abs(a - b) <= F32_EPSILON;
    } else {
        return abs(a - b) <= F64_EPSILON;
    }
}

min :: inline (a : $T, b : T) -> T #no_context #modify { return rejectVectors(T) && rejectMatrices(T); } {
    return ifx a < b then a else b;
}

min :: inline (first : $T, rest : ..T) -> T #no_context {
    result := first;
    for rest { result = min(result, it); }
    return result;
}

max :: inline (a : $T, b : T) -> T #no_context #modify { return rejectVectors(T) && rejectMatrices(T); } {
    return ifx a > b then a else b;
}

max :: inline (first : $T, rest : ..T) -> T #no_context {
    result := first;
    for rest { result = max(result, it); }
    return result;
}

clamp :: inline (v : $T, a : T, b : T) -> T #no_context {
    return min(max(v, a), b);
}

saturate :: inline (v : $T) -> T #no_context #modify { return rejectVectors(T) && rejectMatrices(T); } {
    return min(max(v, 0), 1);
}

lerp :: inline (a : T, b : T, t : $T/Type.[f32, f64]) -> T #no_context {
    return a + (b - a) * t;
}

preciseLerp :: inline (a : T, b : T, t : $T/Type.[f32, f64]) -> T #no_context {
    return a * (1.0 - t) + b * t;
}

invLerp :: inline (a : T, b : T, v : $T/Type.[f32, f64]) -> T #no_context {
    return (v - a) / (b - a);
}

remap :: inline (old_a : T, old_b : T, old_v : $T/Type.[f32, f64], new_a : T, new_b : T) -> T #no_context {
    return lerp(new_a, new_b, invLerp(old_a, old_b, old_v));
}

saturatedRemap :: inline (old_a : T, old_b : T, old_v : $T/Type.[f32, f64], new_a : T, new_b : T) -> T #no_context {
    return lerp(new_a, new_b, saturate(invLerp(old_a, old_b, old_v)));
}

linearToGamma :: inline (value : $T/Type.[f32, f64], gamma : T = 2.2) {
    return Math.pow(value, 1.0 / gamma);
}

gammaToLinear :: inline (value : $T/Type.[f32, f64], gamma : T = 2.2) {
    return Math.pow(value, gamma);
}

degToRad :: inline (deg : f32) -> f32 #no_context {
    return deg * (PI / 180.0);
}

radToDeg :: inline (rad : f32) -> f32 #no_context {
    return rad * (180.0 / PI);
}

#scope_file

rejectVectors :: inline (T : Type) -> bool #compile_time {
    assert(#compile_time, "This function should be run only in compile time"); // @Cleanup: #CompileTime.

    return T != v2f && T != v2s && T != v2u
        && T != v3f && T != v3s && T != v3u
        && T != v4f && T != v4s && T != v4u;
}

rejectMatrices :: inline (T : Type) -> bool #compile_time {
    assert(#compile_time, "This function should be run only in compile time"); // @Cleanup: #CompileTime.

    return T != m2x2 && T != m3x3 && T != m3x4 && T != m4x3 && T != m4x4;
}

isAnyOf :: (type : Type, types : ..Type_Info_Tag) -> bool #compile_time {
    assert(#compile_time, "This function should be run only in compile time"); // @Cleanup: #CompileTime.

    info := cast(*Type_Info) type;

    while info.type == .VARIANT {
        info = (cast(*Type_Info_Variant) info).variant_of;
    }

    for types {
        assert(it != .VARIANT);
        assert(it != .ANY);

        if info.type == it {
            return true;
        }
    }

    return false;
}
