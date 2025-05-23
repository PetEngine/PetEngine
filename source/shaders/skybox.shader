#include "graphics_bindings.shader_header"

#vertex_shader

#define F32_MIN 1.18e-38

layout(push_constant) uniform PushConstants {
    uint32_t per_view_uniform_index;
} g_vs_push_constants;

out vec3 o_view;

void main() {
    gl_Position.x = 2.0 * (gl_VertexIndex & 1) - 1.0;
    gl_Position.y = 1.0 - 2.0 * (gl_VertexIndex >> 1);
    gl_Position.z = F32_MIN;
    gl_Position.w = 1.0;

    const mat4x4 inv_view = g_per_view_uniforms[g_vs_push_constants.per_view_uniform_index].inv_view_matrix;
    const mat4x4 inv_proj = g_per_view_uniforms[g_vs_push_constants.per_view_uniform_index].inv_proj_matrix;

    o_view = (inv_proj * gl_Position).xyz;
    o_view = mat3x3(inv_view) * o_view;
    o_view = normalize(o_view.xyz);
}

#fragment_shader

layout(push_constant) uniform PushConstants {
    layout(offset = 4) uint16_t texture_index;
    uint16_t sampler_index;
} g_ps_push_constants;

const vec2 g_sub_pixel_offsets[] = {
    {  1, -3 }, { -1,  3 },
    {  5,  1 }, { -3,  5 },
    { -5,  5 }, { -7,  1 },
    {  3,  7 }, {  7, -7 },
};

in  vec3 i_view;
out vec4 o_color;

void main() {
    o_color = texture(samplerCube(g_per_scene_textures_cube[g_ps_push_constants.texture_index],
                                  g_per_scene_samplers[g_ps_push_constants.sampler_index]),
                      i_view);
}

#pipeline_state

PrimitiveTopology = TRIANGLE_STRIP;
DepthTestEnable   = true;
DepthWriteEnable  = false;
