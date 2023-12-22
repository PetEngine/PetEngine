// @TODO: #VulkanTexture.
//    - Abstract image and view(s) creation to not to write it several times
//      in createVulkanTexture and in resizeResolutionDependentVulkanTextures.
//    - #Views. Image view(s) creation, maybe with usages to be more consistent with other graphics APIs.
//    - #SwapchainBuffers. Make a function for swapchain buffers initialization.
//    - #Resizable.
//    - #ResourceLayout. Rework resource layout changing mechanism. If we gonna compile our command buffers concurrently,
//      current tracking of current texture layout will not work.

VulkanResourceManager :: struct {
    #as using public_data : ResourceManager;

    Memory :: struct(kind : MemoryKind) {
        device_memory : VkDeviceMemory;

        union {
            buffers  : StaticArray(VulkanBuffer, MAX_BUFFERS);
            textures : StaticArray(VulkanTexture, MAX_TEXTURES);
        }

        names_subarena : Arena;
    }

    buffer_memory : struct {
        persistent : Memory(.PERSISTENT);
        per_scene  : Memory(.PER_SCENE);
        per_frame  : StaticArray(Memory(.PER_FRAME), Device.MAX_FRAME_BUFFERING);
    }

    texture_memory : struct {
        persistent                      : Memory(.PERSISTENT);
        persistent_resolution_dependent : Memory(.PERSISTENT_RESOLUTION_DEPENDENT);
        per_scene                       : Memory(.PER_SCENE);
        per_scene_resolution_dependent  : Memory(.PER_SCENE_RESOLUTION_DEPENDENT);
        per_frame                       : StaticArray(Memory(.PER_FRAME), Device.MAX_FRAME_BUFFERING);
    }

    names_arena : Arena;
}

createVulkanResourceManager :: (device : *VulkanDevice) -> *VulkanResourceManager #must {
    manager := pushToArena(*context.pet.persistent_arena, VulkanResourceManager);

    manager.destroyPlatformResourceManager            = destroyVulkanResourceManager;
    manager.commitPlatformResourceMemory              = commitVulkanResourceMemory;
    manager.resetPlatformResourceMemory               = resetVulkanResourceMemory;
    manager.resizePlatformResolutionDependentTextures = resizeVulkanResolutionDependentTextures;

    manager.pushPlatformBuffer   = pushVulkanBuffer;
    manager.createPlatformBuffer = createVulkanBuffer;

    manager.pushPlatformTexture   = pushVulkanTexture;
    manager.createPlatformTexture = createVulkanTexture;

    manager.buffer_memory.per_frame.count  = manager.buffer_memory.per_frame.capacity;
    manager.texture_memory.per_frame.count = manager.texture_memory.per_frame.capacity;

    BUFFER_SUBARENA_CAPACITY  :: ResourceManager.MAX_BUFFERS  * ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH;
    TEXTURE_SUBARENA_CAPACITY :: ResourceManager.MAX_TEXTURES * ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH;
    MANAGER_ARENA_CAPACITY :: (2 + manager.buffer_memory.per_frame.capacity)  * BUFFER_SUBARENA_CAPACITY
                            + (4 + manager.texture_memory.per_frame.capacity) * TEXTURE_SUBARENA_CAPACITY;

    createArena(*manager.names_arena, MANAGER_ARENA_CAPACITY, "VulkanResourceManager names");

    createSubarena(*manager.names_arena, *manager.buffer_memory.persistent.names_subarena, BUFFER_SUBARENA_CAPACITY, "Persistent buffers names");
    createSubarena(*manager.names_arena, *manager.buffer_memory.per_scene.names_subarena, BUFFER_SUBARENA_CAPACITY, "PerScene buffers names");
    for * manager.buffer_memory.per_frame {
        createSubarena(*manager.names_arena, *it.names_subarena, BUFFER_SUBARENA_CAPACITY, "Frame #% buffers names", it_index);
    }

    createSubarena(*manager.names_arena, *manager.texture_memory.persistent.names_subarena,                      TEXTURE_SUBARENA_CAPACITY, "Persistent textures names");
    createSubarena(*manager.names_arena, *manager.texture_memory.persistent_resolution_dependent.names_subarena, TEXTURE_SUBARENA_CAPACITY, "Persistent resolution dependent textures names");
    createSubarena(*manager.names_arena, *manager.texture_memory.per_scene.names_subarena,                       TEXTURE_SUBARENA_CAPACITY, "Per scene textures names");
    createSubarena(*manager.names_arena, *manager.texture_memory.per_scene_resolution_dependent.names_subarena,  TEXTURE_SUBARENA_CAPACITY, "Per scene resolution dependent textures names");
    for * manager.texture_memory.per_frame {
        createSubarena(*manager.names_arena, *it.names_subarena, TEXTURE_SUBARENA_CAPACITY, "Frame #% textures names", it_index);
    }

    manager.buffer_memory.per_frame.count  = cast,no_check(s64) device.frame_buffering;
    manager.texture_memory.per_frame.count = cast,no_check(s64) device.frame_buffering;

    return manager;
}

#scope_file

destroyVulkanResourceManager :: (device_ : *Device, manager_ : *ResourceManager) {
    device  := cast(*VulkanDevice)          device_;
    manager := cast(*VulkanResourceManager) manager_;

    destroyVulkanBufferMemory(device, *manager.buffer_memory.persistent);
    destroyVulkanBufferMemory(device, *manager.buffer_memory.per_scene);
    for * manager.buffer_memory.per_frame {
        destroyVulkanBufferMemory(device, it);
    }

    destroyVulkanTextureMemory(device, *manager.texture_memory.persistent);
    destroyVulkanTextureMemory(device, *manager.texture_memory.persistent_resolution_dependent);
    destroyVulkanTextureMemory(device, *manager.texture_memory.per_scene);
    destroyVulkanTextureMemory(device, *manager.texture_memory.per_scene_resolution_dependent);
    for * manager.texture_memory.per_frame {
        destroyVulkanTextureMemory(device, it);
    }

    destroyArena(*manager.names_arena);
}

commitVulkanResourceMemory :: (device_ : *Device, manager_ : *ResourceManager, memory_kind : ResourceManager.MemoryKind) {
    device  := cast(*VulkanDevice)          device_;
    manager := cast(*VulkanResourceManager) manager_;

    if #complete memory_kind == {
        case .PERSISTENT;
            commitVulkanBufferMemory(device, *manager.buffer_memory.persistent);
            commitVulkanTextureMemory(device, *manager.texture_memory.persistent);

        case .PERSISTENT_RESOLUTION_DEPENDENT;
            commitVulkanTextureMemory(device, *manager.texture_memory.persistent_resolution_dependent);

        case .PER_SCENE;
            commitVulkanBufferMemory(device, *manager.buffer_memory.per_scene);
            commitVulkanTextureMemory(device, *manager.texture_memory.per_scene);

        case .PER_SCENE_RESOLUTION_DEPENDENT;
            commitVulkanTextureMemory(device, *manager.texture_memory.per_scene_resolution_dependent);

        case .PER_FRAME;
            commitVulkanBufferMemory(device, *manager.buffer_memory.per_frame[device.frame_index]);
            commitVulkanTextureMemory(device, *manager.texture_memory.per_frame[device.frame_index]);
    }
}

resetVulkanResourceMemory :: (device_ : *Device, manager_ : *ResourceManager, memory_kind : ResourceManager.MemoryKind) {
    device  := cast(*VulkanDevice)          device_;
    manager := cast(*VulkanResourceManager) manager_;

    if #complete memory_kind == {
        case .PERSISTENT;
            resetVulkanBufferMemory(device, *manager.buffer_memory.persistent);
            resetVulkanTextureMemory(device, *manager.texture_memory.persistent);

        case .PERSISTENT_RESOLUTION_DEPENDENT;
            resetVulkanTextureMemory(device, *manager.texture_memory.persistent_resolution_dependent);

        case .PER_SCENE;
            resetVulkanBufferMemory(device, *manager.buffer_memory.per_scene);
            resetVulkanTextureMemory(device, *manager.texture_memory.per_scene);

        case .PER_SCENE_RESOLUTION_DEPENDENT;
            resetVulkanTextureMemory(device, *manager.texture_memory.per_scene_resolution_dependent);

        case .PER_FRAME;
            // @TODO: #PerFrameTextures. #PerFrameBuffers. #FrameBuffering.
            //    - If manager.*_memory.per_frame.count < device.frame_buffering then allocate new memory memory
            //    - If manager.*_memory.per_frame.count > device.frame_buffering then free unusused memory
            assert(manager.buffer_memory.per_frame.count  == cast,no_check(s64) device.frame_buffering, "It's illegal to change frame buffering for now.");
            assert(manager.texture_memory.per_frame.count == cast,no_check(s64) device.frame_buffering, "It's illegal to change frame buffering for now.");

            manager.buffer_memory.per_frame.count  = cast,no_check(s64) device.frame_buffering;
            manager.texture_memory.per_frame.count = cast,no_check(s64) device.frame_buffering;

            resetVulkanBufferMemory(device, *manager.buffer_memory.per_frame[device.frame_index]);
            resetVulkanTextureMemory(device, *manager.texture_memory.per_frame[device.frame_index]);
    }
}

resizeVulkanResolutionDependentTextures :: (device_ : *Device, manager_ : *ResourceManager) {
    device  := cast(*VulkanDevice)          device_;
    manager := cast(*VulkanResourceManager) manager_;

    // We will not resize our window every frame, so maybe fuck it and just wait for textures not being in use?
    // @Speed: Anyway, if I will figure out some better solution it will be awesome.
    waitDeviceIdle(device);

    resizeVulkanResolutionDependentTextures(device, *manager.texture_memory.persistent_resolution_dependent);
    resizeVulkanResolutionDependentTextures(device, *manager.texture_memory.per_scene_resolution_dependent);
}

//
// Buffers
//

destroyVulkanBufferMemory :: (device : *VulkanDevice, memory : *VulkanResourceManager.Memory) {
    for memory.buffers {
        warningMessage("Buffer \"%\" in % memory has not been freed", it.name, memory.kind);
        // @TODO: VkAllocationCallbacks
        vkDestroyBuffer(device.device, it.buffer, null);
    }
    memory.buffers.count = 0;

    if memory.device_memory {
        warningMessage("% device memory has not been freed", memory.kind);
        // @TODO: VkAllocationCallbacks
        vkFreeMemory(device.device, memory.device_memory, null);
        memory.device_memory = VK_NULL_HANDLE;
    }

    destroySubarena(*memory.names_subarena);
}

commitVulkanBufferMemory :: (device : *VulkanDevice, memory : *VulkanResourceManager.Memory) {
    assert(memory.device_memory == VK_NULL_HANDLE);
    if memory.buffers.count <= 0 return;

    memory_type_index : u32 = 0xFFFF_FFFF;

    for toView(device.memory_properties.memoryProperties.memoryTypes.data, device.memory_properties.memoryProperties.memoryTypeCount) {
        if it.propertyFlags & .VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT {
            memory_type_index = cast(u32) it_index;
            break;
        }
    }
    assert(memory_type_index != 0xFFFF_FFFF, "Device local memory is not supported on this device");

    allocate_info := VkMemoryAllocateInfo.{
        allocationSize  = 0, // Will be set in the loop
        memoryTypeIndex = memory_type_index
    };

    bind_infos    := pushToArena(*context.pet.per_frame_arena, VkBindBufferMemoryInfo, memory.textures.count);
    bind_infos_it := bind_infos;

    memory_requirements_info : VkBufferMemoryRequirementsInfo2;
    memory_requirements      : VkMemoryRequirements2;
    memory_offset            : VkDeviceSize;

    for memory.buffers {
        bind_infos_it.buffer       = it.buffer;
        bind_infos_it.memoryOffset = memory_offset;

        memory_requirements_info.buffer = it.buffer;
        vkGetBufferMemoryRequirements2(device.device, *memory_requirements_info, *memory_requirements);

        requirements := *memory_requirements.memoryRequirements;
        allocate_info.allocationSize = alignUpWithPowerOfTwo(requirements.size, requirements.alignment);

        memory_offset += allocate_info.allocationSize;

        bind_infos_it += 1;
    }

    // @TODO: VkAllocationCallbacks
    debugCheckVK(vkAllocateMemory(device.device, *allocate_info, null, *memory.device_memory));

    setVulkanObjectName(device, memory.device_memory, "Memory/Buffers/%", memory.kind);

    bind_infos_it = bind_infos;
    for 0 .. memory.buffers.count - 1 {
        bind_infos_it.memory = memory.device_memory;
        bind_infos_it += 1;
    }

    debugCheckVK(vkBindBufferMemory2(device.device, cast(u32) memory.buffers.count, bind_infos));

    // @TODO: #Views
}

resetVulkanBufferMemory :: (device : *VulkanDevice, memory : *VulkanResourceManager.Memory) {
    for memory.buffers {
        // @TODO: VkAllocationCallbacks
        vkDestroyBuffer(device.device, it.buffer, null);
        it.buffer = VK_NULL_HANDLE;
    }
    memory.buffers.count = 0;

    if memory.device_memory {
        // @TODO: VkAllocationCallbacks
        vkFreeMemory(device.device, memory.device_memory, null);
        memory.device_memory = VK_NULL_HANDLE;
    }

    resetArena(*memory.names_subarena);
}

//
// Textures
//

destroyVulkanTextureMemory :: (device : *VulkanDevice, memory : *VulkanResourceManager.Memory) {
    for memory.textures {
        warningMessage("Texture \"%\" in % memory has not been freed", it.name, memory.kind);
        // @TODO: VkAllocationCallbacks
        vkDestroyImageView(device.device, it.view, null);
        // @TODO: VkAllocationCallbacks
        vkDestroyImage(device.device, it.image, null);
    }
    memory.textures.count = 0;

    if memory.device_memory {
        warningMessage("% device memory has not been freed", memory.kind);
        // @TODO: VkAllocationCallbacks
        vkFreeMemory(device.device, memory.device_memory, null);
        memory.device_memory = VK_NULL_HANDLE;
    }

    destroySubarena(*memory.names_subarena);
}

// @TODO: VkPhysicalDeviceVulkan11Properties::maxMemoryAllocationSize
commitVulkanTextureMemory :: (device : *VulkanDevice, memory : *VulkanResourceManager.Memory) {
    assert(memory.device_memory == VK_NULL_HANDLE);

    if memory.textures.count <= 0 {
        return;
    }

    memory_type_index : u32 = 0xFFFF_FFFF;

    memory_types_it := device.memory_properties.memoryProperties.memoryTypes.data;

    for 0 .. device.memory_properties.memoryProperties.memoryTypeCount - 1 {
        if memory_types_it.propertyFlags & .VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT {
            memory_type_index = it;
            break;
        }

        memory_types_it += 1;
    }

    assert(memory_type_index != 0xFFFF_FFFF, "Device local memory is not supported on this device");

    allocate_info := VkMemoryAllocateInfo.{
        allocationSize  = 0, // Will be set in the loop
        memoryTypeIndex = memory_type_index
    };

    bind_infos    := pushToArena(*context.pet.per_frame_arena, VkBindImageMemoryInfo, memory.textures.count);
    bind_infos_it := bind_infos;

    memory_requirements_info : VkImageMemoryRequirementsInfo2;
    memory_requirements      : VkMemoryRequirements2;
    memory_offset            : VkDeviceSize;

    for memory.textures {
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

    setVulkanObjectName(device, memory.device_memory, "Memory/Textures/%", memory.kind);

    bind_infos_it = bind_infos;
    for 0 .. memory.textures.count - 1 {
        bind_infos_it.memory = memory.device_memory;
        bind_infos_it += 1;
    }

    debugCheckVK(vkBindImageMemory2(device.device, cast(u32) memory.textures.count, bind_infos));

    //
    // @Hardcoded: #Views.
    //    Views must be created to already bound images.
    //

    for * memory.textures {
        view_create_info := VkImageViewCreateInfo.{
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
                aspectMask     = getVulkanImageAspectFlags(it.format),
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

        setVulkanObjectName(device, it.view, "% view", it.name);
    }
}

resetVulkanTextureMemory :: (device : *VulkanDevice, memory : *VulkanResourceManager.Memory) {
    for memory.textures {
        // @TODO: VkAllocationCallbacks
        vkDestroyImageView(device.device, it.view, null);
        it.view = VK_NULL_HANDLE;

        // @TODO: VkAllocationCallbacks
        vkDestroyImage(device.device, it.image, null);
        it.image = VK_NULL_HANDLE;
    }
    memory.textures.count = 0;

    if memory.device_memory {
        // @TODO: VkAllocationCallbacks
        vkFreeMemory(device.device, memory.device_memory, null);
        memory.device_memory = VK_NULL_HANDLE;
    }

    resetArena(*memory.names_subarena);
}

resizeVulkanResolutionDependentTextures :: (device : *VulkanDevice, memory : *VulkanResourceManager.Memory) {
    if memory.textures.count <= 0 return;

    back_buffer := getBackBuffer(device);

    queue_family_indices : [Texture.possible_owners.capacity] u32;

    create_info := VkImageCreateInfo.{
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

    for * memory.textures {
        for it.possible_owners {
            queue_family_indices[it_index] = device.queues[it].family_index;
        }

        create_info.format                = textureFormatToVulkanFormat(it.format);
        create_info.samples               = samplesCountToVulkanSampleCountFlags(it.samples_count);
        create_info.usage                 = textureUsageToVulkanUsageFlags(it.usage);
        create_info.queueFamilyIndexCount = cast(u32) it.possible_owners.count;

        if it.possible_owners.count > 1 {
            create_info.sharingMode = .VK_SHARING_MODE_CONCURRENT;
        } else {
            create_info.sharingMode = .VK_SHARING_MODE_EXCLUSIVE;
        }

        it.width          = back_buffer.width;
        it.height         = back_buffer.height;
        it.current_layout = .VK_IMAGE_LAYOUT_UNDEFINED;
        it.current_owner  = it.possible_owners[0];

        // @TODO: VkAllocationCallbacks
        vkDestroyImageView(device.device, it.view, null);

        // @TODO: VkAllocationCallbacks
        vkDestroyImage(device.device, it.image, null);

        // @TODO: VkAllocationCallbacks
        debugCheckVK(vkCreateImage(device.device, *create_info, null, *it.image));

        setVulkanObjectName(device, it.image, "% view", it.name);
    }

    if memory.device_memory {
        // @TODO: VkAllocationCallbacks
        vkFreeMemory(device.device, memory.device_memory, null);
        memory.device_memory = VK_NULL_HANDLE;
    }

    commitVulkanTextureMemory(device, memory);
}
