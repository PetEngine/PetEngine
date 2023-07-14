struct VertexOutput {
    vec4 color;
};

#vertex_shader

struct Vertex {
    vec4 position;
    vec4 color;
};

const Vertex g_Vertices[] = {
    { vec4(-0.5, -0.5, 0.0, 1.0), vec4(1.0, 0.0, 0.0, 1.0) },
    { vec4( 0.0,  0.5, 0.0, 1.0), vec4(0.0, 1.0, 0.0, 1.0) },
    { vec4( 0.5, -0.5, 0.0, 1.0), vec4(0.0, 0.0, 1.0, 1.0) },
};

out VertexOutput output;

void main() {
    Vertex vertex = g_Vertices[gl_VertexIndex];
    gl_Position   = vertex.position;

    output.color = vertex.color;
}

#fragment_shader

struct FragmentOutput {
    vec4 color;
};

in  VertexOutput   input;
out FragmentOutput output;

void main() {
    output.color = input.color;
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
ColorTarget[0].WriteMask           = RGBA;
ColorTarget[0].BlendEnable         = false;
ColorTarget[0].SrcColorBlendFactor = SRC_COLOR;
ColorTarget[0].DstColorBlendFactor = ZERO;
ColorTarget[0].ColorBlendOp        = ADD;
ColorTarget[0].SrcAlphaBlendFactor = SRC_ALPHA;
ColorTarget[0].DstAlphaBlendFactor = ZERO;
ColorTarget[0].AlphaBlendOp        = ADD;
