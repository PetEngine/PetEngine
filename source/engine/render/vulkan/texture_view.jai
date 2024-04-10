VulkanTextureView :: struct {
    #as using public_data : TextureView;

    view : VkImageView;
}

pushVulkanTextureView :: (device_ : *Device, manager_ : *ResourceManager, lifetime : ResourceManager.Lifetime) -> *TextureView #must {
    device  := cast(*VulkanDevice)          device_;
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
    device_  : *Device,
    manager_ : *ResourceManager,
    view_    : *TextureView,
    lifetime : ResourceManager.Lifetime,
    name     : string
) {
    device  := cast(*VulkanDevice)          device_;
    manager := cast(*VulkanResourceManager) manager_;
    view    := cast(*VulkanTextureView)     view_;
    texture := cast(*VulkanTexture)         view_.texture;

    usage_info := VkImageViewUsageCreateInfo.{
        usage = textureUsageToVulkanUsageFlags(view.usage, false)
    };

    create_info := VkImageViewCreateInfo.{
        pNext            = *usage_info,
        flags            = 0,
        image            = texture.image,
        format           = textureFormatToVulkanFormat(view.format),
        components       = .{
            r = .VK_COMPONENT_SWIZZLE_R,
            g = .VK_COMPONENT_SWIZZLE_G,
            b = .VK_COMPONENT_SWIZZLE_B,
            a = .VK_COMPONENT_SWIZZLE_A,
        },
        subresourceRange = .{
            aspectMask     = getVulkanImageAspectFlags(view.format),
            baseMipLevel   = view.first_mip,
            levelCount     = view.mips_count,
            baseArrayLayer = view.first_layer,
            layerCount     = max(view.layers_count, 1),
        },
    };

    if view.flags & .ARRAY {
        if view.dimension == {
            case ._1D;
                create_info.viewType = .VK_IMAGE_VIEW_TYPE_1D_ARRAY;
            case ._2D;
                create_info.viewType = ifx  view.flags & .CUBE
                                       then .VK_IMAGE_VIEW_TYPE_CUBE_ARRAY
                                       else .VK_IMAGE_VIEW_TYPE_2D_ARRAY;
        }
    } else {
        if #complete view.dimension == {
            case ._1D;
                create_info.viewType = .VK_IMAGE_VIEW_TYPE_1D;
            case ._2D;
                create_info.viewType = ifx  view.flags & .CUBE
                                       then .VK_IMAGE_VIEW_TYPE_CUBE
                                       else .VK_IMAGE_VIEW_TYPE_2D;
            case ._3D;
                create_info.viewType = .VK_IMAGE_VIEW_TYPE_3D;
        }
    }

    debugCheckVK(vkCreateImageView(device.device, *create_info, null, *view.view));

    if #complete lifetime == {
        case .PERSISTENT; composeVulkanTextureViewName(view, *manager.texture_views.persistent,                    lifetime, name);
        case .PER_SCENE;  composeVulkanTextureViewName(view, *manager.texture_views.per_scene,                     lifetime, name);
        case .PER_FRAME;  composeVulkanTextureViewName(view, *manager.texture_views.per_frame[device.frame_index], lifetime, name);
    }

    setVulkanObjectName(device, view.view, "% view", view.name);
}

#scope_file

// "Texture View/<lifetime>/<name>"
composeVulkanTextureViewName :: (
    view        : *TextureView,
    memory_pool : *VulkanResourceManager.MemorylessPool,
    lifetime    : ResourceManager.Lifetime,
    name        : string
) {
    lifetime_name := Reflection.enum_value_to_name(lifetime);
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
