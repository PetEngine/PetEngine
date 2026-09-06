VulkanSampler :: struct {
    sampler : VkSampler;
}

createVulkanSampler :: (state : SamplerState, name : string) {
    device  := cast(*VulkanDevice)          context.pet.render.device;
    manager := cast(*VulkanResourceManager) context.pet.render.resource_manager;

    sampler := pushBack(*manager.samplers);

    create_info := VkSamplerCreateInfo.{
        magFilter    = samplerFilterToVkFilter(state.mag_filter),
        minFilter    = samplerFilterToVkFilter(state.min_filter),
        mipmapMode   = samplerFilterToVkSamplerMipmapMode(state.mip_filter),
        addressModeU = samplerAddressModeToVkSamplerAddressMode(state.address_mode_u),
        addressModeV = samplerAddressModeToVkSamplerAddressMode(state.address_mode_v),
        addressModeW = samplerAddressModeToVkSamplerAddressMode(state.address_mode_w),
        mipLodBias   = state.lod_bias,
        minLod       = cast(f32) state.min_lod,
        maxLod       = ifx state.max_lod == SamplerState.MAX_LOD_NONE then VK_LOD_CLAMP_NONE else cast(f32) state.max_lod,
        borderColor  = samplerBorderColorToVkBorderColor(state.border_color),
    };

    if state.anisotropy == {
        case 0;
            create_info.anisotropyEnable = VK_FALSE;
            create_info.maxAnisotropy    = 1.0;

        case SamplerState.MAX_ANISOTROPY;
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

    if state.compare_op == SamplerState.CompareOp.OFF {
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
    setVulkanObjectName(sampler.sampler, "Sampler/%", name);
}

#scope_file

samplerFilterToVkFilter :: inline (filter : SamplerState.Filter) -> VkFilter {
    if #complete filter == {
        case .POINT;  return .VK_FILTER_NEAREST;
        case .LINEAR; return .VK_FILTER_LINEAR;
    }
    return .VK_FILTER_NEAREST;
}

samplerFilterToVkSamplerMipmapMode :: inline (filter : SamplerState.Filter) -> VkSamplerMipmapMode {
    if #complete filter == {
        case .POINT;  return .VK_SAMPLER_MIPMAP_MODE_NEAREST;
        case .LINEAR; return .VK_SAMPLER_MIPMAP_MODE_LINEAR;
    }
    return .VK_SAMPLER_MIPMAP_MODE_NEAREST;
}

samplerAddressModeToVkSamplerAddressMode :: inline (address_mode : SamplerState.AddressMode) -> VkSamplerAddressMode {
    if #complete address_mode == {
        case .CLAMP;  return .VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        case .WRAP;   return .VK_SAMPLER_ADDRESS_MODE_REPEAT;
        case .MIRROR; return .VK_SAMPLER_ADDRESS_MODE_MIRRORED_REPEAT;
        case .BORDER; return .VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER;
    }
    return .VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
}

samplerCompareOpToVkCompareOp :: inline (compare_op : SamplerState.CompareOp) -> VkCompareOp {
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

samplerBorderColorToVkBorderColor :: inline (border_color : SamplerState.BorderColor) -> VkBorderColor {
    if #complete border_color == {
        case .NONE;        return .VK_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK;
        case .TRANSPARENT; return .VK_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK;
        case .BLACK;       return .VK_BORDER_COLOR_FLOAT_OPAQUE_BLACK;
        case .WHITE;       return .VK_BORDER_COLOR_FLOAT_OPAQUE_WHITE;
    }
    return .VK_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK;
}
