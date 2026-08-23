#include "graphics_bindings.shader_header"

layout(buffer_reference, buffer_reference_align = 4) readonly buffer MeshRef {
    mat4x3   model_to_mesh;
    mat4x3   mesh_to_model;
    uint16_t material_index;
};

layout(buffer_reference, buffer_reference_align = 4) readonly buffer MaterialRef {
    f32vec4 factor_albedo;
    f32vec3 factor_emissive;
    float   factor_metallic;
    float   factor_roughness;

    uint16_t texture_index_albedo;
    uint16_t texture_index_normal;
    uint16_t texture_index_emissive;
    uint16_t texture_index_metallic_roughness;
    uint16_t texture_index_occlusion;
};

layout(push_constant) uniform PushConstants {
    Indices32Ref     indices_ref;
    DefaultVertexRef vertices_ref;
    MeshRef          meshes_ref;
    MaterialRef      materials_ref;
    uint32_t         per_view_uniform_index;
} g_push_constants;

#vertex_shader

     out vec3 o_position;
     out vec3 o_normal;
flat out uint o_material_index;

void main() {
    Indices32Ref     index_ref  = g_push_constants.indices_ref[gl_VertexIndex];
    DefaultVertexRef vertex_ref = g_push_constants.vertices_ref[index_ref.index];
    MeshRef          mesh_ref   = g_push_constants.meshes_ref[gl_BaseInstance];

    const f32vec3 ws_position = mesh_ref.mesh_to_model * f32vec4(vertex_ref.position_u.xyz, 1.0);
    const f32vec3 ws_normal   = normalize(mesh_ref.mesh_to_model * f32vec4(vertex_ref.normal_v.xyz, 0.0));

    gl_Position      = g_per_view_uniforms[g_push_constants.per_view_uniform_index].view_proj_matrix * f32vec4(ws_position, 1.0);
    o_position       = ws_position;
    o_normal         = ws_normal;
    o_material_index = mesh_ref.material_index;
}

#fragment_shader

     in vec3 i_position;
     in vec3 i_normal;
flat in uint i_material_index;

out vec4 o_color;

void main() {
    const vec3 N = normalize(i_normal);
    o_color = vec4(N * 0.5 + 0.5, 1.0);
}

#pipeline_state

FrontFace        = COUNTER_CLOCKWISE;
// CullMode      = BACK_FACE; // @TODO: #GLTF. doubleSided
DepthTestEnable  = true;
DepthWriteEnable = true;
