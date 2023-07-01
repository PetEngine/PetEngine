// @TODO: #VulkanTexture.
//    - Abstract image and view(s) creation to not to write it several times
//      in createVulkanTexture and in resizeResolutionDependentVulkanTextures.
//    - #Views. Image view(s) creation, maybe with usages to be more consistent with other graphics APIs.
//    - #SwapchainBuffers. Make a function for swapchain buffers initialization.
//    - #Resizable.
//    - #ResourceLayout. Rework resource layout changing mechanism. If we gonna compile our command buffers concurrently,
//      current tracking of current texture layout will not work.

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

    persistent_memory                      : Memory;
    persistent_resolution_dependent_memory : Memory;

    per_level_memory                      : Memory;
    per_level_resolution_dependent_memory : Memory;

    // @TODO: #PerFrameTextures. Should we have per_frame_memory_count to check for unreachable per frame memories
    //        when we are changing number of swapchain buffers? Btw, currently we do not have such a mechanism
    //        to change number of swapchain buffers in runtime, so idk.
    per_frame_memory : StaticArray(Memory, Device.MAX_FRAME_BUFFERING);
}

// @TODO: https://registry.khronos.org/vulkan/specs/1.3-extensions/html/chap11.html#_device_group_memory_allocations
createVulkanTextureManager :: (device : *VulkanDevice) -> *VulkanTextureManager #must {
    manager := pushToArena(*context.pet.persistent_arena, VulkanTextureManager);

    manager.per_frame_memory.count = cast,no_check(s64) device.frame_buffering;

    createVulkanTextureMemory(device, manager, .PERSISTENT);
    createVulkanTextureMemory(device, manager, .PERSISTENT_RESOLUTION_DEPENDENT);
    createVulkanTextureMemory(device, manager, .PER_LEVEL);
    createVulkanTextureMemory(device, manager, .PER_LEVEL_RESOLUTION_DEPENDENT);
    createVulkanTextureMemory(device, manager, .PER_FRAME);

    manager.memory_properties.sType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MEMORY_PROPERTIES_2;
    vkGetPhysicalDeviceMemoryProperties2(device.physical_device, *manager.memory_properties);

    return manager;
}

destroyVulkanTextureManager :: (device : *VulkanDevice, manager : *VulkanTextureManager) {
    destroyVulkanTextureMemory(device, manager, .PERSISTENT);
    destroyVulkanTextureMemory(device, manager, .PERSISTENT_RESOLUTION_DEPENDENT);
    destroyVulkanTextureMemory(device, manager, .PER_LEVEL);
    destroyVulkanTextureMemory(device, manager, .PER_LEVEL_RESOLUTION_DEPENDENT);
    destroyVulkanTextureMemory(device, manager, .PER_FRAME);
}

// @TODO: VkPhysicalDeviceVulkan11Properties::maxMemoryAllocationSize
commitVulkanTextureMemory :: (device : *VulkanDevice, manager : *VulkanTextureManager, $memory_kind : TextureManager.MemoryKind) {
    memory := getTextureMemory(device, manager, memory_kind);
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

    memory_offset : VkDeviceSize = 0;

    bind_infos_it := bind_infos;

    for memory.textures {
        bind_infos_it.sType        = .VK_STRUCTURE_TYPE_BIND_IMAGE_MEMORY_INFO;
        bind_infos_it.pNext        = null;
        bind_infos_it.image        = it.image;
        bind_infos_it.memoryOffset = memory_offset;

        memory_requirements_info.image = it.image;
        vkGetImageMemoryRequirements2(device.device, *memory_requirements_info, *memory_requirements);

        requirements := *memory_requirements.memoryRequirements;
        allocate_info.allocationSize = alignUpWithPowerOfTwo(requirements.size, requirements.alignment);

        memory_offset += allocate_info.allocationSize;

        bind_infos_it += 1;
    }

    // @TODO: VkAllocationCallbacks
    debugCheckVK(vkAllocateMemory(device.device, *allocate_info, null, *memory.device_memory));

    setVulkanObjectName(device, memory.device_memory, "% device memory", memory_kind);

    bind_infos_it = bind_infos;
    for 0 .. memory.textures.count - 1 {
        bind_infos_it.memory = memory.device_memory;
        bind_infos_it += 1;
    }

    debugCheckVK(vkBindImageMemory2(device.device, cast(u32) memory.textures.count, bind_infos));

    // @Hardcoded: #Views.
    for memory.textures {
        view_create_info := VkImageViewCreateInfo.{
            sType            = .VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            pNext            = null,
            flags            = 0,
            image            = it.image,
            format           = textureFormatToVulkanFormat(it.format),
            components       = .{
                r = .VK_COMPONENT_SWIZZLE_R,
                g = .VK_COMPONENT_SWIZZLE_G,
                b = .VK_COMPONENT_SWIZZLE_B,
                a = .VK_COMPONENT_SWIZZLE_A,
            },
            subresourceRange = .{
                aspectMask     = getVulkanImageAspectFlags(*it),
                baseMipLevel   = 0,
                levelCount     = VK_REMAINING_MIP_LEVELS,
                baseArrayLayer = 0,
                layerCount     = VK_REMAINING_ARRAY_LAYERS,
            },
        };

        if it.flags & .ARRAY {
            if it.dimension == {
                case ._1D;
                    view_create_info.viewType = .VK_IMAGE_VIEW_TYPE_1D_ARRAY;
                case ._2D;
                    view_create_info.viewType = ifx  it.flags & .CUBE
                                                then .VK_IMAGE_VIEW_TYPE_CUBE_ARRAY
                                                else .VK_IMAGE_VIEW_TYPE_2D_ARRAY;
            }
        } else {
            if #complete it.dimension == {
                case ._1D;
                    view_create_info.viewType = .VK_IMAGE_VIEW_TYPE_1D;
                case ._2D;
                    view_create_info.viewType = ifx  it.flags & .CUBE
                                                then .VK_IMAGE_VIEW_TYPE_CUBE
                                                else .VK_IMAGE_VIEW_TYPE_2D;
                case ._3D;
                    view_create_info.viewType = .VK_IMAGE_VIEW_TYPE_3D;
            }
        }

        // @TODO: VkAllocationCallbacks
        debugCheckVK(vkCreateImageView(device.device, *view_create_info, null, *it.view));

        setVulkanObjectName(device, it.view, it.name);
    }
}

resetVulkanTextureMemory :: (device : *VulkanDevice, manager : *VulkanTextureManager, $memory_kind : TextureManager.MemoryKind) {
    #if memory_kind == .PER_FRAME {
        // @TODO: #PerFrameTextures. #FrameBuffering.
        //    - If device.frame_buffering > manager.per_frame_memory.count allocate new memory memory
        //    - If device.frame_buffering < manager.per_frame_memory.count free unusused memory
        assert(manager.per_frame_memory.count == cast,no_check(s64) device.frame_buffering,
               "It's illegal to change frame buffering for now.");

        manager.per_frame_memory.count = cast,no_check(s64) device.frame_buffering;
    }

    memory := getTextureMemory(device, manager, memory_kind);

    if memory.device_memory == VK_NULL_HANDLE {
        assert(memory.textures.count <= 0);
        assert(memory.arena.occupied <= 0);
        return;
    }

    assert(memory.textures.count > 0);

    for memory.textures {
        // @TODO: VkAllocationCallbacks
        vkDestroyImageView(device.device, it.view, null);
        // @TODO: VkAllocationCallbacks
        vkDestroyImage(device.device, it.image, null);
    }
    memory.textures.count = 0;

    // @TODO: VkAllocationCallbacks
    vkFreeMemory(device.device, memory.device_memory, null);
    memory.device_memory = VK_NULL_HANDLE;

    resetArena(*memory.arena);
}

resizeResolutionDependentVulkanTextures :: (device : *VulkanDevice, manager : *VulkanTextureManager) {
    // We will not resize our window like every frame, so maybe fuck it and just wait for textures be not in use?
    // @Speed: Anyway, if I will figure out some better solution it will be awesome.
    waitDeviceIdle(device);

    resizeResolutionDependentVulkanTextures(device, manager, .PERSISTENT_RESOLUTION_DEPENDENT);
    resizeResolutionDependentVulkanTextures(device, manager, .PER_LEVEL_RESOLUTION_DEPENDENT);
}

VulkanTexture :: struct {
    #as using public_data : Texture;

    image          : VkImage;
    view           : VkImageView;   // @TODO: #Views.
    current_layout : VkImageLayout; // @TODO: Rename to just layout
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
    usage               : Texture.Usage,
    name                : string,
    $memory_kind        : TextureManager.MemoryKind,
    possible_owners     : ..QueueType
) -> *VulkanTexture #must {
    memory := getTextureMemory(device, manager, memory_kind);

    texture := pushToArena(*memory.arena, VulkanTexture);
    memory.textures.count += 1;

    texture.format                = format;
    texture.flags                 = flags;
    texture.usage                 = usage;
    texture.width                 = width;
    texture.height                = height;
    texture.depth                 = depth_or_array_size;
    texture.samples_count         = samples_count;
    texture.mips_count            = mips_count;
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
        format                = textureFormatToVulkanFormat(texture.format),
        mipLevels             = texture.mips_count,
        arrayLayers           = 1,
        samples               = samplesCountToVulkanSampleCountFlags(texture.samples_count),
        tiling                = .VK_IMAGE_TILING_OPTIMAL,
        usage                 = textureUsageToVulkanUsageFlags(texture.usage),
        queueFamilyIndexCount = texture.possible_owners_count,
        pQueueFamilyIndices   = queue_family_indices.data,
        initialLayout         = .VK_IMAGE_LAYOUT_UNDEFINED // initialLayout must be VK_IMAGE_LAYOUT_UNDEFINED or VK_IMAGE_LAYOUT_PREINITIALIZED
        // Everything else will be set later
    };

    if texture.flags & .ARRAY {
        create_info.arrayLayers = texture.array_size;

        if height > 0 {
            texture.dimension = ._2D;
        } else {
            texture.dimension = ._1D;
        }
    } else if texture.depth > 0 {
        texture.dimension = ._3D;
    } else if texture.height > 0 {
        texture.dimension = ._2D;
    } else {
        texture.dimension = ._1D;
    }

    assert((texture.dimension == ._2D) || !(texture.flags & .RESOLUTION_DEPENDENT), "Only 2D textures can be resolution dependent");

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

    if texture.possible_owners_count > 1 {
        create_info.sharingMode = .VK_SHARING_MODE_CONCURRENT;
    } else {
        create_info.sharingMode = .VK_SHARING_MODE_EXCLUSIVE;
    }

    checkCreateInfoLimits(device, *create_info, textureFormatFlags(texture.format));

    {
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
    }

    // @TODO: VkAllocationCallbacks
    debugCheckVK(vkCreateImage(device.device, *create_info, null, *texture.image));

    setVulkanObjectName(device, texture.image, texture.name);

    return texture;
}

textureFormatToVulkanFormat :: inline (format : Texture.Format) -> VkFormat #no_context {
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

vulkanFormatToTextureFormat :: inline (format : VkFormat) -> Texture.Format #no_context {
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

textureUsageToVulkanUsageFlags :: inline (usage : Texture.Usage) -> VkImageUsageFlags #no_context {
    usage_flags : VkImageUsageFlags = .VK_IMAGE_USAGE_TRANSFER_SRC_BIT
                                    | .VK_IMAGE_USAGE_TRANSFER_DST_BIT;

    if usage & .SHADER_READ  then usage_flags |= .VK_IMAGE_USAGE_SAMPLED_BIT;
    if usage & .SHADER_WRITE then usage_flags |= .VK_IMAGE_USAGE_STORAGE_BIT;
    if usage & .COLOR_TARGET then usage_flags |= .VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
    if usage & .DEPTH_TARGET then usage_flags |= .VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT;

    return usage_flags;
}

vulkanUsageFlagsToTextureUsage :: inline (usage_flags : VkImageUsageFlags) -> Texture.Usage #no_context {
    usage : Texture.Usage;

    if usage_flags & .VK_IMAGE_USAGE_SAMPLED_BIT                  then usage |= .SHADER_READ;
    if usage_flags & .VK_IMAGE_USAGE_STORAGE_BIT                  then usage |= .SHADER_WRITE;
    if usage_flags & .VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT         then usage |= .COLOR_TARGET;
    if usage_flags & .VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT then usage |= .DEPTH_TARGET;

    return usage;
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

getVulkanImageAspectFlags :: inline (texture : *VulkanTexture) -> VkImageAspectFlags #no_context {
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

getTextureMemory :: inline (
    device       : *VulkanDevice,
    manager      : *VulkanTextureManager,
    $memory_kind : TextureManager.MemoryKind
) -> *VulkanTextureManager.Memory #no_context {
    #if memory_kind == .PERSISTENT {
        return *manager.persistent_memory;
    } else #if memory_kind == .PERSISTENT_RESOLUTION_DEPENDENT {
        return *manager.persistent_resolution_dependent_memory;
    } else #if memory_kind == .PER_LEVEL {
        return *manager.per_level_memory;
    } else #if memory_kind == .PER_LEVEL_RESOLUTION_DEPENDENT {
        return *manager.per_level_resolution_dependent_memory;
    } else #if memory_kind == .PER_FRAME {
        return *manager.per_frame_memory[device.frame_index];
    } else {
        #assert false "Unhandled TextureManager.MemoryKind";
        return null;
    }
}

createVulkanTextureMemory :: (device : *VulkanDevice, manager : *VulkanTextureManager, $memory_kind : TextureManager.MemoryKind) {
    builder : Basic.String_Builder;
    builder.allocator = Basic.temporary_allocator;

    #if memory_kind == .PER_FRAME {
        for * manager.per_frame_memory {
            Basic.print_to_builder(*builder, "% textures for frame #%", memory_kind, it_index);

            // @TODO: #Settings. Get the size of the arena from settings.
            createArena(*it.arena, megaBytes(1), Basic.builder_to_string(*builder));

            it.textures.data = it.arena.memory;
        }
    } else {
        memory := getTextureMemory(device, manager, memory_kind);

        Basic.print_to_builder(*builder, "% textures", memory_kind);

        // @TODO: #Settings. Get the size of the arena from settings.
        createArena(*memory.arena, megaBytes(1), Basic.builder_to_string(*builder));

        memory.textures.data = memory.arena.memory;
    }
}

destroyVulkanTextureMemory :: (device : *VulkanDevice, manager : *VulkanTextureManager, $memory_kind : TextureManager.MemoryKind) {
    #if memory_kind == .PER_FRAME {
        for * memory : manager.per_frame_memory {
            for memory.textures {
                warningMessage("Texture \"%\" in % has not been freed", it.name, memory.arena.name);
                // @TODO: VkAllocationCallbacks
                vkDestroyImageView(device.device, it.view, null);
                // @TODO: VkAllocationCallbacks
                vkDestroyImage(device.device, it.image, null);
            }
            memory.textures.count = 0;

            if memory.device_memory {
                warningMessage("% device memory has not been freed", memory_kind);
                // @TODO: VkAllocationCallbacks
                vkFreeMemory(device.device, memory.device_memory, null);
                memory.device_memory = VK_NULL_HANDLE;
            }

            destroyArena(*memory.arena);
        }
    } else {
        memory := getTextureMemory(device, manager, memory_kind);

        for memory.textures {
            warningMessage("Texture \"%\" in % has not been freed", it.name, memory.arena.name);
            // @TODO: VkAllocationCallbacks
            vkDestroyImageView(device.device, it.view, null);
            // @TODO: VkAllocationCallbacks
            vkDestroyImage(device.device, it.image, null);
        }
        memory.textures.count = 0;

        if memory.device_memory {
            warningMessage("% device memory has not been freed", memory_kind);
            // @TODO: VkAllocationCallbacks
            vkFreeMemory(device.device, memory.device_memory, null);
            memory.device_memory = VK_NULL_HANDLE;
        }

        destroyArena(*memory.arena);
    }
}

resizeResolutionDependentVulkanTextures :: (
    device       : *VulkanDevice,
    manager      : *VulkanTextureManager,
    $memory_kind : TextureManager.MemoryKind
) {
    #assert memory_kind == .PERSISTENT_RESOLUTION_DEPENDENT || memory_kind == .PER_LEVEL_RESOLUTION_DEPENDENT;

    memory := getTextureMemory(device, manager, memory_kind);
    if memory.textures.count <= 0 return;

    back_buffer := getBackBuffer(device);

    queue_family_indices : [Texture.possible_owners.count] u32;

    create_info := VkImageCreateInfo.{
        sType               = .VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
        pNext               = null,
        flags               = 0,
        imageType           = .VK_IMAGE_TYPE_2D,
        extent              = .{ back_buffer.width, back_buffer.height, 1 },
        mipLevels           = 1,
        arrayLayers         = 1,
        tiling              = .VK_IMAGE_TILING_OPTIMAL,
        pQueueFamilyIndices = queue_family_indices.data,
        initialLayout       = .VK_IMAGE_LAYOUT_UNDEFINED // initialLayout must be VK_IMAGE_LAYOUT_UNDEFINED or VK_IMAGE_LAYOUT_PREINITIALIZED
        // Everything else will be set in the loop
    };

    for * texture : memory.textures {
        for 0 .. texture.possible_owners_count - 1 {
            queue_family_indices[it] = device.queues[texture.possible_owners[it]].family_index;
        }

        create_info.format                = textureFormatToVulkanFormat(texture.format);
        create_info.samples               = samplesCountToVulkanSampleCountFlags(texture.samples_count);
        create_info.usage                 = textureUsageToVulkanUsageFlags(texture.usage);
        create_info.queueFamilyIndexCount = texture.possible_owners_count;

        if texture.possible_owners_count > 1 {
            create_info.sharingMode = .VK_SHARING_MODE_CONCURRENT;
        } else {
            create_info.sharingMode = .VK_SHARING_MODE_EXCLUSIVE;
        }

        texture.width          = back_buffer.width;
        texture.height         = back_buffer.height;
        texture.current_layout = .VK_IMAGE_LAYOUT_UNDEFINED;
        texture.current_owner  = texture.possible_owners[0];

        // @TODO: VkAllocationCallbacks
        vkDestroyImageView(device.device, texture.view, null);

        // @TODO: VkAllocationCallbacks
        vkDestroyImage(device.device, texture.image, null);

        // @TODO: VkAllocationCallbacks
        debugCheckVK(vkCreateImage(device.device, *create_info, null, *texture.image));

        setVulkanObjectName(device, texture.image, texture.name);
    }

    if memory.device_memory {
        // @TODO: VkAllocationCallbacks
        vkFreeMemory(device.device, memory.device_memory, null);
        memory.device_memory = VK_NULL_HANDLE;
    }

    commitVulkanTextureMemory(device, manager, memory_kind);
}

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
