import std.string;

enum VertexFormat : u8 {
    PNUV  = 0,
    PNTUV = 1,
};

struct Header {
    u8           version;
    VertexFormat vertex_format;
    u16          textures_count;
    u16          materials_count;
    u16          meshes_count;
    u32          vertices_count;
    u32          indices_count;
};

struct TextureName {
    u16  length;
    char data[length];
} [[format_read("std::string::impl::format_string")]];

struct v4f_color {
    float x, y, z, w;
} [[color(std::format("{:02X}{:02X}{:02X}", u32(x*w*255), u32(y*w*255), u32(z*w*255)))]];

struct v3f_color {
    float x, y, z;
} [[color(std::format("{:02X}{:02X}{:02X}", u32(x*255), u32(y*255), u32(z*255)))]];

struct Material {
    v4f_color factor_albedo;
    v3f_color factor_emissive;
    float factor_metallic;
    float factor_roughness;

    u16 texture_index_albedo;
    u16 texture_index_normal;
    u16 texture_index_emissive;
    u16 texture_index_metallic_roughness;
    u16 texture_index_occlusion;
};

struct m3x4 {
    float e00, e01, e02, e03;
    float e10, e11, e12, e13;
    float e20, e21, e22, e23;
};

struct Mesh {
    u32  indices_start;
    u32  indices_count;
    m3x4 mesh_to_model;
    m3x4 model_to_mesh;
    u16 material_index;
};

struct v4f {
    float x, y, z, w;
};

Header header @ $;
TextureName textures[header.textures_count] @ $;
Material materials[header.materials_count] @ $;
Mesh meshes[header.meshes_count] @ $;
