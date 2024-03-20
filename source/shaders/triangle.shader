struct VertexOutput {
    vec4 color;
};

#vertex_shader

struct Vertex {
    vec4 position;
    vec4 color;
};

const Vertex g_Vertices[] = {
    { { -0.5,  0.5, 0.0, 1.0 }, { 1.0, 0.0, 0.0, 1.0 } },
    { {  0.5,  0.5, 0.0, 1.0 }, { 0.0, 1.0, 0.0, 1.0 } },
    { { -0.5, -0.5, 0.0, 1.0 }, { 0.0, 0.0, 1.0, 1.0 } },
    { {  0.5, -0.5, 0.0, 1.0 }, { 1.0, 1.0, 1.0, 1.0 } },
};

out VertexOutput vs_output;

layout(push_constant) uniform PushConstants {
    float time;
};

void main() {
    Vertex vertex = g_Vertices[gl_VertexIndex];
    gl_Position   = vertex.position;

    const float alpha = cos(1.5 * time) * 0.5 + 0.5;
    vs_output.color = vertex.color * alpha;
}

#fragment_shader

uniform PerView {
    vec3 camera_pos;

    mat3x4 view_matrix;
    mat3x4 inv_view_matrix;

    mat4x4 proj_matrix;
    mat4x4 inv_proj_matrix;

    mat4x4 view_proj_matrix;
    mat4x4 inv_view_proj_matrix;
};

in  VertexOutput fs_input;
out vec4         fs_output_color;

void main() {
    fs_output_color = fs_input.color + vec4(camera_pos, 0.0);
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
