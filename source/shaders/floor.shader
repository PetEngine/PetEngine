#include "graphics_bindings.shader_header"

#vertex_shader

struct Vertex {
    vec3 position;
    vec3 color;
};

#define DISTANCE 50.0

const Vertex g_vertices[] = {
    { { -DISTANCE, 0.0,  DISTANCE }, { 1.0, 0.0, 0.0 } },
    { {  DISTANCE, 0.0,  DISTANCE }, { 0.0, 1.0, 0.0 } },
    { { -DISTANCE, 0.0, -DISTANCE }, { 1.0, 0.0, 1.0 } },
    { {  DISTANCE, 0.0, -DISTANCE }, { 0.0, 0.0, 1.0 } },
};

layout(push_constant) uniform PushConstants {
    uint32_t per_view_uniform_index;
} g_push_constants;

out vec3 o_color;

void main() {
    const Vertex vertex = g_vertices[gl_VertexIndex];

    gl_Position = g_per_view_uniforms[g_push_constants.per_view_uniform_index].view_proj_matrix * vec4(vertex.position, 1.0);
    o_color     = vertex.color;
}

#fragment_shader

in  vec3 i_color;
out vec4 o_color;

void main() {
    o_color = vec4(i_color, 1.0);
}

#pipeline_state

PrimitiveTopology = TRIANGLE_STRIP;
DepthTestEnable   = true;
DepthWriteEnable  = true;
