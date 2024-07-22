#include "graphics_bindings.shader_header"

#vertex_shader

layout(push_constant) uniform PushConstants {
    Indices32Ref     indices_ref;
    DefaultVertexRef vertices_ref;
    uint32_t         per_view_uniform_index;
} g_push_constants;

out vec3 o_color;

void main() {
    Indices32Ref     index_ref  = g_push_constants.indices_ref[gl_VertexIndex];
    DefaultVertexRef vertex_ref = g_push_constants.vertices_ref[gl_BaseInstance + index_ref.index];

    f32vec4 position = f32vec4(vertex_ref.position_u.xyz, 1.0);

    // model transform
    {
        // put it upper
        position.y += 6.0;

        // Make it left hand
        position.z = -position.z;

        // rotate
        const float32_t angle = g_per_frame_uniform.time;
        const float32_t s     = sin(angle);
        const float32_t c     = cos(angle);
        position.xz = position.xx * f32vec2(c, -s) + position.zz * f32vec2(s, c);
    }

    gl_Position = g_per_view_uniforms[g_push_constants.per_view_uniform_index].view_proj_matrix * position;
    o_color     = vertex_ref.normal_v.xyz;
}

#fragment_shader

in  vec3 i_color;
out vec4 o_color;

void main() {
    o_color = vec4(i_color, 1.0);
}

#pipeline_state

FrontFace        = COUNTER_CLOCKWISE;
CullMode         = BACK_FACE;
DepthTestEnable  = true;
DepthWriteEnable = true;
