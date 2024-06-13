#include "graphics_bindings.shader_header"

struct VertexOutput {
    vec4 color;
};

#vertex_shader

struct Vertex {
    vec4 position;
    vec4 color;
};

const Vertex g_vertices[] = {
    { { -0.5,  0.5, 0.0, 1.0 }, { 1.0, 0.0, 0.0, 1.0 } },
    { {  0.5,  0.5, 0.0, 1.0 }, { 0.0, 1.0, 0.0, 1.0 } },
    { { -0.5, -0.5, 0.0, 1.0 }, { 0.0, 0.0, 1.0, 1.0 } },
    { {  0.5, -0.5, 0.0, 1.0 }, { 1.0, 1.0, 1.0, 1.0 } },
};

out VertexOutput vs_output;

layout(push_constant) uniform PushConstants {
    uint per_view_uniform_index;
} g_push_constants;

void main() {
    Vertex vertex = g_vertices[gl_VertexIndex];
    gl_Position   = vertex.position;

    const vec3 camera_position = g_per_view_uniforms[g_push_constants.per_view_uniform_index].camera_position;

    const float alpha = cos(1.5 * g_per_frame_uniform.time) * 0.5 + 0.5;
    vs_output.color = vertex.color * vec4(camera_position, 1.0) * alpha;
}

#fragment_shader

in  VertexOutput fs_input;
out vec4         fs_output_color;

void main() {
    fs_output_color = fs_input.color;
}

#pipeline_state

PrimitiveTopology                  = TRIANGLE_STRIP;
FillMode                           = FILL;
CullMode                           = NONE;
FrontFace                          = CLOCKWISE;
DepthBiasEnable                    = false;
DepthBiasConstantFactor            = 0.0;
DepthBiasClamp                     = 0.0;
DepthBiasSlopeFactor               = 0.0;
DepthTestEnable                    = false;
DepthWriteEnable                   = false;
DepthCompareOp                     = ALWAYS;
BlendLogicOpEnable                 = false;
BlendLogicOp                       = COPY;
ColorTarget[0].WriteMask           = RED | GREEN | BLUE;
ColorTarget[0].BlendEnable         = false;
ColorTarget[0].SrcColorBlendFactor = SRC_COLOR;
ColorTarget[0].DstColorBlendFactor = ZERO;
ColorTarget[0].ColorBlendOp        = ADD;
ColorTarget[0].SrcAlphaBlendFactor = SRC_ALPHA;
ColorTarget[0].DstAlphaBlendFactor = ZERO;
ColorTarget[0].AlphaBlendOp        = ADD;
