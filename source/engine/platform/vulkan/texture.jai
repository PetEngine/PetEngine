VulkanTextureManager :: struct {
    #as using public_data : TextureManager;

    // @Cleanup: Maybe get rid of arena or textures array?
    Memory :: struct {
        device_memory : VkDeviceMemory;
        textures      : [] VulkanTexture;
        arena         : Arena;
    }

    // @Cleanup: Maybe store it in device?
    memory_properties : VkPhysicalDeviceMemoryProperties2;

    memories : [#run Basic.enum_highest_value(MemoryKind) + 1] Memory;
}

// @TODO: https://registry.khronos.org/vulkan/specs/1.3-extensions/html/chap11.html#_device_group_memory_allocations
createVulkanTextureManager :: (device : *VulkanDevice) -> *VulkanTextureManager #must {
    manager := pushToArena(*context.pet.persistent_arena, VulkanTextureManager);

    builder : Basic.String_Builder;
    builder.allocator = Basic.temporary_allocator;

    for * manager.memories {
        Basic.print_to_builder(*builder, "% textures", cast(VulkanTextureManager.MemoryKind) it_index);

        // @TODO: #Settings. Get the size of the arena from settings.
        createArena(*it.arena, megaBytes(1), Basic.builder_to_string(*builder));

        it.textures.data = it.arena.memory;
    }

    manager.memory_properties.sType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MEMORY_PROPERTIES_2;
    vkGetPhysicalDeviceMemoryProperties2(device.physical_device, *manager.memory_properties);

    return manager;
}

destroyVulkanTextureManager :: (device : *VulkanDevice, manager : *VulkanTextureManager) {
    for * memory_it : manager.memories {
        for * memory_it.textures {
            warningMessage("Texture \"%\" in % has not been freed", it.name, memory_it.arena.name);
            // @TODO: VkAllocationCallbacks
            vkDestroyImage(device.device, it.image, null);
        }
        memory_it.textures.count = 0;

        if memory_it.device_memory {
            warningMessage("% device memory has not been freed", cast(VulkanTextureManager.MemoryKind) it_index);
            // @TODO: VkAllocationCallbacks
            vkFreeMemory(device.device, memory_it.device_memory, null);
            memory_it.device_memory = VK_NULL_HANDLE;
        }

        destroyArena(*memory_it.arena);
    }
}

commitVulkanTextures :: (device : *VulkanDevice, manager : *VulkanTextureManager, $memory_kind : TextureManager.MemoryKind) {
    memory := *manager.memories[memory_kind];
    assert(memory.device_memory == VK_NULL_HANDLE);

    if memory.textures.count <= 0 {
        return;
    }

    memory_type_index : u32 = 0xFFFF_FFFF;

    memory_types_it := manager.memory_properties.memoryProperties.memoryTypes.data;

    for 0 .. manager.memory_properties.memoryProperties.memoryTypeCount - 1 {
        if memory_types_it.propertyFlags & .VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT {
            memory_type_index = it;
            break;
        }

        memory_types_it += 1;
    }

    assert(memory_type_index != 0xFFFF_FFFF, "Device local memory is not supported on this device");

    allocate_info := VkMemoryAllocateInfo.{
        sType           = .VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        pNext           = null,
        allocationSize  = 0, // Will be set in the loop
        memoryTypeIndex = memory_type_index
    };

    bind_infos := pushToArena(*context.pet.per_frame_arena, VkBindImageMemoryInfo, memory.textures.count);

    memory_requirements_info := VkImageMemoryRequirementsInfo2.{
        sType = .VK_STRUCTURE_TYPE_IMAGE_MEMORY_REQUIREMENTS_INFO_2,
        pNext = null,
        image = VK_NULL_HANDLE // Will be set in the loop
    };

    memory_requirements := VkMemoryRequirements2.{
        sType = .VK_STRUCTURE_TYPE_MEMORY_REQUIREMENTS_2,
        pNext = null
    };

    bind_infos_it := bind_infos;
    textures_it   := memory.textures.data;

    memoryOffset : VkDeviceSize = 0;

    for 0 .. memory.textures.count - 1 {
        bind_infos_it.sType        = .VK_STRUCTURE_TYPE_BIND_IMAGE_MEMORY_INFO;
        bind_infos_it.pNext        = null;
        bind_infos_it.image        = textures_it.image;
        bind_infos_it.memoryOffset = memoryOffset;

        memory_requirements_info.image = textures_it.image;
        vkGetImageMemoryRequirements2(device.device, *memory_requirements_info, *memory_requirements);

        requirements := *memory_requirements.memoryRequirements;
        allocate_info.allocationSize = alignUpWithPowerOfTwo(requirements.size, requirements.alignment);

        memoryOffset += allocate_info.allocationSize;

        bind_infos_it += 1;
        textures_it   += 1;
    }

    // @TODO: VkAllocationCallbacks
    debugCheckVK(vkAllocateMemory(device.device, *allocate_info, null, *memory.device_memory));

    setVulkanObjectName(device, .VK_OBJECT_TYPE_DEVICE_MEMORY, memory.device_memory, "% device memory", memory_kind);

    bind_infos_it = bind_infos;
    for 0 .. memory.textures.count - 1 {
        bind_infos_it.memory = memory.device_memory;
        bind_infos_it += 1;
    }

    debugCheckVK(vkBindImageMemory2(device.device, cast(u32) memory.textures.count, bind_infos));
}

resetVulkanTextures :: (device : *VulkanDevice, manager : *VulkanTextureManager, $memory_kind : TextureManager.MemoryKind) {
    memory := *manager.memories[memory_kind];
    assert(memory.device_memory != VK_NULL_HANDLE);

    for * memory.textures {
        // @TODO: VkAllocationCallbacks
        vkDestroyImage(device.device, it.image, null);
    }
    memory.textures.count = 0;

    // @TODO: VkAllocationCallbacks
    vkFreeMemory(device.device, memory.device_memory, null);
    memory.device_memory = VK_NULL_HANDLE;

    resetArena(*memory.arena);
}

VulkanTexture :: struct {
    #as using public_data : Texture;

    image          : VkImage;
    current_layout : VkImageLayout;
}

createVulkanTexture :: (
    device              : *VulkanDevice,
    manager             : *VulkanTextureManager,
    format              : Texture.Format,
    width               : u16,
    height              : u16,
    depth_or_array_size : u16,
    samples_count       : u8,
    mips_count          : u8,
    flags               : Texture.Flags,
    name                : string,
    $memory_kind        : TextureManager.MemoryKind,
    possible_owners     : ..QueueType
) -> *VulkanTexture #must {
    memory := *manager.memories[memory_kind];

    texture := pushToArena(*memory.arena, VulkanTexture);
    memory.textures.count += 1;

    texture.flags                 = flags;
    texture.width                 = width;
    texture.height                = height;
    texture.depth                 = depth_or_array_size;
    texture.samples_count         = samples_count;
    texture.mips_count            = mips_count;
    texture.format                = format;
    texture.name                  = name;
    texture.possible_owners_count = cast(u32) possible_owners.count;
    texture.current_owner         = possible_owners[0];
    texture.current_layout        = .VK_IMAGE_LAYOUT_UNDEFINED;

    queue_family_indices : [Texture.possible_owners.count] u32;
    for possible_owners {
        queue_family_indices[it_index]    = device.queues[it].family_index;
        texture.possible_owners[it_index] = it;
    }

    create_info := VkImageCreateInfo.{
        sType                 = .VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
        pNext                 = null,
        format                = textureFormatToVulkanFormat(format),
        extent                = VkExtent3D.{ 1, 1, 1 },
        mipLevels             = texture.mips_count,
        arrayLayers           = 1,
        tiling                = .VK_IMAGE_TILING_OPTIMAL,
        usage                 = textureFlagsToVulkanUsageFlags(texture.flags),
        queueFamilyIndexCount = texture.possible_owners_count,
        pQueueFamilyIndices   = queue_family_indices.data,
        initialLayout         = .VK_IMAGE_LAYOUT_UNDEFINED // initialLayout must be VK_IMAGE_LAYOUT_UNDEFINED or VK_IMAGE_LAYOUT_PREINITIALIZED
        // Everything else will be set later
    };

    if texture.flags & .ARRAY {
        if height > 0 {
            texture.dimension = ._2D;
        } else {
            texture.dimension = ._1D;
        }
        create_info.arrayLayers = texture.array_size;
    } else if texture.depth > 0 {
        texture.dimension = ._3D;
    } else if texture.height > 0 {
        texture.dimension = ._2D;
    } else {
        texture.dimension = ._1D;
    }

    if texture.flags & .CUBE {
        create_info.flags       |= .VK_IMAGE_CREATE_CUBE_COMPATIBLE_BIT;
        create_info.arrayLayers *= 6;
    }

    if #complete texture.dimension == {
        case ._1D;
            create_info.imageType     = .VK_IMAGE_TYPE_3D;
            create_info.extent.width  = texture.width;
        case ._2D;
            create_info.imageType     = .VK_IMAGE_TYPE_2D;
            create_info.extent.width  = texture.width;
            create_info.extent.height = texture.height;
        case ._3D;
            create_info.imageType     = .VK_IMAGE_TYPE_1D;
            create_info.extent.width  = texture.width;
            create_info.extent.height = texture.height;
            create_info.extent.depth  = texture.depth;
    }

    if texture.samples_count == {
        case  1; create_info.samples = .VK_SAMPLE_COUNT_1_BIT;
        case  2; create_info.samples = .VK_SAMPLE_COUNT_2_BIT;
        case  4; create_info.samples = .VK_SAMPLE_COUNT_4_BIT;
        case  8; create_info.samples = .VK_SAMPLE_COUNT_8_BIT;
        case 16; create_info.samples = .VK_SAMPLE_COUNT_16_BIT;
        case 32; create_info.samples = .VK_SAMPLE_COUNT_32_BIT;
        case 64; create_info.samples = .VK_SAMPLE_COUNT_64_BIT;
    }

    if texture.possible_owners_count > 1 {
        create_info.sharingMode = .VK_SHARING_MODE_CONCURRENT;
    } else {
        create_info.sharingMode = .VK_SHARING_MODE_EXCLUSIVE;
    }

    image_format_info := VkPhysicalDeviceImageFormatInfo2.{
        sType  = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_FORMAT_INFO_2,
        pNext  = null,
        format = create_info.format,
        type   = create_info.imageType,
        tiling = create_info.tiling,
        usage  = create_info.usage,
        flags  = create_info.flags
    };

    image_format_properties := VkImageFormatProperties2.{
        sType = .VK_STRUCTURE_TYPE_IMAGE_FORMAT_PROPERTIES_2,
        pNext = null
    };

    result := vkGetPhysicalDeviceImageFormatProperties2(device.physical_device, *image_format_info, *image_format_properties);
    if result == .VK_ERROR_FORMAT_NOT_SUPPORTED {
        assertMessage("Texture format % (%) is not supported", texture.format, create_info.format);
    } else {
        assert(result == .VK_SUCCESS, "vkGetPhysicalDeviceImageFormatProperties2 returned %", result);
    }

    // @TODO: VkAllocationCallbacks
    debugCheckVK(vkCreateImage(device.device, *create_info, null, *texture.image));

    setVulkanObjectName(device, .VK_OBJECT_TYPE_IMAGE, texture.image, name);

    return texture;
}

textureFormatToVulkanFormat :: (format : Texture.Format) -> VkFormat #no_context {
    if #complete format == {
        case .UNKNOWN;       return .VK_FORMAT_UNDEFINED;
        case .RGB8_UNORM;    return .VK_FORMAT_R8G8B8_UNORM;
        case .RGB8_SNORM;    return .VK_FORMAT_R8G8B8_SNORM;
        case .BGR8_UNORM;    return .VK_FORMAT_B8G8R8_UNORM;
        case .BGR8_SNORM;    return .VK_FORMAT_B8G8R8_SNORM;
        case .RGBA8_UNORM;   return .VK_FORMAT_R8G8B8A8_UNORM;
        case .BGRA8_UNORM;   return .VK_FORMAT_B8G8R8A8_UNORM;
        case .RGB10A2_UNORM; return .VK_FORMAT_A2B10G10R10_UNORM_PACK32;
        case .D32;           return .VK_FORMAT_D32_SFLOAT;
        case .S8;            return .VK_FORMAT_S8_UINT;
        case .BC7_UNORM;     return .VK_FORMAT_BC7_UNORM_BLOCK;
    }
    return .VK_FORMAT_UNDEFINED;
}

vulkanFormatToTextureFormat :: (format : VkFormat) -> Texture.Format #no_context {
    if #complete format == {
        case .VK_FORMAT_UNDEFINED;                return .UNKNOWN;
        case .VK_FORMAT_R8G8B8_UNORM;             return .RGB8_UNORM;
        case .VK_FORMAT_R8G8B8_SNORM;             return .RGB8_SNORM;
        case .VK_FORMAT_B8G8R8_UNORM;             return .BGR8_UNORM;
        case .VK_FORMAT_B8G8R8_SNORM;             return .BGR8_SNORM;
        case .VK_FORMAT_R8G8B8A8_UNORM;           return .RGBA8_UNORM;
        case .VK_FORMAT_B8G8R8A8_UNORM;           return .BGRA8_UNORM;
        case .VK_FORMAT_A2B10G10R10_UNORM_PACK32; return .RGB10A2_UNORM;
        case .VK_FORMAT_D32_SFLOAT;               return .D32;
        case .VK_FORMAT_S8_UINT;                  return .S8;
        case .VK_FORMAT_BC7_UNORM_BLOCK;          return .BC7_UNORM;
    }
    return .UNKNOWN;
}

textureFlagsToVulkanUsageFlags :: (flags : Texture.Flags) -> VkImageUsageFlags #no_context {
    usage_flags := VkImageUsageFlags.VK_IMAGE_USAGE_TRANSFER_SRC_BIT
                 | .VK_IMAGE_USAGE_TRANSFER_DST_BIT;

    if flags & .COHERENT      then usage_flags |= .VK_IMAGE_USAGE_SAMPLED_BIT;
    if flags & .NONCOHERENT   then usage_flags |= .VK_IMAGE_USAGE_STORAGE_BIT;
    if flags & .COLOR_TARGET  then usage_flags |= .VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
    if flags & .DEPTH_STENCIL then usage_flags |= .VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT;

    return usage_flags;
}

vulkanUsageFlagsToTextureFlags :: (usage_flags : VkImageUsageFlags) -> Texture.Flags #no_context {
    flags : Texture.Flags;

    if usage_flags & .VK_IMAGE_USAGE_SAMPLED_BIT                  then flags |= .COHERENT;
    if usage_flags & .VK_IMAGE_USAGE_STORAGE_BIT                  then flags |= .NONCOHERENT;
    if usage_flags & .VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT         then flags |= .COLOR_TARGET;
    if usage_flags & .VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT then flags |= .DEPTH_STENCIL;

    return flags;
}

getVulkanImageAspectFlags :: (texture : *VulkanTexture) -> VkImageAspectFlags {
    if #complete texture.format == {
        case .UNKNOWN;
            return .VK_IMAGE_ASPECT_NONE;
        case .RGB8_UNORM;    #through;
        case .RGB8_SNORM;    #through;
        case .BGR8_UNORM;    #through;
        case .BGR8_SNORM;    #through;
        case .RGBA8_UNORM;   #through;
        case .BGRA8_UNORM;   #through;
        case .RGB10A2_UNORM; #through;
        case .BC7_UNORM;
            return .VK_IMAGE_ASPECT_COLOR_BIT;
        case .D32;
            return .VK_IMAGE_ASPECT_DEPTH_BIT;
        case .S8;
            return .VK_IMAGE_ASPECT_STENCIL_BIT;
    }
    return .VK_IMAGE_ASPECT_NONE;
}

#scope_file
