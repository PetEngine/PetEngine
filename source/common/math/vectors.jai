#scope_export

v2 :: struct(T : Type) {
    x : T;
    y : T;

    #place x; e : [2] T;
}

v3 :: struct(T : Type) {
    x : T;
    y : T;
    z : T;

    #place x; xy : v2(T);
    #place y; yz : v2(T);

    #place x; e : [3] T;
}

v4 :: struct(T : Type) {
    x : T;
    y : T;
    z : T;
    w : T;

    #place x; xyz : v3(T);
    #place y; yzw : v3(T);

    #place x; xy : v2(T);
    #place y; yz : v2(T);
    #place z; zw : v2(T);

    #place x; e : [4] T;
}

v2f :: v2(f32);
v2s :: v2(s32);
v2u :: v2(u32);

v3f :: v3(f32);
v3s :: v3(s32);
v3u :: v3(u32);

v4f :: v4(f32);
v4s :: v4(s32);
v4u :: v4(u32);

#assert size_of(v2f) == 8;
#assert size_of(v2s) == 8;
#assert size_of(v2u) == 8;

#assert size_of(v3f) == 12;
#assert size_of(v3s) == 12;
#assert size_of(v3u) == 12;

#assert size_of(v4f) == 16;
#assert size_of(v4s) == 16;
#assert size_of(v4u) == 16;

operator [] :: inline (v : $V/.[v2, v3, v4], index : int) -> V.T #no_context {
    return v.e[index];
}

operator *[] :: inline (v : *$V/.[v2, v3, v4], index : int) -> *V.T #no_context {
    return *v.e[index];
}

operator []= :: inline (v : *$V/.[v2, v3, v4], index : int, value : V.T) #no_context {
    v.e[index] = value;
}

operator - :: inline (v : $V/.[v2f, v2s]) -> V #no_context { return .{ -v.x, -v.y }; }
operator - :: inline (v : $V/.[v3f, v3s]) -> V #no_context { return .{ -v.x, -v.y, -v.z }; }
operator - :: inline (v : $V/.[v4f, v4s]) -> V #no_context { return .{ -v.x, -v.y, -v.z, -v.w }; }

operator + :: inline (a : v2, b : v2(a.T)) -> v2(a.T) #no_context { return .{ a.x + b.x, a.y + b.y }; }
operator + :: inline (a : v3, b : v3(a.T)) -> v3(a.T) #no_context { return .{ a.x + b.x, a.y + b.y, a.z + b.z }; }
operator + :: inline (a : v4, b : v4(a.T)) -> v4(a.T) #no_context { return .{ a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w }; }
operator + :: inline (a : v2, b : a.T) -> v2(a.T) #no_context #symmetric { return .{ a.x + b, a.y + b }; }
operator + :: inline (a : v3, b : a.T) -> v3(a.T) #no_context #symmetric { return .{ a.x + b, a.y + b, a.z + b }; }
operator + :: inline (a : v4, b : a.T) -> v4(a.T) #no_context #symmetric { return .{ a.x + b, a.y + b, a.z + b, a.w + b }; }

operator - :: inline (a : v2, b : v2(a.T)) -> v2(a.T) #no_context { return .{ a.x - b.x, a.y - b.y }; }
operator - :: inline (a : v3, b : v3(a.T)) -> v3(a.T) #no_context { return .{ a.x - b.x, a.y - b.y, a.z - b.z }; }
operator - :: inline (a : v4, b : v4(a.T)) -> v4(a.T) #no_context { return .{ a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w }; }
operator - :: inline (a : v2, b : a.T) -> v2(a.T) #no_context { return .{ a.x - b, a.y - b }; }
operator - :: inline (a : v3, b : a.T) -> v3(a.T) #no_context { return .{ a.x - b, a.y - b, a.z - b }; }
operator - :: inline (a : v4, b : a.T) -> v4(a.T) #no_context { return .{ a.x - b, a.y - b, a.z - b, a.w - b }; }
operator - :: inline (a : b.T, b : v2) -> v2(b.T) #no_context { return .{ a - b.x, a - b.y }; }
operator - :: inline (a : b.T, b : v3) -> v3(b.T) #no_context { return .{ a - b.x, a - b.y, a - b.z }; }
operator - :: inline (a : b.T, b : v4) -> v4(b.T) #no_context { return .{ a - b.x, a - b.y, a - b.z, a - b.w }; }

operator * :: inline (a : v2, b : v2(a.T)) -> v2(a.T) #no_context { return .{ a.x * b.x, a.y * b.y }; }
operator * :: inline (a : v3, b : v3(a.T)) -> v3(a.T) #no_context { return .{ a.x * b.x, a.y * b.y, a.z * b.z }; }
operator * :: inline (a : v4, b : v4(a.T)) -> v4(a.T) #no_context { return .{ a.x * b.x, a.y * b.y, a.z * b.z, a.w * b.w }; }
operator * :: inline (a : v2, b : a.T) -> v2(a.T) #no_context #symmetric { return .{ a.x * b, a.y * b }; }
operator * :: inline (a : v3, b : a.T) -> v3(a.T) #no_context #symmetric { return .{ a.x * b, a.y * b, a.z * b }; }
operator * :: inline (a : v4, b : a.T) -> v4(a.T) #no_context #symmetric { return .{ a.x * b, a.y * b, a.z * b, a.w * b }; }

operator / :: inline (a : v2, b : v2(a.T)) -> v2(a.T) #no_context { return .{ a.x / b.x, a.y / b.y }; }
operator / :: inline (a : v3, b : v3(a.T)) -> v3(a.T) #no_context { return .{ a.x / b.x, a.y / b.y, a.z / b.z }; }
operator / :: inline (a : v4, b : v4(a.T)) -> v4(a.T) #no_context { return .{ a.x / b.x, a.y / b.y, a.z / b.z, a.w / b.w }; }
operator / :: inline (a : v2, b : a.T) -> v2(a.T) #no_context { return .{ a.x / b, a.y / b }; }
operator / :: inline (a : v3, b : a.T) -> v3(a.T) #no_context { return .{ a.x / b, a.y / b, a.z / b }; }
operator / :: inline (a : v4, b : a.T) -> v4(a.T) #no_context { return .{ a.x / b, a.y / b, a.z / b, a.w / b }; }
operator / :: inline (a : b.T, b : v2) -> v2(b.T) #no_context { return .{ a / b.x, a / b.y }; }
operator / :: inline (a : b.T, b : v3) -> v3(b.T) #no_context { return .{ a / b.x, a / b.y, a / b.z }; }
operator / :: inline (a : b.T, b : v4) -> v4(b.T) #no_context { return .{ a / b.x, a / b.y, a / b.z, a / b.w }; }

isNonZero :: inline (v : v2) -> bool #no_context { return v.x || v.y; }
isNonZero :: inline (v : v3) -> bool #no_context { return v.x || v.y || v.z; }
isNonZero :: inline (v : v4) -> bool #no_context { return v.x || v.y || v.z || v.w; }

isZero :: inline (v : v2) -> bool #no_context { return !isNonZero(v); }
isZero :: inline (v : v3) -> bool #no_context { return !isNonZero(v); }
isZero :: inline (v : v4) -> bool #no_context { return !isNonZero(v); }

dot :: inline (a : v2, b : v2(a.T)) -> a.T #no_context { return a.x * b.x + a.y * b.y; }
dot :: inline (a : v3, b : v3(a.T)) -> a.T #no_context { return a.x * b.x + a.y * b.y + a.z * b.z; }
dot :: inline (a : v4, b : v4(a.T)) -> a.T #no_context { return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w; }

length   :: inline (v : $V/.[v2f, v3f, v4f])        -> f32 { return sqrt(dot(v, v)); }
distance :: inline (a : $V/.[v2f, v3f, v4f], b : V) -> f32 { return length(a - b); }

normalize :: inline (v : $V/.[v2f, v3f, v4f], $epsilon := DEFAULT_F32_EPSILON, fallback := V.{}) -> V {
    l := length(v);
    return ifx l <= epsilon then fallback else v / l;
}

normalized :: inline (v : $V/.[v2f, v3f, v4f], $epsilon := DEFAULT_F32_EPSILON) -> bool #no_context {
    return almostEquals(dot(v, v), 1.0, epsilon);
}

cross :: inline (a : v3f, b : v3f) -> v3f #no_context { return .{ a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x }; }

operator == :: inline (a : v2, b : v2(a.T)) -> bool #no_context { return a.x == b.x && a.y == b.y; }
operator == :: inline (a : v3, b : v3(a.T)) -> bool #no_context { return a.x == b.x && a.y == b.y && a.z == b.z; }
operator == :: inline (a : v4, b : v4(a.T)) -> bool #no_context { return a.x == b.x && a.y == b.y && a.z == b.z && a.w == b.w; }

operator != :: inline (a : v2, b : v2(a.T)) -> bool #no_context { return a.x != b.x || a.y != b.y; }
operator != :: inline (a : v3, b : v3(a.T)) -> bool #no_context { return a.x != b.x || a.y != b.y || a.z != b.z; }
operator != :: inline (a : v4, b : v4(a.T)) -> bool #no_context { return a.x != b.x || a.y != b.y || a.z != b.z || a.w != b.w; }

sign :: inline (v : v2, $no_zero := false) -> v2(v.T) #no_context { return .{ sign(v.x, no_zero), sign(v.y, no_zero) }; }
sign :: inline (v : v3, $no_zero := false) -> v3(v.T) #no_context { return .{ sign(v.x, no_zero), sign(v.y, no_zero), sign(v.z, no_zero) }; }
sign :: inline (v : v4, $no_zero := false) -> v4(v.T) #no_context { return .{ sign(v.x, no_zero), sign(v.y, no_zero), sign(v.z, no_zero), sign(v.w, no_zero) }; }

abs :: inline (v : $V/.[v2f, v2s]) -> V #no_context { return .{ abs(v.x), abs(v.y) }; }
abs :: inline (v : $V/.[v3f, v3s]) -> V #no_context { return .{ abs(v.x), abs(v.y), abs(v.z) }; }
abs :: inline (v : $V/.[v4f, v4s]) -> V #no_context { return .{ abs(v.x), abs(v.y), abs(v.z), abs(v.w) }; }

almostEquals :: inline (a : $V/.[v2f, v3f, v4f], b : V, $epsilon := DEFAULT_F32_EPSILON) -> bool #no_context {
    av := abs(a - b);
    result := av.x <= epsilon && av.y <= epsilon;
    #if V == v3f || V == v4f then result &&= av.z <= epsilon;
    #if             V == v4f then result &&= av.w <= epsilon;
    return result;
}

almostZero :: inline (v : $V/.[v2f, v3f, v4f], $epsilon := DEFAULT_F32_EPSILON) -> bool #no_context {
    av := abs(v);
    result := av.x <= epsilon && av.y <= epsilon;
    #if V == v3f || V == v4f then result &&= av.z <= epsilon;
    #if             V == v4f then result &&= av.w <= epsilon;
    return result;
}

min :: inline (a : v2, b : v2(a.T)) -> v2(a.T) #no_context { return .{ min(a.x, b.x), min(a.y, b.y) }; }
min :: inline (a : v3, b : v3(a.T)) -> v3(a.T) #no_context { return .{ min(a.x, b.x), min(a.y, b.y), min(a.z, b.z) }; }
min :: inline (a : v4, b : v4(a.T)) -> v4(a.T) #no_context { return .{ min(a.x, b.x), min(a.y, b.y), min(a.z, b.z), min(a.w, b.w) }; }

max :: inline (a : v2, b : v2(a.T)) -> v2(a.T) #no_context { return .{ max(a.x, b.x), max(a.y, b.y) }; }
max :: inline (a : v3, b : v3(a.T)) -> v3(a.T) #no_context { return .{ max(a.x, b.x), max(a.y, b.y), max(a.z, b.z) }; }
max :: inline (a : v4, b : v4(a.T)) -> v4(a.T) #no_context { return .{ max(a.x, b.x), max(a.y, b.y), max(a.z, b.z), max(a.w, b.w) }; }

lerp :: inline (a : v2f, b : v2f, t : f32) -> v2f #no_context { return .{ lerp(a.x, b.x, t), lerp(a.y, b.y, t) }; }
lerp :: inline (a : v3f, b : v3f, t : f32) -> v3f #no_context { return .{ lerp(a.x, b.x, t), lerp(a.y, b.y, t), lerp(a.z, b.z, t) }; }
lerp :: inline (a : v4f, b : v4f, t : f32) -> v4f #no_context { return .{ lerp(a.x, b.x, t), lerp(a.y, b.y, t), lerp(a.z, b.z, t), lerp(a.w, b.w, t) }; }

clamp :: inline (v : v2, a : v.T, b : v.T) -> v2(v.T) #no_context { va := v2.{ a, a };       vb := v2.{ b, b };       return min(max(v, va), vb); }
clamp :: inline (v : v3, a : v.T, b : v.T) -> v3(v.T) #no_context { va := v3.{ a, a, a };    vb := v3.{ b, b, b };    return min(max(v, va), vb); }
clamp :: inline (v : v4, a : v.T, b : v.T) -> v4(v.T) #no_context { va := v4.{ a, a, a, a }; vb := v4.{ b, b, b, b }; return min(max(v, va), vb); }

saturate :: inline (v : v2) -> v2(v.T) #no_context { v0 : v2(v.T); v1 := v2(v.T).{ 1, 1 };       return min(max(v, v0), v1); }
saturate :: inline (v : v3) -> v3(v.T) #no_context { v0 : v3(v.T); v1 := v3(v.T).{ 1, 1, 1 };    return min(max(v, v0), v1); }
saturate :: inline (v : v4) -> v4(v.T) #no_context { v0 : v4(v.T); v1 := v4(v.T).{ 1, 1, 1, 1 }; return min(max(v, v0), v1); }

gammaToLinear :: inline (v : v2f, gamma : f32 = 2.2) -> v2f { return .{ pow(v.x, gamma), pow(v.y, gamma) }; }
gammaToLinear :: inline (v : v3f, gamma : f32 = 2.2) -> v3f { return .{ pow(v.x, gamma), pow(v.y, gamma), pow(v.z, gamma) }; }
gammaToLinear :: inline (v : v4f, gamma : f32 = 2.2) -> v4f { return .{ pow(v.x, gamma), pow(v.y, gamma), pow(v.z, gamma), v.w }; }

linearToGamma :: inline (v : v2f, gamma : f32 = 2.2) -> v2f { ig := 1.0 / gamma; return .{ pow(v.x, ig), pow(v.y, ig) }; }
linearToGamma :: inline (v : v3f, gamma : f32 = 2.2) -> v3f { ig := 1.0 / gamma; return .{ pow(v.x, ig), pow(v.y, ig), pow(v.z, ig) }; }
linearToGamma :: inline (v : v4f, gamma : f32 = 2.2) -> v4f { ig := 1.0 / gamma; return .{ pow(v.x, ig), pow(v.y, ig), pow(v.z, ig), v.w }; }
