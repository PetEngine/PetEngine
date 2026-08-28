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
    Indices32Ref indices_ref;
    PNTUVRef     vertices_ref;
    MeshRef      meshes_ref;
    MaterialRef  materials_ref;
    uint32_t     per_view_uniform_index;
    uint16_t     sampler_index;
    uint16_t     first_texture_index;
} g_push_constants;

#vertex_shader

     out vec3 o_position;
     out vec3 o_tangent;
     out vec3 o_normal;
     out vec3 o_bitangent;
     out vec2 o_uv;
flat out uint o_material_index;

void main() {
    Indices32Ref index_ref  = g_push_constants.indices_ref[gl_VertexIndex];
    PNTUVRef     vertex_ref = g_push_constants.vertices_ref[index_ref.index];
    MeshRef      mesh_ref   = g_push_constants.meshes_ref[gl_BaseInstance];

    const vec3 ws_position = mesh_ref.mesh_to_model * vec4(vertex_ref.position_u.xyz, 1.0);
    const vec3 bitangent   = cross(vertex_ref.normal_v.xyz, vertex_ref.tangent.xyz) * vertex_ref.tangent.w;

    const mat3x3 normal_matrix = transpose(mat3x3(mesh_ref.model_to_mesh));

    gl_Position      = g_per_view_uniforms[g_push_constants.per_view_uniform_index].view_proj_matrix * vec4(ws_position, 1.0);
    o_position       = ws_position;
    o_tangent        = normalize(mat3x3(mesh_ref.mesh_to_model) * vertex_ref.tangent.xyz);
    o_normal         = normalize(normal_matrix * vertex_ref.normal_v.xyz);
    o_bitangent      = normalize(mat3x3(mesh_ref.mesh_to_model) * bitangent);
    o_uv             = vec2(vertex_ref.position_u.w, vertex_ref.normal_v.w);
    o_material_index = mesh_ref.material_index;
}

#fragment_shader

#include "pbr.shader_header"

const vec3 SUN_DIR   = vec3(0, -1, 0);
const vec3 SUN_COLOR = vec3(1,  1, 1) * 5;

const vec3 DOWN  = vec3(0.59766, 0.51953, 0.43359);
const vec3 UP    = vec3(0.00854, 0.02026, 0.04224);

const float INV_WHITE_POINT = 1.3790642466494378; // 1.0 / toneMappingUncharted2(11.2);

     in vec3 i_position;
     in vec3 i_tangent;
     in vec3 i_normal;
     in vec3 i_bitangent;
     in vec2 i_uv;
flat in uint i_material_index;

out vec4 o_color;

void main() {
    MaterialRef material_ref = g_push_constants.materials_ref[i_material_index];

    // @TODO: #GLTF. alphaMode
    vec3 albedo = material_ref.factor_albedo.rgb;
    if (material_ref.texture_index_albedo != 0xFFFF)
    {
        // https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#_material_pbrmetallicroughness_basecolortexture
        const vec3 s = texture(sampler2D(g_per_scene_textures_2d[g_push_constants.first_texture_index + material_ref.texture_index_albedo],
                                         g_per_scene_samplers[g_push_constants.sampler_index]),
                               i_uv).rgb;
        albedo *= s;
    }

    float roughness = material_ref.factor_roughness;
    float metalness = material_ref.factor_metallic;
    if (material_ref.texture_index_metallic_roughness != 0xFFFF)
    {
        // https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#_material_pbrmetallicroughness_metallicroughnesstexture
        const vec2 s = texture(sampler2D(g_per_scene_textures_2d[g_push_constants.first_texture_index + material_ref.texture_index_metallic_roughness],
                                         g_per_scene_samplers[g_push_constants.sampler_index]),
                               i_uv).gb;

        roughness *= s.x;
        metalness *= s.y;
    }

    vec3 emissive = material_ref.factor_emissive;
    if (material_ref.texture_index_emissive != 0xFFFF)
    {
        // https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#_material_emissivetexture
        const vec3 s = texture(sampler2D(g_per_scene_textures_2d[g_push_constants.first_texture_index + material_ref.texture_index_emissive],
                                         g_per_scene_samplers[g_push_constants.sampler_index]),
                               i_uv).rgb;
        emissive *= s;
    }

    vec3 N = normalize(i_normal);
    if (material_ref.texture_index_normal != 0xFFFF)
    {
        // https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#_material_normaltexture
        vec3 s = texture(sampler2D(g_per_scene_textures_2d[g_push_constants.first_texture_index + material_ref.texture_index_normal],
                                   g_per_scene_samplers[g_push_constants.sampler_index]),
                         i_uv).xyz;
        s = s * 2.0 - 1.0;
        s = normalize(s);

        const vec3 T = normalize(i_tangent);
        const vec3 B = normalize(i_bitangent);

        N = mat3x3(T, B, N) * s;
        N = normalize(N);
    }

    float occlusion = 1.0;
    if (material_ref.texture_index_occlusion != 0xFFFF)
    {
        // https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#_material_occlusiontexture
        const float s = texture(sampler2D(g_per_scene_textures_2d[g_push_constants.first_texture_index + material_ref.texture_index_occlusion],
                                          g_per_scene_samplers[g_push_constants.sampler_index]),
                                i_uv).r;
        occlusion = s;
    }

    const vec3 L = -SUN_DIR;
    const vec3 V = normalize(g_per_view_uniforms[g_push_constants.per_view_uniform_index].camera_position - i_position);

    const vec3 direct   = calculateBRDF(L, V, N, albedo, roughness, metalness) * SUN_COLOR;
    const vec3 indirect = lerp(DOWN, UP, N.y * 0.5 + 0.5) * albedo * (1.0 - metalness);

    const float shadow = 1.0;

    vec3 result = direct * shadow;
    result += indirect * occlusion;
    result += emissive;

    o_color = vec4(toneMappingUncharted2(result) * INV_WHITE_POINT, 1.0);
}

#pipeline_state

FrontFace        = COUNTER_CLOCKWISE;
// CullMode      = BACK_FACE; // @TODO: #GLTF. doubleSided
DepthTestEnable  = true;
DepthWriteEnable = true;
