struct Vertex {
    vec4 position;
    vec4 color;
};

const Vertex g_Vertices[] = {
    { vec4(-0.5, -0.5, 0.0, 1.0), vec4(1.0, 0.0, 0.0, 1.0) },
    { vec4( 0.0,  0.5, 0.0, 1.0), vec4(0.0, 1.0, 0.0, 1.0) },
    { vec4( 0.5, -0.5, 0.0, 1.0), vec4(0.0, 0.0, 1.0, 1.0) },
};

layout(location = 0) out vec4 o_color;

void main() {
    Vertex vertex = g_Vertices[gl_VertexIndex];
    gl_Position   = vertex.position;
    o_color       = vertex.color;
}
