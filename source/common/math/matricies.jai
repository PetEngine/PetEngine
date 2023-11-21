#scope_export

m2x2 :: struct {
    e00, e01 : f32;
    e10, e11 : f32;

    #place e00; rows : [2] v2f;
    #place e00; e    : [2][2] f32;
    #place e00; flat : [4] f32;
}

m3x3 :: struct {
    e00, e01, e02 : f32;
    e10, e11, e12 : f32;
    e20, e21, e22 : f32;

    #place e00; rows : [3] v3f;
    #place e00; e    : [3][3] f32;
    #place e00; flat : [9] f32;
}

m3x4 :: struct {
    e00, e01, e02, e03 : f32;
    e10, e11, e12, e13 : f32;
    e20, e21, e22, e23 : f32;

    #place e00; rows : [3] v4f;
    #place e00; e    : [3][4] f32;
    #place e00; flat : [12] f32;
}

m4x3 :: struct {
    e00, e01, e02 : f32;
    e10, e11, e12 : f32;
    e20, e21, e22 : f32;
    e30, e31, e32 : f32;

    #place e00; rows : [4] v3f;
    #place e00; _3x3 : m3x3;
    #place e00; e    : [4][3] f32;
    #place e00; flat : [12] f32;
}

m4x4 :: struct {
    e00, e01, e02, e03 : f32;
    e10, e11, e12, e13 : f32;
    e20, e21, e22, e23 : f32;
    e30, e31, e32, e33 : f32;

    #place e00; rows : [4] v4f;
    #place e00; _3x4 : m3x4;
    #place e00; e    : [4][4] f32;
    #place e00; flat : [16] f32;
}

#assert size_of(m2x2) == 16;
#assert size_of(m3x3) == 36;
#assert size_of(m3x4) == 48;
#assert size_of(m4x3) == 48;
#assert size_of(m4x4) == 64;

operator [] :: inline (m : $T/Type.[m2x2, m3x3, m3x4, m4x3, m4x4], index : int) -> type_of(T.rows[0]) #no_context {
    return m.rows[index];
}

operator []= :: inline (m : *$T/Type.[m2x2, m3x3, m3x4, m4x3, m4x4], index : int, value : type_of(T.rows[0])) #no_context {
    m.rows[index] = value;
}

identity :: inline ($T : Type) -> T #no_context {
    #if T == m2x2 {
        return .{ e00 = 1, e11 = 1 };
    } else #if T == m3x3 {
        return .{ e00 = 1, e11 = 1, e22 = 1 };
    } else #if T == m3x4 {
        return .{ e00 = 1, e11 = 1, e22 = 1 };
    } else #if T == m4x3 {
        return .{ e00 = 1, e11 = 1, e22 = 1 };
    } else {
        #assert T == m4x4;
        return .{ e00 = 1, e11 = 1, e22 = 1, e33 = 1 };
    }
}

operator + :: inline (a : m2x2, b : m2x2) -> m2x2 #no_context { return .{ a.rows[0] + b.rows[0], a.rows[1] + b.rows[1] }; }
operator + :: inline (a : m3x3, b : m3x3) -> m3x3 #no_context { return .{ a.rows[0] + b.rows[0], a.rows[1] + b.rows[1], a.rows[2] + b.rows[2] }; }
operator + :: inline (a : m3x4, b : m3x4) -> m3x4 #no_context { return .{ a.rows[0] + b.rows[0], a.rows[1] + b.rows[1], a.rows[2] + b.rows[2] }; }
operator + :: inline (a : m4x3, b : m4x3) -> m4x3 #no_context { return .{ a.rows[0] + b.rows[0], a.rows[1] + b.rows[1], a.rows[2] + b.rows[2], a.rows[3] + b.rows[3] }; }
operator + :: inline (a : m4x4, b : m4x4) -> m4x4 #no_context { return .{ a.rows[0] + b.rows[0], a.rows[1] + b.rows[1], a.rows[2] + b.rows[2], a.rows[3] + b.rows[3] }; }
operator + :: inline (a : m2x2, b : f32) -> m2x2 #no_context #symmetric { return .{ a.rows[0] + b, a.rows[1] + b }; }
operator + :: inline (a : m3x3, b : f32) -> m3x3 #no_context #symmetric { return .{ a.rows[0] + b, a.rows[1] + b, a.rows[2] + b }; }
operator + :: inline (a : m3x4, b : f32) -> m3x4 #no_context #symmetric { return .{ a.rows[0] + b, a.rows[1] + b, a.rows[2] + b }; }
operator + :: inline (a : m4x3, b : f32) -> m4x3 #no_context #symmetric { return .{ a.rows[0] + b, a.rows[1] + b, a.rows[2] + b, a.rows[3] + b }; }
operator + :: inline (a : m4x4, b : f32) -> m4x4 #no_context #symmetric { return .{ a.rows[0] + b, a.rows[1] + b, a.rows[2] + b, a.rows[3] + b }; }

operator - :: inline (a : m2x2, b : m2x2) -> m2x2 #no_context { return .{ a.rows[0] - b.rows[0], a.rows[1] - b.rows[1] }; }
operator - :: inline (a : m3x3, b : m3x3) -> m3x3 #no_context { return .{ a.rows[0] - b.rows[0], a.rows[1] - b.rows[1], a.rows[2] - b.rows[2] }; }
operator - :: inline (a : m3x4, b : m3x4) -> m3x4 #no_context { return .{ a.rows[0] - b.rows[0], a.rows[1] - b.rows[1], a.rows[2] - b.rows[2] }; }
operator - :: inline (a : m4x3, b : m4x3) -> m4x3 #no_context { return .{ a.rows[0] - b.rows[0], a.rows[1] - b.rows[1], a.rows[2] - b.rows[2], a.rows[3] - b.rows[3] }; }
operator - :: inline (a : m4x4, b : m4x4) -> m4x4 #no_context { return .{ a.rows[0] - b.rows[0], a.rows[1] - b.rows[1], a.rows[2] - b.rows[2], a.rows[3] - b.rows[3] }; }
operator - :: inline (a : m2x2, b : f32) -> m2x2 #no_context { return .{ a.rows[0] - b, a.rows[1] - b }; }
operator - :: inline (a : m3x3, b : f32) -> m3x3 #no_context { return .{ a.rows[0] - b, a.rows[1] - b, a.rows[2] - b }; }
operator - :: inline (a : m3x4, b : f32) -> m3x4 #no_context { return .{ a.rows[0] - b, a.rows[1] - b, a.rows[2] - b }; }
operator - :: inline (a : m4x3, b : f32) -> m4x3 #no_context { return .{ a.rows[0] - b, a.rows[1] - b, a.rows[2] - b, a.rows[3] - b }; }
operator - :: inline (a : m4x4, b : f32) -> m4x4 #no_context { return .{ a.rows[0] - b, a.rows[1] - b, a.rows[2] - b, a.rows[3] - b }; }

operator * :: inline (a : m2x2, b : f32) -> m2x2 #no_context #symmetric { return .{ a.rows[0] * b, a.rows[1] * b }; }
operator * :: inline (a : m3x3, b : f32) -> m3x3 #no_context #symmetric { return .{ a.rows[0] * b, a.rows[1] * b, a.rows[2] * b }; }
operator * :: inline (a : m3x4, b : f32) -> m3x4 #no_context #symmetric { return .{ a.rows[0] * b, a.rows[1] * b, a.rows[2] * b }; }
operator * :: inline (a : m4x4, b : f32) -> m4x4 #no_context #symmetric { return .{ a.rows[0] * b, a.rows[1] * b, a.rows[2] * b, a.rows[3] * b }; }
operator * :: inline (m : m2x2, v : v2f) -> v2f #no_context { return .{ dot(m.rows[0], v), dot(m.rows[1], v) }; }
operator * :: inline (m : m3x3, v : v3f) -> v3f #no_context { return .{ dot(m.rows[0], v), dot(m.rows[1], v), dot(m.rows[2], v) }; }
operator * :: inline (m : m3x4, v : v4f) -> v3f #no_context { return .{ dot(m.rows[0], v), dot(m.rows[1], v), dot(m.rows[2], v) }; }
operator * :: inline (m : m4x3, v : v3f) -> v4f #no_context { return .{ dot(m.rows[0], v), dot(m.rows[1], v), dot(m.rows[2], v), dot(m.rows[3], v) }; }
operator * :: inline (m : m4x4, v : v4f) -> v4f #no_context { return .{ dot(m.rows[0], v), dot(m.rows[1], v), dot(m.rows[2], v), dot(m.rows[3], v) }; }

operator / :: inline (a : m2x2, b : f32) -> m2x2 #no_context { return .{ a.rows[0] / b, a.rows[1] / b }; }
operator / :: inline (a : m3x3, b : f32) -> m3x3 #no_context { return .{ a.rows[0] / b, a.rows[1] / b, a.rows[2] / b }; }
operator / :: inline (a : m3x4, b : f32) -> m3x4 #no_context { return .{ a.rows[0] / b, a.rows[1] / b, a.rows[2] / b }; }
operator / :: inline (a : m4x4, b : f32) -> m4x4 #no_context { return .{ a.rows[0] / b, a.rows[1] / b, a.rows[2] / b, a.rows[3] / b }; }

operator * :: inline (a : m2x2, b : m2x2) -> m2x2 #no_context {
    bt := transpose(b);
    return .{
        dot(a.rows[0], bt.rows[0]), dot(a.rows[0], bt.rows[1]),
        dot(a.rows[1], bt.rows[0]), dot(a.rows[1], bt.rows[1]),
    };
}

operator * :: inline (a : m3x3, b : m3x3) -> m3x3 #no_context {
    bt := transpose(b);
    return .{
        dot(a.rows[0], bt.rows[0]), dot(a.rows[0], bt.rows[1]), dot(a.rows[0], bt.rows[2]),
        dot(a.rows[1], bt.rows[0]), dot(a.rows[1], bt.rows[1]), dot(a.rows[1], bt.rows[2]),
        dot(a.rows[2], bt.rows[0]), dot(a.rows[2], bt.rows[1]), dot(a.rows[2], bt.rows[2]),
    };
}

operator * :: inline (a : m3x4, b : m4x3) -> m3x3 #no_context {
    bt := transpose(b);
    return .{
        dot(a.rows[0], b.rows[0]), dot(a.rows[0], b.rows[1]), dot(a.rows[0], b.rows[2]),
        dot(a.rows[1], b.rows[0]), dot(a.rows[1], b.rows[1]), dot(a.rows[1], b.rows[2]),
        dot(a.rows[2], b.rows[0]), dot(a.rows[2], b.rows[1]), dot(a.rows[2], b.rows[2]),
    };
}

operator * :: inline (a : m4x3, b : m3x4) -> m4x4 #no_context {
    bt := transpose(b);
    return .{
        dot(a.rows[0], bt.rows[0]), dot(a.rows[0], bt.rows[1]), dot(a.rows[0], bt.rows[2]), dot(a.rows[0], bt.rows[3]),
        dot(a.rows[1], bt.rows[0]), dot(a.rows[1], bt.rows[1]), dot(a.rows[1], bt.rows[2]), dot(a.rows[1], bt.rows[3]),
        dot(a.rows[2], bt.rows[0]), dot(a.rows[2], bt.rows[1]), dot(a.rows[2], bt.rows[2]), dot(a.rows[2], bt.rows[3]),
        dot(a.rows[3], bt.rows[0]), dot(a.rows[3], bt.rows[1]), dot(a.rows[3], bt.rows[2]), dot(a.rows[3], bt.rows[3]),
    };
}

operator * :: inline (a : m4x4, b : m4x4) -> m4x4 #no_context {
    bt := transpose(b);
    return .{
        dot(a.rows[0], bt.rows[0]), dot(a.rows[0], bt.rows[1]), dot(a.rows[0], bt.rows[2]), dot(a.rows[0], bt.rows[3]),
        dot(a.rows[1], bt.rows[0]), dot(a.rows[1], bt.rows[1]), dot(a.rows[1], bt.rows[2]), dot(a.rows[1], bt.rows[3]),
        dot(a.rows[2], bt.rows[0]), dot(a.rows[2], bt.rows[1]), dot(a.rows[2], bt.rows[2]), dot(a.rows[2], bt.rows[3]),
        dot(a.rows[3], bt.rows[0]), dot(a.rows[3], bt.rows[1]), dot(a.rows[3], bt.rows[2]), dot(a.rows[3], bt.rows[3]),
    };
}

transpose :: inline (m : m2x2) -> m2x2 #no_context {
    return .{
        m.e00, m.e10,
        m.e01, m.e11,
    };
}

transpose :: inline (m : m3x3) -> m3x3 #no_context {
    return .{
        m.e00, m.e10, m.e20,
        m.e01, m.e11, m.e21,
        m.e02, m.e12, m.e22,
    };
}

transpose :: inline (m : m3x4) -> m4x3 #no_context {
    return .{
        m.e00, m.e10, m.e20,
        m.e01, m.e11, m.e21,
        m.e02, m.e12, m.e22,
        m.e03, m.e13, m.e23,
    };
}

transpose :: inline (m : m4x3) -> m3x4 #no_context {
    return .{
        m.e00, m.e10, m.e20, m.e30,
        m.e01, m.e11, m.e21, m.e31,
        m.e02, m.e12, m.e22, m.e32,
    };
}

transpose :: inline (m : m4x4) -> m4x4 #no_context {
    return .{
        m.e00, m.e10, m.e20, m.e30,
        m.e01, m.e11, m.e21, m.e31,
        m.e02, m.e12, m.e22, m.e32,
        m.e03, m.e13, m.e23, m.e33,
    };
}

determinant :: inline (m : m2x2) -> f32 #no_context {
    return m.e00 * m.e11 - m.e01 * m.e10;
}

determinant :: inline (m : m3x3) -> f32 #no_context {
    return m.e00 * (m.e11 * m.e22 - m.e12 * m.e21)
         - m.e01 * (m.e10 * m.e22 - m.e12 * m.e20)
         + m.e02 * (m.e10 * m.e21 - m.e11 * m.e20);
}

determinant :: inline (m : m4x4) -> f32 #no_context {
    d0 := m.e22 * m.e33 - m.e23 * m.e32;
    d1 := m.e21 * m.e33 - m.e23 * m.e31;
    d2 := m.e21 * m.e32 - m.e22 * m.e31;
    d3 := m.e20 * m.e33 - m.e23 * m.e30;
    d4 := m.e20 * m.e32 - m.e22 * m.e30;
    d5 := m.e20 * m.e31 - m.e21 * m.e30;

    return m.e00 * (m.e11 * d0 - m.e12 * d1 + m.e13 * d2)
         - m.e01 * (m.e10 * d0 - m.e12 * d3 + m.e13 * d4)
         + m.e02 * (m.e10 * d1 - m.e11 * d3 + m.e13 * d5)
         - m.e03 * (m.e10 * d2 - m.e11 * d4 + m.e12 * d5);
}

// Left handed
viewMatrix :: (camera : v3f, target : v3f, world_up : v3f = .{ 0, 1, 0 }) -> m4x4 {
    assert(isNormal(world_up), "world_up vector should be normal");

    axis_z := normalize(target - camera);
    axis_x := cross(world_up, axis_z);
    axis_y := cross(axis_z, axis_x);

    return .{
        axis_x.x, axis_x.y, axis_x.z, -dot(axis_x, camera),
        axis_y.x, axis_y.y, axis_y.z, -dot(axis_y, camera),
        axis_z.x, axis_z.y, axis_z.z, -dot(axis_z, camera),
             0.0,      0.0,      0.0,                  1.0
    };
}

// Left handed
viewMatrixAndItsInverse :: (camera : v3f, target : v3f, world_up : v3f = .{ 0, 1, 0 }) -> (view : m4x4, view_inverse : m4x4) {
    assert(isNormal(world_up) == 1.0, "world_up vector should be normal");

    axis_z := normalize(target - camera);
    axis_x := cross(world_up, axis_z);
    axis_y := cross(axis_z, axis_x);

    return .{
        axis_x.x, axis_x.y, axis_x.z, -dot(axis_x, camera),
        axis_y.x, axis_y.y, axis_y.z, -dot(axis_y, camera),
        axis_z.x, axis_z.y, axis_z.z, -dot(axis_z, camera),
             0.0,      0.0,      0.0,                  1.0
    }, .{
        axis_x.x, axis_y.x, axis_z.x, camera.x,
        axis_x.y, axis_y.y, axis_z.y, camera.y,
        axis_x.z, axis_y.z, axis_z.z, camera.z,
             0.0,      0.0,      0.0,      1.0
    };
}

// Left handed
perspectiveProjectionMatrix :: inline (aspect_ratio : f32, fov : f32, near : f32, far : f32, $reverse_z := true) -> m4x4 {
    t      := Math.tan(0.5 * fov);
    neg_nf := -(near * far);

    #if reverse_z {
        depth := near - far;

        e22 := near   / depth;
        e23 := neg_nf / depth;
    } else {
        depth := far - near;

        e22 := far    / depth;
        e23 := neg_nf / depth;
    }

    return .{
        e00 = 1.0 / (aspect_ratio * t),
        e11 = 1.0 / t,
        e22 = e22,
        e23 = e23,
        e32 = 1.0
    };
}

// Left handed
perspectiveProjectionMatrixAndItsInverse :: inline (aspect_ratio : f32, fov : f32, near : f32, far : f32, $reverse_z := true) -> (projection : m4x4, inverse_projection : m4x4) {
    t      := Math.tan(0.5 * fov);
    neg_nf := -(near * far);
    at     := aspect_ratio * t;

    #if reverse_z {
        depth := near - far;

        e22 := near   / depth;
        e23 := neg_nf / depth;

        inv_e32 := depth / neg_nf;
        inv_e33 := 1.0   / far;
    } else {
        depth := far - near;

        e22 := far    / depth;
        e23 := neg_nf / depth;

        inv_e32 := depth / neg_nf;
        inv_e33 := 1.0   / near;
    }

    return .{
        e00 = 1.0 / at,
        e11 = 1.0 / t,
        e22 = e22,
        e23 = e23,
        e32 = 1.0
    }, .{
        e00 = at,
        e11 = t,
        e23 = 1.0,
        e32 = inv_e32,
        e33 = inv_e33
    };
}

// Left handed
perspectiveProjectionMatrix :: inline (width : f32, heigt : f32, near : f32, far : f32, $reverse_z := true) -> m4x4 #no_context {
    _2n    := 2.0 * near;
    neg_nf := -(near * far);

    #if reverse_z {
        depth := near - far;

        e22 := near   / depth;
        e23 := neg_nf / depth;
    } else {
        depth := far - near;

        e22 := far    / depth;
        e23 := neg_nf / depth;
    }

    return .{
        e00 = _2n / width,
        e11 = _2n / heigt,
        e22 = e22,
        e23 = e23,
        e32 = 1.0
    };
}

// Left handed
perspectiveProjectionMatrixAndItsInverse :: inline (width : f32, heigt : f32, near : f32, far : f32, $reverse_z := true) -> (projection : m4x4, inverse_projection : m4x4) #no_context {
    _2n    := 2.0 * near;
    neg_nf := -(near * far);

    #if reverse_z {
        depth := near - far;

        e22 := near   / depth;
        e23 := neg_nf / depth;
    } else {
        depth := far - near;

        e22 := far    / depth;
        e23 := neg_nf / depth;
    }

    return .{
        e00 = _2n / width,
        e11 = _2n / heigt,
        e22 = e22,
        e23 = e23,
        e32 = 1.0
    }, .{
        e00 = width  / _2n,
        e11 = height / _2n,
        e23 = 1.0,
        e32 = inv_e32,
        e33 = inv_e33
    };
}

#scope_file

Math :: #import "Math";
