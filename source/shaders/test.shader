#include "graphics_bindings.shader_header"

#vertex_shader

layout(push_constant) uniform PushConstants {
    Indices32Ref     indices_ref;
    DefaultVertexRef vertices_ref;
} g_push_constants;

out vec3 o_color;

void main() {
    Indices32Ref     index_ref  = g_push_constants.indices_ref[gl_VertexIndex];
    DefaultVertexRef vertex_ref = g_push_constants.vertices_ref[gl_BaseInstance + index_ref.index];

    f32vec3 position = vertex_ref.position_u.xyz * 0.125;
    position.z = position.z * 0.5 + 0.5;

    gl_Position = vec4(position, 1.0);

    const float alpha = cos(1.5 * g_per_frame_uniform.time) * 0.5 + 0.5;
    o_color = vertex_ref.normal_v.xyz * alpha;
}

#fragment_shader

in  vec3 i_color;
out vec4 o_color;

void main() {
    o_color = vec4(i_color, 1.0);
}

#pipeline_state

FrontFace                = COUNTER_CLOCKWISE;
CullMode                 = BACK_FACE;
DepthTestEnable          = true;
DepthWriteEnable         = true;
DepthCompareOp           = GREATER;
ColorTarget[0].WriteMask = RED | GREEN | BLUE;
