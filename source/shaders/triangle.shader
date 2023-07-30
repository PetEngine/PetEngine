struct VertexOutput {
    vec4 color;
};

#vertex_shader

struct Vertex {
    vec4 position;
    vec4 color;
};

const Vertex g_Vertices[] = {
    { { -0.5, -0.5, 0.0, 1.0 }, { 1.0, 0.0, 0.0, 1.0 } },
    { {  0.0,  0.5, 0.0, 1.0 }, { 0.0, 1.0, 0.0, 1.0 } },
    { {  0.5, -0.5, 0.0, 1.0 }, { 0.0, 0.0, 1.0, 1.0 } },
};

out VertexOutput vs_output;

void main() {
    Vertex vertex = g_Vertices[gl_VertexIndex];
    gl_Position   = vertex.position;

    vs_output.color = vertex.color;
}

#fragment_shader

in  VertexOutput fs_input;
out vec4         fs_output_color;

void main() {
    fs_output_color = fs_input.color;
}

#pipeline_state

PrimitiveTopology                  = TRIANGLE_LIST;
FillMode                           = FILL;
CullMode                           = BACK_FACE;
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
ColorTarget[0].WriteMask           = RGB;
ColorTarget[0].BlendEnable         = false;
ColorTarget[0].SrcColorBlendFactor = SRC_COLOR;
ColorTarget[0].DstColorBlendFactor = ZERO;
ColorTarget[0].ColorBlendOp        = ADD;
ColorTarget[0].SrcAlphaBlendFactor = SRC_ALPHA;
ColorTarget[0].DstAlphaBlendFactor = ZERO;
ColorTarget[0].AlphaBlendOp        = ADD;
