#include "graphics_bindings.shader_header"

#vertex_shader

layout(push_constant) uniform PushConstants {
    Indices32Ref     indices_reference;
    DefaultVertexRef vertices_reference;
} g_push_constants;

out vec3 o_color;

void main() {
    Indices32Ref     index_ref  = subscript(Indices32Ref,     g_push_constants.indices_reference,  gl_VertexIndex);
    DefaultVertexRef vertex_ref = subscript(DefaultVertexRef, g_push_constants.vertices_reference, index_ref.index);

    gl_Position = vec4(vertex_ref.position_u.xyz, 1.0);

    const float alpha = cos(1.5 * g_per_frame_uniform.time) * 0.5 + 0.5;
    o_color = vertex_ref.normal_v.xyz * alpha;
}

#fragment_shader

in  vec3 i_color;
out vec3 o_color;

void main() {
    o_color = i_color;
}

#pipeline_state

// @TODO: #FixViews
DepthTestEnable  = false;
DepthWriteEnable = false;
