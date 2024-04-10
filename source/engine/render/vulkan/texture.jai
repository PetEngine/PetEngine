VulkanTexture :: struct {
    #as using public_data : Texture;

    image          : VkImage;
    current_layout : VkImageLayout; // @TODO: Rename to just layout
}

pushVulkanTexture :: (device_ : *Device, manager_ : *ResourceManager, lifetime : ResourceManager.Lifetime) -> *Texture #must {
    device  := cast(*VulkanDevice)          device_;
    manager := cast(*VulkanResourceManager) manager_;

    texture : *VulkanTexture;
    if #complete lifetime == {
        case .PERSISTENT; texture = pushBack(*manager.textures.persistent.resources);
        case .PER_SCENE;  texture = pushBack(*manager.textures.per_scene.resources);
        case .PER_FRAME;  texture = pushBack(*manager.textures.per_frame[device.frame_index].resources);
    }
    return texture;
}

createVulkanTexture :: (
    device_  : *Device,
    manager_ : *ResourceManager,
    texture_ : *Texture,
    lifetime : ResourceManager.Lifetime,
    name     : string
) {
    device  := cast(*VulkanDevice)          device_;
    manager := cast(*VulkanResourceManager) manager_;
    texture := cast(*VulkanTexture)         texture_;

    texture.current_layout = .VK_IMAGE_LAYOUT_UNDEFINED;

    queue_family_indices : [Texture.possible_owners.capacity] u32;
    for texture.possible_owners {
        queue_family_indices[it_index] = device.queues[it].family_index;
    }

    create_info := VkImageCreateInfo.{
        format                = textureFormatToVulkanFormat(texture.format),
        mipLevels             = texture.mips_count,
        arrayLayers           = 1,
        samples               = samplesCountToVulkanSampleCountFlags(texture.samples_count),
        tiling                = .VK_IMAGE_TILING_OPTIMAL,
        usage                 = textureUsageToVulkanUsageFlags(texture.usages, true),
        queueFamilyIndexCount = cast(u32) texture.possible_owners.count,
        pQueueFamilyIndices   = queue_family_indices.data,
        initialLayout         = .VK_IMAGE_LAYOUT_UNDEFINED // initialLayout must be VK_IMAGE_LAYOUT_UNDEFINED or VK_IMAGE_LAYOUT_PREINITIALIZED
        // Everything else will be set up later
    };

    if texture.flags & .ARRAY {
        create_info.arrayLayers = texture.array_size;
    }

    if #complete texture.dimension == {
        case ._1D;
            create_info.imageType     = .VK_IMAGE_TYPE_1D;
            create_info.extent.width  = texture.width;
            create_info.extent.height = 1;
            create_info.extent.depth  = 1;

        case ._2D;
            create_info.imageType     = .VK_IMAGE_TYPE_2D;
            create_info.extent.width  = texture.width;
            create_info.extent.height = texture.height;
            create_info.extent.depth  = 1;

        case ._3D;
            create_info.imageType     = .VK_IMAGE_TYPE_3D;
            create_info.extent.width  = texture.width;
            create_info.extent.height = texture.height;
            create_info.extent.depth  = texture.depth;
    }

    if texture.flags & .CUBE {
        create_info.flags       |= .VK_IMAGE_CREATE_CUBE_COMPATIBLE_BIT;
        create_info.arrayLayers *= 6;
    }

    if texture.possible_owners.count > 1 {
        create_info.sharingMode = .VK_SHARING_MODE_CONCURRENT;
    } else {
        create_info.sharingMode = .VK_SHARING_MODE_EXCLUSIVE;
    }

    checkCreateInfoLimits(device, *create_info, textureFormatFlags(texture.format));
    checkImageProperties(device, texture, *create_info);

    debugCheckVK(vkCreateImage(device.device, *create_info, null, *texture.image));

    if #complete lifetime == {
        case .PERSISTENT; composeVulkanTextureName(texture, *manager.textures.persistent,                    lifetime, name);
        case .PER_SCENE;  composeVulkanTextureName(texture, *manager.textures.per_scene,                     lifetime, name);
        case .PER_FRAME;  composeVulkanTextureName(texture, *manager.textures.per_frame[device.frame_index], lifetime, name);
    }

    setVulkanObjectName(device, texture.image, texture.name);
}

textureFormatToVulkanFormat :: inline (format : Texture.Format) -> VkFormat #no_context {
    if #complete format == {
        case .UNKNOWN;       return .VK_FORMAT_UNDEFINED;
        case .BGRA8_UNORM;   return .VK_FORMAT_B8G8R8A8_UNORM;
        case .BGRA8_SNORM;   return .VK_FORMAT_B8G8R8A8_SNORM;
        case .BGRA8_SRGB;    return .VK_FORMAT_B8G8R8A8_SRGB;
        case .RGB10A2_UNORM; return .VK_FORMAT_A2B10G10R10_UNORM_PACK32;
        case .D32;           return .VK_FORMAT_D32_SFLOAT;
        case .S8;            return .VK_FORMAT_S8_UINT;
        case .BC7_UNORM;     return .VK_FORMAT_BC7_UNORM_BLOCK;
        case .BC7_SRGB;      return .VK_FORMAT_BC7_SRGB_BLOCK;
    }
    return .VK_FORMAT_UNDEFINED;
}

vulkanFormatToTextureFormat :: inline (format : VkFormat) -> Texture.Format #no_context {
    if #complete format == {
        case .VK_FORMAT_UNDEFINED;                return .UNKNOWN;
        case .VK_FORMAT_B8G8R8A8_UNORM;           return .BGRA8_UNORM;
        case .VK_FORMAT_B8G8R8A8_SNORM;           return .BGRA8_SNORM;
        case .VK_FORMAT_B8G8R8A8_SRGB;            return .BGRA8_SRGB;
        case .VK_FORMAT_A2B10G10R10_UNORM_PACK32; return .RGB10A2_UNORM;
        case .VK_FORMAT_D32_SFLOAT;               return .D32;
        case .VK_FORMAT_S8_UINT;                  return .S8;
        case .VK_FORMAT_BC7_UNORM_BLOCK;          return .BC7_UNORM;
        case .VK_FORMAT_BC7_SRGB_BLOCK;           return .BC7_SRGB;
    }
    return .UNKNOWN;
}

textureUsageToVulkanUsageFlags :: inline (usage : Texture.Usage, $apply_transfer_flags : bool) -> VkImageUsageFlags #no_context {
    usage_flags : VkImageUsageFlags;

    #if apply_transfer_flags {
        usage_flags |= .VK_IMAGE_USAGE_TRANSFER_SRC_BIT
                    |  .VK_IMAGE_USAGE_TRANSFER_DST_BIT;
    }

    if usage & .SHADER_READ  then usage_flags |= .VK_IMAGE_USAGE_SAMPLED_BIT;
    if usage & .SHADER_WRITE then usage_flags |= .VK_IMAGE_USAGE_STORAGE_BIT;
    if usage & .COLOR_TARGET then usage_flags |= .VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
    if usage & .DEPTH_TARGET then usage_flags |= .VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT;

    return usage_flags;
}

samplesCountToVulkanSampleCountFlags :: inline (samples_count : u8) -> VkSampleCountFlags #no_context {
    if samples_count == {
        case  1; return .VK_SAMPLE_COUNT_1_BIT;
        case  2; return .VK_SAMPLE_COUNT_2_BIT;
        case  4; return .VK_SAMPLE_COUNT_4_BIT;
        case  8; return .VK_SAMPLE_COUNT_8_BIT;
        case 16; return .VK_SAMPLE_COUNT_16_BIT;
        case 32; return .VK_SAMPLE_COUNT_32_BIT;
        case 64; return .VK_SAMPLE_COUNT_64_BIT;
    }
    return .VK_SAMPLE_COUNT_1_BIT;
}

getVulkanImageAspectFlags :: inline (format : Texture.Format) -> VkImageAspectFlags #no_context {
    if #complete format == {
        case .UNKNOWN;
            return .VK_IMAGE_ASPECT_NONE;
        case .BGRA8_UNORM;   #through;
        case .BGRA8_SNORM;   #through;
        case .BGRA8_SRGB;    #through;
        case .RGB10A2_UNORM; #through;
        case .BC7_UNORM;     #through;
        case .BC7_SRGB;
            return .VK_IMAGE_ASPECT_COLOR_BIT;
        case .D32;
            return .VK_IMAGE_ASPECT_DEPTH_BIT;
        case .S8;
            return .VK_IMAGE_ASPECT_STENCIL_BIT;
    }
    return .VK_IMAGE_ASPECT_NONE;
}

#scope_file

checkCreateInfoLimits :: (device : *VulkanDevice, create_info : *VkImageCreateInfo, format_flags : Texture.FormatFlags) {
    if #complete create_info.imageType == {
        case .VK_IMAGE_TYPE_1D;
            if create_info.extent.width > device.limits.maxImageDimension1D {
                assertMessage("Device limits do not allow such a huge width for 1D textures. Requested: %, allowed: %",
                              create_info.extent.width,
                              device.limits.maxImageDimension1D);
            }

        case .VK_IMAGE_TYPE_2D;
            if create_info.flags & .VK_IMAGE_CREATE_CUBE_COMPATIBLE_BIT {
                if create_info.extent.width > device.limits.maxImageDimensionCube {
                    assertMessage("Device limits do not allow such a huge width for cube textures. Requested: %, allowed: %",
                                  create_info.extent.width,
                                  device.limits.maxImageDimensionCube);
                } else if create_info.extent.height > device.limits.maxImageDimensionCube {
                    assertMessage("Device limits do not allow such a huge height for cube textures. Requested: %, allowed: %",
                                  create_info.extent.height,
                                  device.limits.maxImageDimensionCube);
                }
            } else {
                if create_info.extent.width > device.limits.maxImageDimension2D {
                    assertMessage("Device limits do not allow such a huge width for 2D textures. Requested: %, allowed: %",
                                  create_info.extent.width,
                                  device.limits.maxImageDimension2D);
                } else if create_info.extent.height > device.limits.maxImageDimension2D {
                    assertMessage("Device limits do not allow such a huge height for 2D textures. Requested: %, allowed: %",
                                  create_info.extent.height,
                                  device.limits.maxImageDimension2D);
                }
            }

        case .VK_IMAGE_TYPE_3D;
            if create_info.extent.width > device.limits.maxImageDimension3D {
                assertMessage("Device limits do not allow such a huge width for 3D textures. Requested: %, allowed: %",
                              create_info.extent.width,
                              device.limits.maxImageDimension3D);
            } else if create_info.extent.height > device.limits.maxImageDimension3D {
                assertMessage("Device limits do not allow such a huge height for 3D textures. Requested: %, allowed: %",
                              create_info.extent.height,
                              device.limits.maxImageDimension3D);
            } else if create_info.extent.depth > device.limits.maxImageDimension3D {
                assertMessage("Device limits do not allow such a huge depth for 3D textures. Requested: %, allowed: %",
                              create_info.extent.depth,
                              device.limits.maxImageDimension3D);
            }
    }

    if create_info.arrayLayers > device.limits.maxImageArrayLayers {
        assertMessage("Device limits do not allow such a huge number of array layers for textures. Requested: %, allowed: %",
                      create_info.arrayLayers,
                      device.limits.maxImageArrayLayers);
    }

    {
        if create_info.usage & .VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT {
            if (format_flags & .INTEGER) && !(create_info.samples & device.properties12.framebufferIntegerColorSampleCounts) {
                assertMessage("Device limits do not allow that number of samples for textures with integer format and color target usage. Requested: %, allowed: %",
                              create_info.samples,
                              device.properties12.framebufferIntegerColorSampleCounts);
            } else if !(create_info.samples & device.limits.framebufferColorSampleCounts) {
                assertMessage("Device limits do not allow that number of samples for textures with color target usage. Requested: %, allowed: %",
                              create_info.samples,
                              device.limits.framebufferColorSampleCounts);
            }
        }

        if create_info.usage & .VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT {
            if (format_flags & .DEPTH) && !(create_info.samples & device.limits.framebufferDepthSampleCounts) {
                assertMessage("Device limits do not allow that number of samples for textures with depth target usage. Requested: %, allowed: %",
                              create_info.samples,
                              device.limits.framebufferDepthSampleCounts);
            }

            if (format_flags & .STENCIL) && !(create_info.samples & device.limits.framebufferStencilSampleCounts) {
                assertMessage("Device limits do not allow that number of samples for textures with stencil format and depth target usage. Requested: %, allowed: %",
                              create_info.samples,
                              device.limits.framebufferStencilSampleCounts);
            }
        }

        if create_info.usage & .VK_IMAGE_USAGE_SAMPLED_BIT {
            if (format_flags & .COLOR) && !(create_info.samples & device.limits.sampledImageColorSampleCounts) {
                assertMessage("Device limits do not allow that number of samples for textures with color format and shader read usage. Requested: %, allowed: %",
                              create_info.samples,
                              device.limits.sampledImageColorSampleCounts);
            } else if (format_flags & .DEPTH) && !(create_info.samples & device.limits.sampledImageDepthSampleCounts) {
                assertMessage("Device limits do not allow that number of samples for textures with depth format and shader read usage. Requested: %, allowed: %",
                              create_info.samples,
                              device.limits.sampledImageDepthSampleCounts);
            }

            if (format_flags & .INTEGER) && !(create_info.samples & device.limits.sampledImageIntegerSampleCounts) {
                assertMessage("Device limits do not allow that number of samples for textures with integer format and shader read usage. Requested: %, allowed: %",
                              create_info.samples,
                              device.limits.sampledImageIntegerSampleCounts);
            }
        }

        if create_info.usage & .VK_IMAGE_USAGE_STORAGE_BIT {
            if !(create_info.samples & device.limits.storageImageSampleCounts) {
                assertMessage("Device limits do not allow that number of samples for textures with shader write usage. Requested: %, allowed: %",
                              create_info.samples,
                              device.limits.storageImageSampleCounts);
            }
        }
    }
}

checkImageProperties :: (device : *VulkanDevice, texture : *VulkanTexture, create_info : *VkImageCreateInfo) {
    image_format_info := VkPhysicalDeviceImageFormatInfo2.{
        format = create_info.format,
        type   = create_info.imageType,
        tiling = create_info.tiling,
        usage  = create_info.usage,
        flags  = create_info.flags
    };

    image_format_properties : VkImageFormatProperties2;

    result := vkGetPhysicalDeviceImageFormatProperties2(device.physical_device, *image_format_info, *image_format_properties);

    if result == .VK_ERROR_FORMAT_NOT_SUPPORTED {
        assertMessage("Texture \"%\": format % (%) is not supported", texture.name, texture.format, create_info.format);
    } else {
        assert(result == .VK_SUCCESS,
               "Texture \"%\": vkGetPhysicalDeviceImageFormatProperties2 returned %",
               texture.name,
               result);
    }

    if create_info.extent.width  > image_format_properties.imageFormatProperties.maxExtent.width
    || create_info.extent.height > image_format_properties.imageFormatProperties.maxExtent.height
    || create_info.extent.depth  > image_format_properties.imageFormatProperties.maxExtent.depth {
        assertMessage("Texture \"%\": image extent [% x % x %] is too big for this texture, max supported is [% x % x %]",
                      texture.name,
                      create_info.extent.width,
                      create_info.extent.height,
                      create_info.extent.depth,
                      image_format_properties.imageFormatProperties.maxExtent.width,
                      image_format_properties.imageFormatProperties.maxExtent.height,
                      image_format_properties.imageFormatProperties.maxExtent.depth);
    }

    if create_info.mipLevels > image_format_properties.imageFormatProperties.maxMipLevels {
        assertMessage("Texture \"%\": number of mip levels (%) is too high for this texture, max supported is %",
                      texture.name,
                      create_info.mipLevels,
                      image_format_properties.imageFormatProperties.maxMipLevels);
    }

    if create_info.arrayLayers > image_format_properties.imageFormatProperties.maxArrayLayers {
        assertMessage("Texture \"%\": number of array layers (%) is too high for this texture, max supported is %",
                      texture.name,
                      create_info.arrayLayers,
                      image_format_properties.imageFormatProperties.maxArrayLayers);
    }

    if !(image_format_properties.imageFormatProperties.sampleCounts & create_info.samples) {
        assertMessage("Texture \"%\": % samples is not supported for this texture. Supported sample count mask: %",
                      texture.name,
                      create_info.samples,
                      image_format_properties.imageFormatProperties.sampleCounts);
    }
}

// "Texture/<lifetime>/<name>"
composeVulkanTextureName :: (
    texture     : *VulkanTexture,
    memory_pool : *VulkanResourceManager.MemoryPool,
    lifetime    : ResourceManager.Lifetime,
    name        : string
) {
    lifetime_name := Reflection.enum_value_to_name(lifetime);
    assert(lifetime_name);

    full_name_length := "Texture/".count
                      + lifetime_name.count + "/".count
                      + name.count;

    assert(full_name_length <= ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH,
           "Texture full name length (%) > ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH (%)",
           full_name_length,
           ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH);

    texture.name.data = pushToArena(*memory_pool.names_subarena, full_name_length);

    appendToString(*texture.name, full_name_length, "Texture/", lifetime_name, "/", name);
    assert(texture.name.count == full_name_length);
}
