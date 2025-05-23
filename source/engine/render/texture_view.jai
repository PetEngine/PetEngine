TextureView :: struct {
    ALL_LAYERS : u16 : 0xFFFF;

    texture      : *Texture;
    dimension    : Texture.Dimension;
    flags        : Texture.Flags;
    format       : Texture.Format;
    usage        : Texture.Usage; // Only 1 usage at a time is allowed
    first_layer  : u16;
    layers_count : u16;
    first_mip    : u8;
    mips_count   : u8;
    lifetime     : ResourceManager.Lifetime;
    name         : string;
}

createTextureView :: inline (
    texture      : *Texture,
    usage        : Texture.Usage,
    first_mip    : u8  = 0,
    mips_count   : u8  = Texture.ALL_MIPS,
    first_layer  : u16 = 0,
    layers_count : u16 = TextureView.ALL_LAYERS,
    lifetime     : ResourceManager.Lifetime
) -> *TextureView #must {
    flags := texture.flags & ~.SWAPCHAIN;
    if layers_count <= 1 then flags &= ~.ARRAY;

    return createTextureView(texture,
                             texture.dimension,
                             flags,
                             texture.format,
                             usage,
                             first_mip,
                             mips_count,
                             first_layer,
                             layers_count,
                             lifetime);
}

createTextureView :: (
    texture      : *Texture,
    dimension    : Texture.Dimension,
    flags        : Texture.Flags,
    format       : Texture.Format,
    usage        : Texture.Usage,
    first_mip    : u8  = 0,
    mips_count   : u8  = Texture.ALL_MIPS,
    first_layer  : u16 = 0,
    layers_count : u16 = TextureView.ALL_LAYERS,
    lifetime     : ResourceManager.Lifetime
) -> *TextureView #must {
    assert(!resourceMemoryCommitted(lifetime), "You cannot create %1 texture view after %1 memory is committed", lifetime);

    assert(dimension != ._1D || texture.dimension == ._1D,
           "1D texture view can be created only to a 1D texture");
    assert(dimension != ._2D || texture.dimension == ._2D || texture.dimension == ._3D,
           "2D texture view can be created only to a 2D or 3D texture");
    assert(dimension != ._3D || texture.dimension == ._3D,
           "3D texture view can be created only to a 3D texture");

    assert(!(flags & .SWAPCHAIN),
           "You cannot set SWAPCHAIN flag to a texture view");
    assert(!(flags & .CUBE) || (texture.flags & .CUBE),
           "You can create a cube view only to a cube texture");
    assert(!(flags & .ARRAY) || (texture.flags & .ARRAY) || (texture.dimension == ._3D),
           "You can create an array view only to a texture array or to a 3D texture");

    assert(format == texture.format,
           "For now compatible formats are not supported, so view format should be equal to texture format");

    assert(texture.usages & usage,
           "Texture \"%\" does not have % usage, so you cannot create a view to this texture with such usage",
           texture.name,
           usage);

    assert(first_mip < texture.mips_count);
    assert(ifx flags & .ARRAY then first_layer < texture.array_size else first_layer == 0);

    if mips_count   == Texture.ALL_MIPS       then mips_count   = texture.mips_count - first_mip;
    if layers_count == TextureView.ALL_LAYERS then layers_count = texture.array_size - first_layer;

    assert(first_mip + mips_count <= texture.mips_count);
    assert(ifx flags & .ARRAY then first_layer + layers_count <= texture.array_size else layers_count <= 1);

    manager := context.pet.render.resource_manager;

    view := manager.pushPlatformTextureView(lifetime);

    view.texture      = texture;
    view.dimension    = dimension;
    view.flags        = flags;
    view.format       = format;
    view.usage        = usage;
    view.first_layer  = first_layer;
    view.layers_count = layers_count;
    view.first_mip    = first_mip;
    view.mips_count   = mips_count;
    view.lifetime     = lifetime;

    last_slash_index := String.find_index_from_right(texture.name, #char "/");
    assert(last_slash_index != -1);

    name := substring(texture.name, last_slash_index + 1);

    manager.createPlatformTextureView(view, name);

    return view;
}
