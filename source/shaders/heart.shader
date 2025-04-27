#include "graphics_bindings.shader_header"

#vertex_shader

layout(push_constant) uniform PushConstants {
    Indices32Ref     indices_ref;
    DefaultVertexRef vertices_ref;
    uint32_t         per_view_uniform_index;
} g_vs_push_constants;

out vec2 o_uv;

void main() {
    Indices32Ref     index_ref  = g_vs_push_constants.indices_ref[gl_VertexIndex];
    DefaultVertexRef vertex_ref = g_vs_push_constants.vertices_ref[gl_BaseInstance + index_ref.index];

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

    gl_Position = g_per_view_uniforms[g_vs_push_constants.per_view_uniform_index].view_proj_matrix * position;
    o_uv        = vec2(vertex_ref.position_u.w, vertex_ref.normal_v.w);
}

#fragment_shader

layout(push_constant) uniform PushConstants {
    layout(offset = 20) uint16_t texture_index;
    uint16_t sampler_index;
} g_ps_push_constants;

in  vec2 i_uv;
out vec4 o_color;

void main() {
    o_color = texture(sampler2D(g_per_scene_textures_2d[g_ps_push_constants.texture_index],
                                g_per_scene_samplers[g_ps_push_constants.sampler_index]),
                      i_uv);
}

#pipeline_state

FrontFace        = COUNTER_CLOCKWISE;
CullMode         = BACK_FACE;
DepthTestEnable  = true;
DepthWriteEnable = true;
