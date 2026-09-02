#scope_export

X_AXIS :: 0;
Y_AXIS :: 1;
Z_AXIS :: 2;

m3x3 :: struct {
    e00, e01, e02 : f32;
    e10, e11, e12 : f32;
    e20, e21, e22 : f32;

    #overlay(e00) rows : [3] v3f;
    #overlay(e00) e    : [3][3] f32;
    #overlay(e00) flat : [9] f32;
}

m3x4 :: struct {
    e00, e01, e02, e03 : f32;
    e10, e11, e12, e13 : f32;
    e20, e21, e22, e23 : f32;

    #overlay(e00) rows : [3] v4f;
    #overlay(e00) e    : [3][4] f32;
    #overlay(e00) flat : [12] f32;
}

m4x4 :: struct {
    e00, e01, e02, e03 : f32;
    e10, e11, e12, e13 : f32;
    e20, e21, e22, e23 : f32;
    e30, e31, e32, e33 : f32;

    #overlay(e00) rows : [4] v4f;
    #overlay(e00) _3x4 : m3x4;
    #overlay(e00) e    : [4][4] f32;
    #overlay(e00) flat : [16] f32;
}

#assert isTightlyPacked(m3x3);
#assert isTightlyPacked(m3x4);
#assert isTightlyPacked(m4x4);

ALL_MATRIX_TYPES :: Type.[ m3x3, m3x4, m4x4 ];

IDENTITY_3X3 :: m3x3.{ e00 = 1, e11 = 1, e22 = 1 };
IDENTITY_3X4 :: m3x4.{ e00 = 1, e11 = 1, e22 = 1 };
IDENTITY_4X4 :: m4x4.{ e00 = 1, e11 = 1, e22 = 1, e33 = 1 };

operator [] :: inline (m : *$T/ALL_MATRIX_TYPES, index : int) -> type_of(T.rows[0]) #no_context {
    return m.rows[index];
}

operator *[] :: inline (m : *$T/ALL_MATRIX_TYPES, index : int) -> *type_of(T.rows[0]) #no_context {
    return *m.rows[index];
}

operator []= :: inline (m : *$T/ALL_MATRIX_TYPES, index : int, value : type_of(T.rows[0])) #no_context {
    m.rows[index] = value;
}

extend :: inline (from : m3x3, $To : Type, $identity := true) -> To #no_context {
    #assert To == m3x4 || To == m4x4;

    to := To.{
        rows[0].xyz = from.rows[0],
        rows[1].xyz = from.rows[1],
        rows[2].xyz = from.rows[2],
    };

    #if identity && To.rows.count >= 4 {
        to.e33 = 1.0;
    }

    return to;
}

extend :: inline (from : m3x4, $identity := true) -> m4x4 #no_context {
    return .{
        rows[0] = from.rows[0],
        rows[1] = from.rows[1],
        rows[2] = from.rows[2],
        e33 = #ifx identity then 1.0 else 0.0,
    };
}

isNonZero :: inline (m : $T/ALL_MATRIX_TYPES) -> bool #no_context {
    is_non_zero := isNonZero(m.rows[0])
                || isNonZero(m.rows[1])
                || isNonZero(m.rows[2]);
    #if T.rows.count >= 4 {
        is_non_zero ||= isNonZero(m.rows[3]);
    }
    return is_non_zero;
}

isZero :: inline (m : $T/ALL_MATRIX_TYPES) -> bool #no_context { return !isNonZero(m); }

isIdentity :: inline (m : m3x3) -> bool #no_context { return m == IDENTITY_3X3; }
isIdentity :: inline (m : m3x4) -> bool #no_context { return m == IDENTITY_3X4; }
isIdentity :: inline (m : m4x4) -> bool #no_context { return m == IDENTITY_4X4; }

operator + :: inline (a : m3x3, b : m3x3) -> m3x3 #no_context { return .{ rows[0] = a.rows[0] + b.rows[0], rows[1] = a.rows[1] + b.rows[1], rows[2] = a.rows[2] + b.rows[2] }; }
operator + :: inline (a : m3x4, b : m3x4) -> m3x4 #no_context { return .{ rows[0] = a.rows[0] + b.rows[0], rows[1] = a.rows[1] + b.rows[1], rows[2] = a.rows[2] + b.rows[2] }; }
operator + :: inline (a : m4x4, b : m4x4) -> m4x4 #no_context { return .{ rows[0] = a.rows[0] + b.rows[0], rows[1] = a.rows[1] + b.rows[1], rows[2] = a.rows[2] + b.rows[2], rows[3] = a.rows[3] + b.rows[3] }; }
operator + :: inline (a : m3x3, b : f32) -> m3x3 #no_context #symmetric { return .{ rows[0] = a.rows[0] + b, rows[1] = a.rows[1] + b, rows[2] = a.rows[2] + b }; }
operator + :: inline (a : m3x4, b : f32) -> m3x4 #no_context #symmetric { return .{ rows[0] = a.rows[0] + b, rows[1] = a.rows[1] + b, rows[2] = a.rows[2] + b }; }
operator + :: inline (a : m4x4, b : f32) -> m4x4 #no_context #symmetric { return .{ rows[0] = a.rows[0] + b, rows[1] = a.rows[1] + b, rows[2] = a.rows[2] + b, rows[3] = a.rows[3] + b }; }

operator - :: inline (a : m3x3, b : m3x3) -> m3x3 #no_context { return .{ rows[0] = a.rows[0] - b.rows[0], rows[1] = a.rows[1] - b.rows[1], rows[2] = a.rows[2] - b.rows[2] }; }
operator - :: inline (a : m3x4, b : m3x4) -> m3x4 #no_context { return .{ rows[0] = a.rows[0] - b.rows[0], rows[1] = a.rows[1] - b.rows[1], rows[2] = a.rows[2] - b.rows[2] }; }
operator - :: inline (a : m4x4, b : m4x4) -> m4x4 #no_context { return .{ rows[0] = a.rows[0] - b.rows[0], rows[1] = a.rows[1] - b.rows[1], rows[2] = a.rows[2] - b.rows[2], rows[3] = a.rows[3] - b.rows[3] }; }
operator - :: inline (a : m3x3, b : f32) -> m3x3 #no_context { return .{ rows[0] = a.rows[0] - b, rows[1] = a.rows[1] - b, rows[2] = a.rows[2] - b }; }
operator - :: inline (a : m3x4, b : f32) -> m3x4 #no_context { return .{ rows[0] = a.rows[0] - b, rows[1] = a.rows[1] - b, rows[2] = a.rows[2] - b }; }
operator - :: inline (a : m4x4, b : f32) -> m4x4 #no_context { return .{ rows[0] = a.rows[0] - b, rows[1] = a.rows[1] - b, rows[2] = a.rows[2] - b, rows[3] = a.rows[3] - b }; }

operator * :: inline (a : m3x3, b : f32) -> m3x3 #no_context #symmetric { return .{ rows[0] = a.rows[0] * b, rows[1] = a.rows[1] * b, rows[2] = a.rows[2] * b }; }
operator * :: inline (a : m3x4, b : f32) -> m3x4 #no_context #symmetric { return .{ rows[0] = a.rows[0] * b, rows[1] = a.rows[1] * b, rows[2] = a.rows[2] * b }; }
operator * :: inline (a : m4x4, b : f32) -> m4x4 #no_context #symmetric { return .{ rows[0] = a.rows[0] * b, rows[1] = a.rows[1] * b, rows[2] = a.rows[2] * b, rows[3] = a.rows[3] * b }; }
operator * :: inline (a : m3x3, b : m3x3) -> m3x3 #no_context { return .{ rows[0] = a.rows[0] * b.rows[0], rows[1] = a.rows[1] * b.rows[1], rows[2] = a.rows[2] * b.rows[2] }; }
operator * :: inline (a : m3x4, b : m3x4) -> m3x4 #no_context { return .{ rows[0] = a.rows[0] * b.rows[0], rows[1] = a.rows[1] * b.rows[1], rows[2] = a.rows[2] * b.rows[2] }; }
operator * :: inline (a : m4x4, b : m4x4) -> m4x4 #no_context { return .{ rows[0] = a.rows[0] * b.rows[0], rows[1] = a.rows[1] * b.rows[1], rows[2] = a.rows[2] * b.rows[2], rows[3] = a.rows[3] * b.rows[3] }; }

operator / :: inline (a : m3x3, b : f32) -> m3x3 #no_context { return .{ rows[0] = a.rows[0] / b, rows[1] = a.rows[1] / b, rows[2] = a.rows[2] / b }; }
operator / :: inline (a : m3x4, b : f32) -> m3x4 #no_context { return .{ rows[0] = a.rows[0] / b, rows[1] = a.rows[1] / b, rows[2] = a.rows[2] / b }; }
operator / :: inline (a : m4x4, b : f32) -> m4x4 #no_context { return .{ rows[0] = a.rows[0] / b, rows[1] = a.rows[1] / b, rows[2] = a.rows[2] / b, rows[3] = a.rows[3] / b }; }

mul :: inline (m : m3x3, v : v3f) -> v3f #no_context { return .{ dot(m.rows[0], v), dot(m.rows[1], v), dot(m.rows[2], v) }; }
mul :: inline (m : m3x4, v : v4f) -> v3f #no_context { return .{ dot(m.rows[0], v), dot(m.rows[1], v), dot(m.rows[2], v) }; }
mul :: inline (m : m4x4, v : v4f) -> v4f #no_context { return .{ dot(m.rows[0], v), dot(m.rows[1], v), dot(m.rows[2], v), dot(m.rows[3], v) }; }

mul :: inline (a : m3x3, b : m3x3) -> m3x3 #no_context {
    bt := transpose(b);
    return .{
        dot(a.rows[0], bt.rows[0]), dot(a.rows[0], bt.rows[1]), dot(a.rows[0], bt.rows[2]),
        dot(a.rows[1], bt.rows[0]), dot(a.rows[1], bt.rows[1]), dot(a.rows[1], bt.rows[2]),
        dot(a.rows[2], bt.rows[0]), dot(a.rows[2], bt.rows[1]), dot(a.rows[2], bt.rows[2]),
    };
}

// multiplication of two 4x4 matrices extended to identity
mul :: inline (a : m3x3, b : m3x4) -> m3x4 #no_context {
    c0 := v3f.{ b.e00, b.e10, b.e20 };
    c1 := v3f.{ b.e01, b.e11, b.e21 };
    c2 := v3f.{ b.e02, b.e12, b.e22 };
    c3 := v3f.{ b.e03, b.e13, b.e23 };
    return .{
        dot(a.rows[0], c0), dot(a.rows[0], c1), dot(a.rows[0], c2), dot(a.rows[0], c3),
        dot(a.rows[1], c0), dot(a.rows[1], c1), dot(a.rows[1], c2), dot(a.rows[1], c3),
        dot(a.rows[2], c0), dot(a.rows[2], c1), dot(a.rows[2], c2), dot(a.rows[2], c3),
    };
}

// multiplication of two 4x4 matrices extended to identity
mul :: inline (a : m3x3, b : m4x4) -> m4x4 #no_context {
    bt := transpose(b);
    return .{
        dot(a.rows[0], bt.rows[0].xyz), dot(a.rows[0], bt.rows[1].xyz), dot(a.rows[0], bt.rows[2].xyz), dot(a.rows[0], bt.rows[3].xyz),
        dot(a.rows[1], bt.rows[0].xyz), dot(a.rows[1], bt.rows[1].xyz), dot(a.rows[1], bt.rows[2].xyz), dot(a.rows[1], bt.rows[3].xyz),
        dot(a.rows[2], bt.rows[0].xyz), dot(a.rows[2], bt.rows[1].xyz), dot(a.rows[2], bt.rows[2].xyz), dot(a.rows[2], bt.rows[3].xyz),
                                 b.e30,                          b.e31,                          b.e32,                          b.e33,
    };
}

// multiplication of two 4x4 matrices extended to identity
mul :: inline (a : m3x4, b : m3x3) -> m3x4 #no_context {
    bt := transpose(b);
    return .{
        dot(a.rows[0].xyz, bt.rows[0]), dot(a.rows[0].xyz, bt.rows[1]), dot(a.rows[0].xyz, bt.rows[2]), a.e03,
        dot(a.rows[1].xyz, bt.rows[0]), dot(a.rows[1].xyz, bt.rows[1]), dot(a.rows[1].xyz, bt.rows[2]), a.e13,
        dot(a.rows[2].xyz, bt.rows[0]), dot(a.rows[2].xyz, bt.rows[1]), dot(a.rows[2].xyz, bt.rows[2]), a.e23,
    };
}

// multiplication of two 4x4 matrices extended to identity
mul :: inline (a : m3x4, b : m3x4) -> m3x4 #no_context {
    c0 := v3f.{ b.e00, b.e10, b.e20 };
    c1 := v3f.{ b.e01, b.e11, b.e21 };
    c2 := v3f.{ b.e02, b.e12, b.e22 };
    c3 := v3f.{ b.e03, b.e13, b.e23 };
    return .{
        dot(a.rows[0].xyz, c0), dot(a.rows[0].xyz, c1), dot(a.rows[0].xyz, c2), dot(a.rows[0].xyz, c3) + a.e03,
        dot(a.rows[1].xyz, c0), dot(a.rows[1].xyz, c1), dot(a.rows[1].xyz, c2), dot(a.rows[1].xyz, c3) + a.e13,
        dot(a.rows[2].xyz, c0), dot(a.rows[2].xyz, c1), dot(a.rows[2].xyz, c2), dot(a.rows[2].xyz, c3) + a.e23,
    };
}

// multiplication of two 4x4 matrices extended to identity
mul :: inline (a : m3x4, b : m4x4) -> m4x4 #no_context {
    bt := transpose(b);
    return .{
        dot(a.rows[0], bt.rows[0]), dot(a.rows[0], bt.rows[1]), dot(a.rows[0], bt.rows[2]), dot(a.rows[0], bt.rows[3]),
        dot(a.rows[1], bt.rows[0]), dot(a.rows[1], bt.rows[1]), dot(a.rows[1], bt.rows[2]), dot(a.rows[1], bt.rows[3]),
        dot(a.rows[2], bt.rows[0]), dot(a.rows[2], bt.rows[1]), dot(a.rows[2], bt.rows[2]), dot(a.rows[2], bt.rows[3]),
                             b.e30,                      b.e31,                      b.e32,                      b.e33,
    };
}

// multiplication of two 4x4 matrices extended to identity
mul :: inline (a : m4x4, b : m3x3) -> m4x4 #no_context {
    bt := transpose(b);
    return .{
        dot(a.rows[0].xyz, bt.rows[0]), dot(a.rows[0].xyz, bt.rows[1]), dot(a.rows[0].xyz, bt.rows[2]), a.e03,
        dot(a.rows[1].xyz, bt.rows[0]), dot(a.rows[1].xyz, bt.rows[1]), dot(a.rows[1].xyz, bt.rows[2]), a.e13,
        dot(a.rows[2].xyz, bt.rows[0]), dot(a.rows[2].xyz, bt.rows[1]), dot(a.rows[2].xyz, bt.rows[2]), a.e23,
        dot(a.rows[3].xyz, bt.rows[0]), dot(a.rows[3].xyz, bt.rows[1]), dot(a.rows[3].xyz, bt.rows[2]), a.e33,
    };
}

// multiplication of two 4x4 matrices extended to identity
mul :: inline (a : m4x4, b : m3x4) -> m4x4 #no_context {
    c0 := v3f.{ b.e00, b.e10, b.e20 };
    c1 := v3f.{ b.e01, b.e11, b.e21 };
    c2 := v3f.{ b.e02, b.e12, b.e22 };
    c3 := v3f.{ b.e03, b.e13, b.e23 };
    return .{
        dot(a.rows[0].xyz, c0), dot(a.rows[0].xyz, c1), dot(a.rows[0].xyz, c2), dot(a.rows[0].xyz, c3) + a.e03,
        dot(a.rows[1].xyz, c0), dot(a.rows[1].xyz, c1), dot(a.rows[1].xyz, c2), dot(a.rows[1].xyz, c3) + a.e13,
        dot(a.rows[2].xyz, c0), dot(a.rows[2].xyz, c1), dot(a.rows[2].xyz, c2), dot(a.rows[2].xyz, c3) + a.e23,
        dot(a.rows[3].xyz, c0), dot(a.rows[3].xyz, c1), dot(a.rows[3].xyz, c2), dot(a.rows[3].xyz, c3) + a.e33,
    };
}

mul :: inline (a : m4x4, b : m4x4) -> m4x4 #no_context {
    bt := transpose(b);
    return .{
        dot(a.rows[0], bt.rows[0]), dot(a.rows[0], bt.rows[1]), dot(a.rows[0], bt.rows[2]), dot(a.rows[0], bt.rows[3]),
        dot(a.rows[1], bt.rows[0]), dot(a.rows[1], bt.rows[1]), dot(a.rows[1], bt.rows[2]), dot(a.rows[1], bt.rows[3]),
        dot(a.rows[2], bt.rows[0]), dot(a.rows[2], bt.rows[1]), dot(a.rows[2], bt.rows[2]), dot(a.rows[2], bt.rows[3]),
        dot(a.rows[3], bt.rows[0]), dot(a.rows[3], bt.rows[1]), dot(a.rows[3], bt.rows[2]), dot(a.rows[3], bt.rows[3]),
    };
}

operator == :: inline (a : $T/ALL_MATRIX_TYPES, b : T) -> bool #no_context { return memcmp(*a, *b, size_of(T)) == 0; }
operator != :: inline (a : $T/ALL_MATRIX_TYPES, b : T) -> bool #no_context { return memcmp(*a, *b, size_of(T)) != 0; }

preTransform  :: inline (a : *$A/ALL_MATRIX_TYPES, b : $B/ALL_MATRIX_TYPES) #no_context { a.* = mul(a.*, b); }
postTransform :: inline (a : *$A/ALL_MATRIX_TYPES, b : $B/ALL_MATRIX_TYPES) #no_context { a.* = mul(b, a.*); }

transpose :: inline (m : m3x3) -> m3x3 #no_context {
    return .{
        m.e00, m.e10, m.e20,
        m.e01, m.e11, m.e21,
        m.e02, m.e12, m.e22,
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

determinant :: inline (m : m3x3) -> f32 #no_context {
    return m.e00 * (m.e11 * m.e22 - m.e12 * m.e21)
         - m.e01 * (m.e10 * m.e22 - m.e12 * m.e20)
         + m.e02 * (m.e10 * m.e21 - m.e11 * m.e20);
}

// determinant of 4x4 matrix extended to identity
determinant :: inline (m : m3x4) -> f32 #no_context {
    return m.e00 * (m.e11 * m.e22 - m.e12 * m.e21)
         - m.e01 * (m.e10 * m.e22 - m.e12 * m.e20)
         + m.e02 * (m.e10 * m.e21 - m.e11 * m.e20)
         - m.e03;
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
lookToMatrix :: (camera : v3f, direction : v3f, world_up : v3f = .{ 0, 1, 0 }) -> m3x4 {
    assertNormalized(world_up);
    assertNormalized(direction);

    axis_z := direction;
    axis_x := normalize(cross(world_up, axis_z));
    axis_y := cross(axis_z, axis_x);
    view_t := -camera;

    assertNormalized(axis_x);
    assertNormalized(axis_y);
    // axis_z is already checked

    return .{
        axis_x.x, axis_x.y, axis_x.z, dot(axis_x, view_t),
        axis_y.x, axis_y.y, axis_y.z, dot(axis_y, view_t),
        axis_z.x, axis_z.y, axis_z.z, dot(axis_z, view_t),
    };
}

// Left handed
lookToMatrixAndItsInverse :: (camera : v3f, direction : v3f, world_up : v3f = .{ 0, 1, 0 }) -> (view : m3x4, inverse_view : m3x4) {
    assertNormalized(world_up);
    assertNormalized(direction);

    axis_z := direction;
    axis_x := normalize(cross(world_up, axis_z));
    axis_y := cross(axis_z, axis_x);
    view_t := -camera;

    assertNormalized(axis_x);
    assertNormalized(axis_y);
    // axis_z is already checked

    return .{
        axis_x.x, axis_x.y, axis_x.z, dot(axis_x, view_t),
        axis_y.x, axis_y.y, axis_y.z, dot(axis_y, view_t),
        axis_z.x, axis_z.y, axis_z.z, dot(axis_z, view_t),
    }, .{
        axis_x.x, axis_y.x, axis_z.x, camera.x,
        axis_x.y, axis_y.y, axis_z.y, camera.y,
        axis_x.z, axis_y.z, axis_z.z, camera.z,
    };
}

// Left handed
lookAtMatrix :: inline (camera : v3f, target : v3f, world_up : v3f = .{ 0, 1, 0 }) -> m3x4 {
    return lookToMatrix(camera, normalize(target - camera), world_up);
}

// Left handed
lookAtMatrixAndItsInverse :: inline (camera : v3f, target : v3f, world_up : v3f = .{ 0, 1, 0 }) -> (view : m3x4, inv_view : m3x4) {
    view, inverse_view := lookToMatrixAndItsInverse(camera, normalize(target - camera), world_up);
    return view, inverse_view;
}

// Left handed: camera z axis looks forward
perspectiveProjectionMatrixFromFov :: (aspect_ratio : f32, fov : f32, near : f32, far : f32, $reverse_z := true) -> m4x4 {
    assert(aspect_ratio > 0);
    assert(0 < fov && fov < PI, "FOV should be less than PI and greater than 0. Maybe you passed degrees instead of radians by accident?");
    assert(near < far);

    ct     := cot(0.5 * fov);
    neg_nf := -(near * far);

    #if reverse_z {
        depth := near - far;
        e22   := near / depth;
    } else {
        depth := far - near;
        e22   := far / depth;
    }

    return .{
        e00 = ct / aspect_ratio,
        e11 = ct,
        e22 = e22,
        e23 = neg_nf / depth,
        e32 = 1.0
    };
}

// Left handed: camera z axis looks forward
perspectiveProjectionMatrixFromFovAndItsInverse :: (aspect_ratio : f32, fov : f32, near : f32, far : f32, $reverse_z := true) -> (projection : m4x4, inverse_projection : m4x4) {
    assert(aspect_ratio > 0);
    assert(0 < fov && fov < PI, "FOV should be less than PI and greater than 0. Maybe you passed degrees instead of radians by accident?");
    assert(near < far);

    ct     := cot(0.5 * fov);
    neg_nf := -(near * far);

    #if reverse_z {
        depth := near - far;
        e22   := near / depth;
        ie33  := 1.0  / far;
    } else {
        depth := far - near;
        e22   := far / depth;
        ie33  := 1.0 / near;
    }

    return .{
        e00 = ct / aspect_ratio,
        e11 = ct,
        e22 = e22,
        e23 = neg_nf / depth,
        e32 = 1.0
    }, .{
        e00 = aspect_ratio / ct,
        e11 = 1.0 / ct,
        e23 = 1.0,
        e32 = depth / neg_nf,
        e33 = ie33
    };
}

// Left handed: camera z axis looks forward
perspectiveProjectionMatrix :: inline (width : f32, height : f32, near : f32, far : f32, $reverse_z := true) -> m4x4 #no_context {
    _2n    := 2.0 * near;
    neg_nf := -(near * far);

    #if reverse_z {
        depth := near - far;
        e22   := near / depth;
    } else {
        depth := far - near;
        e22   := far / depth;
    }

    return .{
        e00 = _2n / width,
        e11 = _2n / height,
        e22 = e22,
        e23 = neg_nf / depth,
        e32 = 1.0
    };
}

// Left handed: camera z axis looks forward
perspectiveProjectionMatrixAndItsInverse :: inline (width : f32, height : f32, near : f32, far : f32, $reverse_z := true) -> (projection : m4x4, inverse_projection : m4x4) #no_context {
    _2n    := 2.0 * near;
    neg_nf := -(near * far);

    #if reverse_z {
        depth := near - far;
        e22   := near / depth;
        ie33  := 1.0  / far;
    } else {
        depth := far - near;
        e22   := far / depth;
        ie33  := 1.0 / near;
    }

    return .{
        e00 = _2n / width,
        e11 = _2n / height,
        e22 = e22,
        e23 = neg_nf / depth,
        e32 = 1.0
    }, .{
        e00 = width  / _2n,
        e11 = height / _2n,
        e23 = 1.0,
        e32 = depth / neg_nf,
        e33 = ie33
    };
}

translation :: inline (v : v3f) -> m3x4 #no_context {
    return .{
        1.0, 0.0, 0.0, v.x,
        0.0, 1.0, 0.0, v.y,
        0.0, 0.0, 1.0, v.z,
    };
}

scaling :: inline (v : v3f) -> m3x3 #no_context {
    return .{
        v.x, 0.0, 0.0,
        0.0, v.y, 0.0,
        0.0, 0.0, v.z,
    };
}

rotationX :: inline (s : f32, c : f32) -> m3x3 #no_context {
    return .{
        1.0, 0.0, 0.0,
        0.0,   c,  -s,
        0.0,   s,   c,
    };
}

rotationY :: inline (s : f32, c : f32) -> m3x3 #no_context {
    return .{
          c, 0.0,   s,
        0.0, 1.0, 0.0,
         -s, 0.0,   c,
    };
}

rotationZ :: inline (s : f32, c : f32) -> m3x3 #no_context {
    return .{
          c,  -s, 0.0,
          s,   c, 0.0,
        0.0, 0.0, 1.0,
    };
}

rotation :: inline (around : v3f, s : f32, c : f32) -> m3x3 {
    assertNormalized(around);

    flipped_cos := 1.0 - c;

    col0 := around * around.x * flipped_cos + v3f.{       1.0,  around.z, -around.y } * v3f.{ c, s, s };
    col1 := around * around.y * flipped_cos + v3f.{ -around.z,       1.0,  around.x } * v3f.{ s, c, s };
    col2 := around * around.z * flipped_cos + v3f.{  around.y, -around.x,       1.0 } * v3f.{ s, s, c };

    return .{
        col0.x, col1.x, col2.x,
        col0.y, col1.y, col2.y,
        col0.z, col1.z, col2.z,
    };
}

rotationX :: (angle : f32) -> m3x3 { return rotationX(sin(angle), cos(angle)); }
rotationY :: (angle : f32) -> m3x3 { return rotationY(sin(angle), cos(angle)); }
rotationZ :: (angle : f32) -> m3x3 { return rotationZ(sin(angle), cos(angle)); }
rotation  :: (around : v3f, angle : f32) -> m3x3 { return rotation(around, sin(angle), cos(angle)); }

preTranslate :: inline (m : *$T/Type.[m3x4, m4x4], v : v3f) #no_context {
    m.e03 = dot(m.rows[0].xyz, v) + m.e03;
    m.e13 = dot(m.rows[1].xyz, v) + m.e13;
    m.e23 = dot(m.rows[2].xyz, v) + m.e23;
    #if T.rows.count == 4 {
        m.e33 = dot(m.rows[3].xyz, v) + m.e33;
    }
}

postTranslate :: inline (m : *m3x4, v : v3f) #no_context {
    m.e03 += v.x;
    m.e13 += v.y;
    m.e23 += v.z;
}

preScale :: inline (m : *$T/ALL_MATRIX_TYPES, v : v3f) #no_context {
    #if T.rows[0].e.count >= 4 {
        m.rows[0].xyz *= s;
        m.rows[1].xyz *= s;
        m.rows[2].xyz *= s;
        #if T.rows.count >= 4 then m.rows[3].xyz *= s;
    } else {
        m.rows[0] *= s;
        m.rows[1] *= s;
        m.rows[2] *= s;
        #if T.rows.count >= 4 then m.rows[3] *= s;
    }
}

postScale :: inline (m : *$T/ALL_MATRIX_TYPES, v : v3f) #no_context {
    m.rows[0] *= s.x;
    m.rows[1] *= s.y;
    m.rows[2] *= s.z;
}

preRotateX :: inline (m : *$T/ALL_MATRIX_TYPES, s : f32, c : f32) #no_context {
    m01 := m.e01 * c + m.e02 * s;
    m11 := m.e11 * c + m.e12 * s;
    m21 := m.e21 * c + m.e22 * s;
    #if T.rows.count >= 4 then m31 := m.e31 * c + m.e32 * s;

    m02 := m.e02 * c - m.e01 * s;
    m12 := m.e12 * c - m.e11 * s;
    m22 := m.e22 * c - m.e21 * s;
    #if T.rows.count >= 4 then m32 := m.e32 * c - m.e31 * s;

    m.e01 = m01;
    m.e11 = m11;
    m.e21 = m21;
    #if T.rows.count >= 4 then m.e31 = m31;

    m.e02 = m02;
    m.e12 = m12;
    m.e22 = m22;
    #if T.rows.count >= 4 then m.e32 = m32;
}

preRotateY :: inline (m : *$T/ALL_MATRIX_TYPES, s : f32, c : f32) #no_context {
    m00 := m.e00 * c - m.e02 * s;
    m10 := m.e10 * c - m.e12 * s;
    m20 := m.e20 * c - m.e22 * s;
    #if T.rows.count >= 4 then m30 := m.e30 * c - m.e32 * s;

    m02 := m.e00 * s + m.e02 * c;
    m12 := m.e10 * s + m.e12 * c;
    m22 := m.e20 * s + m.e22 * c;
    #if T.rows.count >= 4 then m32 := m.e30 * s + m.e32 * c;

    m.e00 = m00;
    m.e10 = m10;
    m.e20 = m20;
    #if T.rows.count >= 4 then m.e30 = m30;

    m.e02 = m02;
    m.e12 = m12;
    m.e22 = m22;
    #if T.rows.count >= 4 then m.e32 = m32;
}

preRotateZ :: inline (m : *$T/ALL_MATRIX_TYPES, s : f32, c : f32) #no_context {
    m00 := m.e00 * c + m.e01 * s;
    m10 := m.e10 * c + m.e11 * s;
    #if T.rows.count >= 3 then m20 := m.e20 * c + m.e21 * s;
    #if T.rows.count >= 4 then m30 := m.e30 * c + m.e31 * s;

    m01 := m.e01 * c - m.e00 * s;
    m11 := m.e11 * c - m.e10 * s;
    #if T.rows.count >= 3 then m21 := m.e21 * c - m.e20 * s;
    #if T.rows.count >= 4 then m31 := m.e31 * c - m.e30 * s;

    m.e00 = m00;
    m.e10 = m10;
    #if T.rows.count >= 3 then m.e20 = m20;
    #if T.rows.count >= 4 then m.e30 = m30;

    m.e01 = m01;
    m.e11 = m11;
    #if T.rows.count >= 3 then m.e21 = m21;
    #if T.rows.count >= 4 then m.e31 = m31;
}

preRotateX :: (m : *$T/ALL_MATRIX_TYPES, angle : f32) { preRotateX(m, sin(angle), cos(angle)); }
preRotateY :: (m : *$T/ALL_MATRIX_TYPES, angle : f32) { preRotateY(m, sin(angle), cos(angle)); }
preRotateZ :: (m : *$T/ALL_MATRIX_TYPES, angle : f32) { preRotateZ(m, sin(angle), cos(angle)); }

postRotateX :: inline (m : *$T/ALL_MATRIX_TYPES, s : f32, c : f32) #no_context {
    r1 := m.rows[1] * c - m.rows[2] * s;
    r2 := m.rows[1] * s + m.rows[2] * c;

    m.rows[1] = r1;
    m.rows[2] = r2;
}

postRotateY :: inline (m : *$T/ALL_MATRIX_TYPES, s : f32, c : f32) #no_context {
    r0 := m.rows[0] * c + m.rows[2] * s;
    r2 := m.rows[2] * c - m.rows[0] * s;

    m.rows[0] = r0;
    m.rows[2] = r2;
}

postRotateZ :: inline (m : *$T/ALL_MATRIX_TYPES, s : f32, c : f32) #no_context {
    r0 := m.rows[0] * c - m.rows[1] * s;
    r1 := m.rows[0] * s + m.rows[1] * c;

    m.rows[0] = r0;
    m.rows[1] = r1;
}

postRotateX :: (m : *$T/ALL_MATRIX_TYPES, angle : f32) { postRotateX(m, sin(angle), cos(angle)); }
postRotateY :: (m : *$T/ALL_MATRIX_TYPES, angle : f32) { postRotateY(m, sin(angle), cos(angle)); }
postRotateZ :: (m : *$T/ALL_MATRIX_TYPES, angle : f32) { postRotateZ(m, sin(angle), cos(angle)); }
