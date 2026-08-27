#include "graphics_bindings.shader_header"

#vertex_shader

layout(buffer_reference, buffer_reference_align = 4) readonly buffer MeshRef {
    mat4x3   model_to_mesh;
    mat4x3   mesh_to_model;
    uint16_t material_index;
};

layout(push_constant) uniform PushConstants {
    Indices32Ref     indices_ref;
    PNUVRef          vertices_ref;
    MeshRef          mesh_ref;
    uint32_t         per_view_uniform_index;
} g_vs_push_constants;

out vec2 o_uv;

void main() {
    Indices32Ref index_ref  = g_vs_push_constants.indices_ref[gl_VertexIndex];
    PNUVRef      vertex_ref = g_vs_push_constants.vertices_ref[index_ref.index];

    vec3 ws_position = g_vs_push_constants.mesh_ref.mesh_to_model * vec4(vertex_ref.position_u.xyz, 1.0);

    // WS transform
    {
        // put it upper
        ws_position.y += 6.0;

        // rotate
        const float angle = g_per_frame_uniform.time;
        const float s     = sin(angle);
        const float c     = cos(angle);
        ws_position.xz = vec2(c, -s) * ws_position.xx + vec2(s, c) * ws_position.zz;
    }

    gl_Position = g_per_view_uniforms[g_vs_push_constants.per_view_uniform_index].view_proj_matrix * vec4(ws_position, 1.0);
    o_uv        = vec2(vertex_ref.position_u.w, vertex_ref.normal_v.w);
}

#fragment_shader

layout(push_constant) uniform PushConstants {
    layout(offset = 28) uint16_t texture_index;
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
