#scope_export

v2f :: struct {
    x : f32;
    y : f32;

    #place x; e : [2] f32;
}

v2s :: struct {
    x : s32;
    y : s32;

    #place x; e : [2] s32;
}

v2u :: struct {
    x : u32;
    y : u32;

    #place x; e : [2] u32;
}

v3f :: struct {
    x : f32;
    y : f32;
    z : f32;

    #place x; xy : v2f;
    #place y; yz : v2f;

    #place x; e : [3] f32;
}

v3s :: struct {
    x : s32;
    y : s32;
    z : s32;

    #place x; xy : v2s;
    #place y; yz : v2s;

    #place x; e : [3] s32;
}

v3u :: struct {
    x : u32;
    y : u32;
    z : u32;

    #place x; xy : v2u;
    #place y; yz : v2u;

    #place x; e : [3] u32;
}

v4f :: struct {
    x : f32;
    y : f32;
    z : f32;
    w : f32;

    #place x; xyz : v3f;
    #place y; yzw : v3f;

    #place x; xy : v2f;
    #place y; yz : v2f;
    #place z; zw : v2f;

    #place x; e : [4] f32;
}

v4s :: struct {
    x : s32;
    y : s32;
    z : s32;
    w : s32;

    #place x; xyz : v3s;
    #place y; yzw : v3s;

    #place x; xy : v2s;
    #place y; yz : v2s;
    #place z; zw : v2s;

    #place x; e : [4] s32;
}

v4u :: struct {
    x : u32;
    y : u32;
    z : u32;
    w : u32;

    #place x; xyz : v3u;
    #place y; yzw : v3u;

    #place x; xy : v2u;
    #place y; yz : v2u;
    #place z; zw : v2u;

    #place x; e : [4] u32;
}

#assert size_of(v2f) == 8;
#assert size_of(v2s) == 8;
#assert size_of(v2u) == 8;
#assert size_of(v3f) == 12;
#assert size_of(v3s) == 12;
#assert size_of(v3u) == 12;
#assert size_of(v4f) == 16;
#assert size_of(v4s) == 16;
#assert size_of(v4u) == 16;

operator [] :: inline (v : $T/Type.[v2f, v2s, v2u, v3f, v3s, v3u, v4f, v4s, v4u], index : int) -> type_of(T.x) #no_context {
    return v.e[index];
}

operator []= :: inline (v : *$T/Type.[v2f, v2s, v2u, v3f, v3s, v3u, v4f, v4s, v4u], index : int, value : type_of(T.x)) #no_context {
    v.e[index] = value;
}

operator - :: inline (v : $T/Type.[v2f, v2s]) -> T #no_context { return .{ -v.x, -v.y }; }
operator - :: inline (v : $T/Type.[v3f, v3s]) -> T #no_context { return .{ -v.x, -v.y, -v.z }; }
operator - :: inline (v : $T/Type.[v4f, v4s]) -> T #no_context { return .{ -v.x, -v.y, -v.z, -v.w }; }

operator + :: inline (a : $T/Type.[v2f, v2s, v2u], b : T) -> T #no_context { return .{ a.x + b.x, a.y + b.y }; }
operator + :: inline (a : $T/Type.[v3f, v3s, v3u], b : T) -> T #no_context { return .{ a.x + b.x, a.y + b.y, a.z + b.z }; }
operator + :: inline (a : $T/Type.[v4f, v4s, v4u], b : T) -> T #no_context { return .{ a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w }; }
operator + :: inline (a : $T/Type.[v2f, v2s, v2u], b : type_of(T.x)) -> T #no_context #symmetric { return .{ a.x + b, a.y + b }; }
operator + :: inline (a : $T/Type.[v3f, v3s, v3u], b : type_of(T.x)) -> T #no_context #symmetric { return .{ a.x + b, a.y + b, a.z + b }; }
operator + :: inline (a : $T/Type.[v4f, v4s, v4u], b : type_of(T.x)) -> T #no_context #symmetric { return .{ a.x + b, a.y + b, a.z + b, a.w + b }; }

operator - :: inline (a : $T/Type.[v2f, v2s, v2u], b : T) -> T #no_context { return .{ a.x - b.x, a.y - b.y }; }
operator - :: inline (a : $T/Type.[v3f, v3s, v3u], b : T) -> T #no_context { return .{ a.x - b.x, a.y - b.y, a.z - b.z }; }
operator - :: inline (a : $T/Type.[v4f, v4s, v4u], b : T) -> T #no_context { return .{ a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w }; }
operator - :: inline (a : $T/Type.[v2f, v2s, v2u], b : type_of(T.x)) -> T #no_context { return .{ a.x - b, a.y - b }; }
operator - :: inline (a : $T/Type.[v3f, v3s, v3u], b : type_of(T.x)) -> T #no_context { return .{ a.x - b, a.y - b, a.z - b }; }
operator - :: inline (a : $T/Type.[v4f, v4s, v4u], b : type_of(T.x)) -> T #no_context { return .{ a.x - b, a.y - b, a.z - b, a.w - b }; }
operator - :: inline (a : type_of(T.x), b : $T/Type.[v2f, v2s, v2u]) -> T #no_context { return .{ a - b.x, a - b.y }; }
operator - :: inline (a : type_of(T.x), b : $T/Type.[v3f, v3s, v3u]) -> T #no_context { return .{ a - b.x, a - b.y, a - b.z }; }
operator - :: inline (a : type_of(T.x), b : $T/Type.[v4f, v4s, v4u]) -> T #no_context { return .{ a - b.x, a - b.y, a - b.z, a - b.w }; }

operator * :: inline (a : $T/Type.[v2f, v2s, v2u], b : T) -> T #no_context { return .{ a.x * b.x, a.y * b.y }; }
operator * :: inline (a : $T/Type.[v3f, v3s, v3u], b : T) -> T #no_context { return .{ a.x * b.x, a.y * b.y, a.z * b.z }; }
operator * :: inline (a : $T/Type.[v4f, v4s, v4u], b : T) -> T #no_context { return .{ a.x * b.x, a.y * b.y, a.z * b.z, a.w * b.w }; }
operator * :: inline (a : $T/Type.[v2f, v2s, v2u], b : type_of(T.x)) -> T #no_context #symmetric { return .{ a.x * b, a.y * b }; }
operator * :: inline (a : $T/Type.[v3f, v3s, v3u], b : type_of(T.x)) -> T #no_context #symmetric { return .{ a.x * b, a.y * b, a.z * b }; }
operator * :: inline (a : $T/Type.[v4f, v4s, v4u], b : type_of(T.x)) -> T #no_context #symmetric { return .{ a.x * b, a.y * b, a.z * b, a.w * b }; }

operator / :: inline (a : $T/Type.[v2f, v2s, v2u], b : T) -> T #no_context { return .{ a.x / b.x, a.y / b.y }; }
operator / :: inline (a : $T/Type.[v3f, v3s, v3u], b : T) -> T #no_context { return .{ a.x / b.x, a.y / b.y, a.z / b.z }; }
operator / :: inline (a : $T/Type.[v4f, v4s, v4u], b : T) -> T #no_context { return .{ a.x / b.x, a.y / b.y, a.z / b.z, a.w / b.w }; }
operator / :: inline (a : $T/Type.[v2f, v2s, v2u], b : type_of(T.x)) -> T #no_context { return .{ a.x / b, a.y / b }; }
operator / :: inline (a : $T/Type.[v3f, v3s, v3u], b : type_of(T.x)) -> T #no_context { return .{ a.x / b, a.y / b, a.z / b }; }
operator / :: inline (a : $T/Type.[v4f, v4s, v4u], b : type_of(T.x)) -> T #no_context { return .{ a.x / b, a.y / b, a.z / b, a.w / b }; }
operator / :: inline (a : type_of(T.x), b : $T/Type.[v2f, v2s, v2u]) -> T #no_context { return .{ a / b.x, a / b.y }; }
operator / :: inline (a : type_of(T.x), b : $T/Type.[v3f, v3s, v3u]) -> T #no_context { return .{ a / b.x, a / b.y, a / b.z }; }
operator / :: inline (a : type_of(T.x), b : $T/Type.[v4f, v4s, v4u]) -> T #no_context { return .{ a / b.x, a / b.y, a / b.z, a / b.w }; }

isNonZero :: inline (v : $T/Type.[v2f, v2s, v2u]) -> bool { return v.x || v.y; }
isNonZero :: inline (v : $T/Type.[v3f, v3s, v3u]) -> bool { return v.x || v.y || v.z; }
isNonZero :: inline (v : $T/Type.[v4f, v4s, v4u]) -> bool { return v.x || v.y || v.z || v.w; }

isZero :: inline (v : $T/Type.[v2f, v2s, v2u, v3f, v3s, v3u, v4f, v4s, v4u]) -> bool { return !isNonZero(v); }

dot :: inline (a : $T/Type.[v2f, v2s, v2u], b : T) -> type_of(T.x) #no_context { return a.x * b.x + a.y * b.y; }
dot :: inline (a : $T/Type.[v3f, v3s, v3u], b : T) -> type_of(T.x) #no_context { return a.x * b.x + a.y * b.y + a.z * b.z; }
dot :: inline (a : $T/Type.[v4f, v4s, v4u], b : T) -> type_of(T.x) #no_context { return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w; }

// We cannot make them #no_context because Math.sqrt uses context for some reason
distance :: inline (a : $T/Type.[v2f, v3f, v4f], b : T) -> f32 { return Math.sqrt(dot(a, b)); }
length   :: inline (v : $T/Type.[v2f, v3f, v4f]) -> f32 { return Math.sqrt(dot(v, v)); }

normalize :: inline (v : $T/Type.[v2f, v3f, v4f], fallback : T = .{}) -> T { l := length(v); return ifx l >= F32_EPSILON then v / l else fallback; }

normalized :: inline (v : $T/Type.[v2f, v3f, v4f]) -> bool #no_context { return almostEquals(dot(v, v), 1.0); }

cross :: inline (a : v3f, b : v3f) -> v3f #no_context { return .{ a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x }; }

operator == :: inline (a : $T/Type.[v2f, v2s, v2u], b : T) -> bool #no_context { return a.x == b.x && a.y == b.y; }
operator == :: inline (a : $T/Type.[v3f, v3s, v3u], b : T) -> bool #no_context { return a.x == b.x && a.y == b.y && a.z == b.z; }
operator == :: inline (a : $T/Type.[v4f, v4s, v4u], b : T) -> bool #no_context { return a.x == b.x && a.y == b.y && a.z == b.z && a.w == b.w; }

operator != :: inline (a : $T/Type.[v2f, v2s, v2u], b : T) -> bool #no_context { return a.x != b.x || a.y != b.y; }
operator != :: inline (a : $T/Type.[v3f, v3s, v3u], b : T) -> bool #no_context { return a.x != b.x || a.y != b.y || a.z != b.z; }
operator != :: inline (a : $T/Type.[v4f, v4s, v4u], b : T) -> bool #no_context { return a.x != b.x || a.y != b.y || a.z != b.z || a.w != b.w; }

//
// @Speed: Maybe at least here there is a sense to use SIMD?
//

sign :: inline (v : $T/Type.[v2f, v2s, v2u], $no_zero := false) -> T #no_context { return .{ sign(v.x, no_zero), sign(v.y, no_zero) }; }
sign :: inline (v : $T/Type.[v3f, v3s, v3u], $no_zero := false) -> T #no_context { return .{ sign(v.x, no_zero), sign(v.y, no_zero), sign(v.z, no_zero) }; }
sign :: inline (v : $T/Type.[v4f, v4s, v4u], $no_zero := false) -> T #no_context { return .{ sign(v.x, no_zero), sign(v.y, no_zero), sign(v.z, no_zero), sign(v.w, no_zero) }; }

abs :: inline (v : $T/Type.[v2f, v2s]) -> T #no_context { return .{ abs(v.x), abs(v.y) }; }
abs :: inline (v : $T/Type.[v3f, v3s]) -> T #no_context { return .{ abs(v.x), abs(v.y), abs(v.z) }; }
abs :: inline (v : $T/Type.[v4f, v4s]) -> T #no_context { return .{ abs(v.x), abs(v.y), abs(v.z), abs(v.w) }; }

min :: inline (a : $T/Type.[v2f, v2s, v2u], b : T) -> T #no_context { return .{ min(a.x, b.x), min(a.y, b.y) }; }
min :: inline (a : $T/Type.[v3f, v3s, v3u], b : T) -> T #no_context { return .{ min(a.x, b.x), min(a.y, b.y), min(a.z, b.z) }; }
min :: inline (a : $T/Type.[v4f, v4s, v4u], b : T) -> T #no_context { return .{ min(a.x, b.x), min(a.y, b.y), min(a.z, b.z), min(a.w, b.w) }; }

max :: inline (a : $T/Type.[v2f, v2s, v2u], b : T) -> T #no_context { return .{ max(a.x, b.x), max(a.y, b.y) }; }
max :: inline (a : $T/Type.[v3f, v3s, v3u], b : T) -> T #no_context { return .{ max(a.x, b.x), max(a.y, b.y), max(a.z, b.z) }; }
max :: inline (a : $T/Type.[v4f, v4s, v4u], b : T) -> T #no_context { return .{ max(a.x, b.x), max(a.y, b.y), max(a.z, b.z), max(a.w, b.w) }; }

lerp :: inline (a : v2f, b : v2f, t : f32) -> v2f #no_context { return .{ lerp(a.x, b.x, t), lerp(a.y, b.y, t) }; }
lerp :: inline (a : v3f, b : v3f, t : f32) -> v3f #no_context { return .{ lerp(a.x, b.x, t), lerp(a.y, b.y, t), lerp(a.z, b.z, t) }; }
lerp :: inline (a : v4f, b : v4f, t : f32) -> v4f #no_context { return .{ lerp(a.x, b.x, t), lerp(a.y, b.y, t), lerp(a.z, b.z, t), lerp(a.w, b.w, t) }; }

clamp :: inline (v : $T/Type.[v2f, v2s, v2u], a : type_of(T.x), b : type_of(T.x)) -> T #no_context { va := T.{ a, a };       vb := T.{ b, b };       return min(max(v, va), vb); }
clamp :: inline (v : $T/Type.[v3f, v3s, v3u], a : type_of(T.x), b : type_of(T.x)) -> T #no_context { va := T.{ a, a, a };    vb := T.{ b, b, b };    return min(max(v, va), vb); }
clamp :: inline (v : $T/Type.[v4f, v4s, v4u], a : type_of(T.x), b : type_of(T.x)) -> T #no_context { va := T.{ a, a, a, a }; vb := T.{ b, b, b, b }; return min(max(v, va), vb); }

saturate :: inline (v : $T/Type.[v2f, v2s, v2u]) -> T #no_context { v0 : T; v1 := T.{ 1, 1 };       return min(max(v, v0), v1); }
saturate :: inline (v : $T/Type.[v3f, v3s, v3u]) -> T #no_context { v0 : T; v1 := T.{ 1, 1, 1 };    return min(max(v, v0), v1); }
saturate :: inline (v : $T/Type.[v4f, v4s, v4u]) -> T #no_context { v0 : T; v1 := T.{ 1, 1, 1, 1 }; return min(max(v, v0), v1); }

gammaToLinear :: inline (v : v2f, gamma : f32 = 2.2) -> v2f { return .{ Math.pow(v.x, gamma), Math.pow(v.y, gamma) }; }
gammaToLinear :: inline (v : v3f, gamma : f32 = 2.2) -> v3f { return .{ Math.pow(v.x, gamma), Math.pow(v.y, gamma), Math.pow(v.z, gamma) }; }
gammaToLinear :: inline (v : v4f, gamma : f32 = 2.2) -> v4f { return .{ Math.pow(v.x, gamma), Math.pow(v.y, gamma), Math.pow(v.z, gamma), v.w }; }

linearToGamma :: inline (v : v2f, gamma : f32 = 2.2) -> v2f { ig := 1.0 / gamma; return .{ Math.pow(v.x, ig), Math.pow(v.y, ig) }; }
linearToGamma :: inline (v : v3f, gamma : f32 = 2.2) -> v3f { ig := 1.0 / gamma; return .{ Math.pow(v.x, ig), Math.pow(v.y, ig), Math.pow(v.z, ig) }; }
linearToGamma :: inline (v : v4f, gamma : f32 = 2.2) -> v4f { ig := 1.0 / gamma; return .{ Math.pow(v.x, ig), Math.pow(v.y, ig), Math.pow(v.z, ig), v.w }; }
