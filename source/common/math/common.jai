#scope_export

PI : f32 : Math.PI;

// Interval machine epsilons
DEFAULT_F32_EPSILON : f32 : 0.00001;
DEFAULT_F64_EPSILON : f64 : 0.0000001;

Rect :: struct {
    x : s16;
    y : s16;
    using,except(raw) resolution : Resolution;

    #place x; raw : u64;
} #no_padding
#assert size_of(Rect) == size_of(u64);

operator == :: inline (left : Rect, right : Rect) -> bool {
    return left.raw == right.raw;
}

Resolution :: struct {
    width  : u16;
    height : u16;

    #place width; raw : u32;
} #no_padding
#assert size_of(Resolution) == size_of(u32);

operator == :: inline (left : Resolution, right : Resolution) -> bool {
    return left.raw == right.raw;
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

floorToPowerOfTwo :: inline (value : $T/.[u8, u16, u32, u64]) -> T #no_context {
    #if CPU == .X64 {
        B :: #ifx T == u8 then u16 else T;
        result : T = ---;
        #asm {
            result === a;
            index  : gpr === c;
        }
        #if size_of(T) == 1 #asm {
            movzxbw value,  value;
        } else #asm {
            xor.q   result, result; // because setnz
        }
        #asm {
            bsr?B   index,  value;
            cmovz?B index,  value;
            setnz   result;
            shl?T   result, index;
        }
    } else {
        notImplemented();
    }
    return result;
}

ceilToPowerOfTwo :: no_inline (value : $T/.[u8, u16, u32, u64]) -> T #no_context {
    value -= 1;
    value |= value >> 1;
    value |= value >> 2;
    value |= value >> 4;
    #if size_of(T) > 1 then value |= value >> 8;
    #if size_of(T) > 2 then value |= value >> 16;
    #if size_of(T) > 4 then value |= value >> 32;
    value += 1;
    return value;
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

sign :: inline (value : $T/Type.[s8, s16, s32, s64, f32, f64], $no_zero := false) -> T #no_context {
    #if no_zero {
        return cast(T) ifx value < 0 then -1 else 1;
    } else {
        return cast(T) ifx value < 0 then -1 else
                       ifx value > 0 then  1 else
                       0;
    }
}

sign :: inline (value : $T/Type.[u8, u16, u32, u64], $no_zero := false) -> T #no_context {
    return cast(T) #ifx no_zero then 1 else value != 0;
}

abs :: inline (value : f32) -> f32 #no_context {
    union { f : f32; u : u32; }
    f  = value;
    u &= 0x7FFF_FFFF;
    return f;
}

abs :: inline (value : f64) -> f64 #no_context {
    union { f : f64; u : u64; }
    f  = value;
    u &= 0x7FFF_FFFF_FFFF_FFFF;
    return f;
}

abs :: inline (value : $T/Type.[s8, s16, s32, s64]) -> T #no_context {
    return ifx value < 0 then -value else value;
}

almostEquals :: inline (a : $T/Type.[f32, f64], b : T, $epsilon : T = 0.0) -> bool #no_context {
    #if T == f32 {
        EPS :: #ifx epsilon > 0.0 then epsilon else DEFAULT_F32_EPSILON;
    } else {
        EPS :: #ifx epsilon > 0.0 then epsilon else DEFAULT_F64_EPSILON;
    }
    return abs(a - b) <= EPS;
}

almostZero :: inline (value : $T/Type.[f32, f64], $epsilon : T = 0.0) -> bool #no_context {
    #if T == f32 {
        EPS :: #ifx epsilon > 0.0 then epsilon else DEFAULT_F32_EPSILON;
    } else {
        EPS :: #ifx epsilon > 0.0 then epsilon else DEFAULT_F64_EPSILON;
    }
    return abs(value) <= EPS;
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
    return pow(value, 1.0 / gamma);
}

gammaToLinear :: inline (value : $T/Type.[f32, f64], gamma : T = 2.2) {
    return pow(value, gamma);
}

degToRad :: inline (deg : f32) -> f32 #no_context {
    return deg * (PI / 180.0);
}

radToDeg :: inline (rad : f32) -> f32 #no_context {
    return rad * (180.0 / PI);
}

sqrt :: inline (value : $T) -> T {
    return inline Math.sqrt(value);
}

pow :: inline (value : $T, power : T) -> T {
    return inline Math.pow(value, power);
}

sin :: inline (value : $T) -> T {
    return inline Math.sin(value);
}

cos :: inline (value : $T) -> T {
    return inline Math.cos(value);
}

cot :: inline (value : $T) -> T {
    return cast(T) inline Math.cot(value);
}

ceil :: inline (value : $T) -> T {
    return inline Math.ceil(value);
}


#scope_file

rejectVectors :: inline (T : Type) -> bool #compile_time {
    return T != v2f && T != v2s && T != v2u
        && T != v3f && T != v3s && T != v3u
        && T != v4f && T != v4s && T != v4u;
}

rejectMatrices :: inline (T : Type) -> bool #compile_time {
    return T != m2x2 && T != m3x3 && T != m3x4 && T != m4x3 && T != m4x4;
}

isAnyOf :: (type : Type, types : ..Type_Info_Tag) -> bool #compile_time {
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

Math :: #import "Math";
