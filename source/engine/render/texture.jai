TextureManager :: struct {
}

Texture :: struct {
    // @TODO: #Math. Make it vector
    ClearValue :: union {
        f32_ : [4] f32;
        u32_ : [4] u32;
    };
}

#scope_file

#load "../platform/vulkan/texture.jai";
