#include "graphics_bindings.shader_header"

#vertex_shader

#define DISTANCE 50.0

layout(push_constant) uniform PushConstants {
    uint32_t per_view_uniform_index;
} g_push_constants;

out vec2 o_uv;

void main() {
    o_uv = vec2(gl_VertexIndex & 1, gl_VertexIndex >> 1);

    vec4 position;
    position.x = 2.0 * DISTANCE * o_uv.x - DISTANCE;
    position.y = 0.0;
    position.z = DISTANCE - 2.0 * DISTANCE * o_uv.y;
    position.w = 1.0;

    gl_Position = g_per_view_uniforms[g_push_constants.per_view_uniform_index].view_proj_matrix * position;
}

#fragment_shader

in  vec2 i_uv;
out vec4 o_color;

void main() {
    o_color = vec4(i_uv, 0.0, 1.0);
}

#pipeline_state

PrimitiveTopology = TRIANGLE_STRIP;
DepthTestEnable   = true;
DepthWriteEnable  = true;
