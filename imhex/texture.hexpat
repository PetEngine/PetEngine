import std.mem;
import std.array;

enum Format : u8 {
    UNKNOWN = 0,

    // Uncompressed
    RGBA8_UNORM,
    RGBA8_SRGB,
    BGRA8_UNORM,
    BGRA8_SNORM,
    BGRA8_SRGB,

    // Packed
    RGB10A2_UNORM,

    // Depth/stencil
    D32,
    S8,

    // Compressed
    BC1_UNORM,
    BC1_SRGB,
    BC1_A1_UNORM,
    BC1_A1_SRGB,
    BC2_UNORM,
    BC2_SRGB,
    BC3_UNORM,
    BC3_SRGB,
    BC4_UNORM,
    BC4_SNORM,
    BC5_UNORM,
    BC5_SNORM,
    BC6H_UFLOAT,
    BC6H_SFLOAT,
    BC7_UNORM,
    BC7_SRGB,

    // Planar
};

enum Flags : u8 {
    NONE  = 0,
    ARRAY = 1,
    CUBE  = 2,
};

struct Header {
    u8     version;
    Format format;
    Flags  flags;
    u8     mips_count;
    u16    width;
    u16    height;
    u16    depth_or_array_size;
};

Header header @ $;

const u8  faces_count    = (u8(header.flags) & u8(Flags::CUBE)) ? 6 : 1;
const u16 array_size     = (u8(header.flags) & u8(Flags::ARRAY)) ? header.depth_or_array_size : 1;
const u16 surfaces_count = header.mips_count * array_size * faces_count;

u64 surface_offsets[surfaces_count - 1] @ $;

u16 g_surface_index = 0;
fn getSurfaceSize() {
    u64 size = 0;

    if (surfaces_count == 1) {
        size = std::mem::size() - $;
    } else if (g_surface_index == 0) {
        size = surface_offsets[0] - $;
    } else if (g_surface_index == surfaces_count - 1) {
        size = std::mem::size() - surface_offsets[surfaces_count - 2];
    } else {
        size = surface_offsets[g_surface_index] - surface_offsets[g_surface_index - 1];
    }

    g_surface_index += 1;
    return size;
};

std::Array<u8, getSurfaceSize()> surfaces[surfaces_count] @ $;
