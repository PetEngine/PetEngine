VulkanTextureView :: struct {
    #as using public_data : TextureView;

    view : VkImageView;
}

pushVulkanTextureView :: (device : *Device, manager_ : *ResourceManager, lifetime : ResourceManager.Lifetime) -> *TextureView #must {
    manager := cast(*VulkanResourceManager) manager_;

    view : *VulkanTextureView;
    if #complete lifetime == {
        case .PERSISTENT; view = pushBack(*manager.texture_views.persistent.resources);
        case .PER_SCENE;  view = pushBack(*manager.texture_views.per_scene.resources);
        case .PER_FRAME;  view = pushBack(*manager.texture_views.per_frame[device.frame_index].resources);
    }
    return view;
}

createVulkanTextureView :: (
    device   : *Device,
    manager_ : *ResourceManager,
    view     : *TextureView,
    name     : string
) {
    manager := cast(*VulkanResourceManager) manager_;

    if #complete view.lifetime == {
        case .PERSISTENT; composeVulkanTextureViewName(view, *manager.texture_views.persistent,                    name);
        case .PER_SCENE;  composeVulkanTextureViewName(view, *manager.texture_views.per_scene,                     name);
        case .PER_FRAME;  composeVulkanTextureViewName(view, *manager.texture_views.per_frame[device.frame_index], name);
    }
}

#scope_file

// "Texture View/<lifetime>/<name>"
composeVulkanTextureViewName :: (
    view        : *TextureView,
    memory_pool : *VulkanResourceManager.MemorylessPool,
    name        : string
) {
    lifetime_name := Reflection.enum_value_to_name(view.lifetime);
    assert(lifetime_name);

    full_name_length := "Texture View/".count
                      + lifetime_name.count + "/".count
                      + name.count;

    assert(full_name_length <= ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH,
           "Texture view full name length (%) > ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH (%)",
           full_name_length,
           ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH);

    view.name.data = pushToArena(*memory_pool.names_subarena, full_name_length);

    appendToString(*view.name, full_name_length, "Texture View/", lifetime_name, "/", name);
    assert(view.name.count == full_name_length);
}
