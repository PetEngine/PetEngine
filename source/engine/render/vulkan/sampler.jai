VulkanSampler :: struct {
    #as using public_data : Sampler;

    sampler : VkSampler;
}

pushVulkanSampler :: (device_ : *Device, manager_ : *ResourceManager, lifetime : ResourceManager.Lifetime) -> *Sampler #must {
    device  := cast(*VulkanDevice)          device_;
    manager := cast(*VulkanResourceManager) manager_;

    sampler : *VulkanSampler;
    if #complete lifetime == {
        case .PERSISTENT; sampler = pushBack(*manager.samplers.persistent.resources);
        case .PER_SCENE;  sampler = pushBack(*manager.samplers.per_scene.resources);
        case .PER_FRAME;  sampler = pushBack(*manager.samplers.per_frame[device.frame_index].resources);
    }
    return sampler;
}

createVulkanSampler :: (
    device_   : *Device,
    manager_  : *ResourceManager,
    sampler_  : *Sampler,
    state     : *SamplerState,
    name      : string
) {
    device  := cast(*VulkanDevice) device_;
    manager := cast(*VulkanResourceManager) manager_;
    sampler := cast(*VulkanSampler) sampler_;

    create_info := VkSamplerCreateInfo.{
        magFilter        = samplerFilterToVkFilter(state.mag_filter),
        minFilter        = samplerFilterToVkFilter(state.min_filter),
        mipmapMode       = samplerFilterToVkSamplerMipmapMode(state.mip_filter),
        addressModeU     = samplerAddressModeToVkSamplerAddressMode(state.address_mode_u),
        addressModeV     = samplerAddressModeToVkSamplerAddressMode(state.address_mode_v),
        addressModeW     = samplerAddressModeToVkSamplerAddressMode(state.address_mode_w),
        mipLodBias       = state.lod_bias,
        minLod           = cast(f32) state.min_lod,
        maxLod           = ifx state.max_lod == Sampler.MAX_LOD_NONE then VK_LOD_CLAMP_NONE else cast(f32) state.max_lod,
        borderColor      = samplerBorderColorToVkBorderColor(state.border_color),
    };

    if state.anisotropy == {
        case 0;
            create_info.anisotropyEnable = VK_FALSE;
            create_info.maxAnisotropy    = 1.0;

        case Sampler.MAX_ANISOTROPY;
            create_info.anisotropyEnable = VK_TRUE;
            create_info.maxAnisotropy    = device.limits.maxSamplerAnisotropy;

        case;
            create_info.anisotropyEnable = VK_TRUE;
            create_info.maxAnisotropy    = cast(f32) state.anisotropy;

            if create_info.maxAnisotropy > device.limits.maxSamplerAnisotropy {
                warningMessage("Sampler \"%\": anisotropy will be clamped to %. % is too large for this device",
                               name,
                               device.limits.maxSamplerAnisotropy,
                               create_info.maxAnisotropy);
                create_info.maxAnisotropy = device.limits.maxSamplerAnisotropy;
            }
    }

    if state.compare_op == Sampler.CompareOp.OFF {
        create_info.compareEnable = VK_FALSE;
        create_info.compareOp     = .VK_COMPARE_OP_ALWAYS;
    } else {
        create_info.compareEnable = VK_TRUE;
        create_info.compareOp     = samplerCompareOpToVkCompareOp(state.compare_op);
    }

    if create_info.mipLodBias > device.limits.maxSamplerLodBias {
        warningMessage("Sampler \"%\": LOD bias will be clamped to %. % is too large for this device",
                       name,
                       device.limits.maxSamplerLodBias,
                       create_info.mipLodBias);
        create_info.mipLodBias = device.limits.maxSamplerLodBias;
    }

    debugCheckVK(vkCreateSampler(device.device, *create_info, null, *sampler.sampler));

    if #complete sampler.lifetime == {
        case .PERSISTENT; composeVulkanSamplerName(sampler, *manager.samplers.persistent,                    name);
        case .PER_SCENE;  composeVulkanSamplerName(sampler, *manager.samplers.per_scene,                     name);
        case .PER_FRAME;  composeVulkanSamplerName(sampler, *manager.samplers.per_frame[device.frame_index], name);
    }

    setVulkanObjectName(device, sampler.sampler, sampler.name);
}

#scope_file

// "Sampler/<lifetime>/<name>"
composeVulkanSamplerName :: (
    sampler     : *VulkanSampler,
    memory_pool : *VulkanResourceManager.MemorylessPool,
    name        : string
) {
    lifetime_name := Reflection.enum_value_to_name(sampler.lifetime);
    assert(lifetime_name);

    full_name_length := "Sampler/".count
                      + lifetime_name.count + "/".count
                      + name.count;

    assert(full_name_length <= ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH,
           "Sampler full name length (%) > ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH (%)",
           full_name_length,
           ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH);

    sampler.name.data = pushToArena(*memory_pool.names_subarena, full_name_length);

    appendToString(*sampler.name, full_name_length, "Sampler/", lifetime_name, "/", name);
    assert(sampler.name.count == full_name_length);
}

samplerFilterToVkFilter :: inline (filter : Sampler.Filter) -> VkFilter {
    if #complete filter == {
        case .POINT;  return .VK_FILTER_NEAREST;
        case .LIENAR; return .VK_FILTER_LINEAR;
    }
    return .VK_FILTER_NEAREST;
}

samplerFilterToVkSamplerMipmapMode :: inline (filter : Sampler.Filter) -> VkSamplerMipmapMode {
    if #complete filter == {
        case .POINT;  return .VK_SAMPLER_MIPMAP_MODE_NEAREST;
        case .LIENAR; return .VK_SAMPLER_MIPMAP_MODE_LINEAR;
    }
    return .VK_SAMPLER_MIPMAP_MODE_NEAREST;
}

samplerAddressModeToVkSamplerAddressMode :: inline (address_mode : Sampler.AddressMode) -> VkSamplerAddressMode {
    if #complete address_mode == {
        case .CLAMP;  return .VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        case .WRAP;   return .VK_SAMPLER_ADDRESS_MODE_REPEAT;
        case .MIRROR; return .VK_SAMPLER_ADDRESS_MODE_MIRRORED_REPEAT;
        case .BORDER; return .VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER;
    }
    return .VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
}

samplerCompareOpToVkCompareOp :: inline (compare_op : Sampler.CompareOp) -> VkCompareOp {
    if #complete compare_op == {
        case .OFF;              return .VK_COMPARE_OP_ALWAYS;
        case .NEVER;            return .VK_COMPARE_OP_NEVER;
        case .LESS;             return .VK_COMPARE_OP_LESS;
        case .EQUAL;            return .VK_COMPARE_OP_EQUAL;
        case .LESS_OR_EQUAL;    return .VK_COMPARE_OP_LESS_OR_EQUAL;
        case .GREATER;          return .VK_COMPARE_OP_GREATER;
        case .NOT_EQUAL;        return .VK_COMPARE_OP_NOT_EQUAL;
        case .GREATER_OR_EQUAL; return .VK_COMPARE_OP_GREATER_OR_EQUAL;
        case .ALWAYS;           return .VK_COMPARE_OP_ALWAYS;
    }
    return .VK_COMPARE_OP_ALWAYS;
}

samplerBorderColorToVkBorderColor :: inline (border_color : Sampler.BorderColor) -> VkBorderColor {
    if #complete border_color == {
        case .NONE;        return .VK_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK;
        case .TRANSPARENT; return .VK_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK;
        case .BLACK;       return .VK_BORDER_COLOR_FLOAT_OPAQUE_BLACK;
        case .WHITE;       return .VK_BORDER_COLOR_FLOAT_OPAQUE_WHITE;
    }
    return .VK_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK;
}
