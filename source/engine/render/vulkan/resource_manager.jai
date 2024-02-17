// @TODO: #VulkanTexture.
//    - #Views. Image view(s) creation, maybe with usages to be more consistent with other graphics APIs.
//    - #SwapchainBuffers. Make a function for swapchain buffers initialization?
//    - #ResourceLayout. Rework resource layout changing mechanism. If we gonna compile our command buffers concurrently,
//      current tracking of current texture layout will not work.

VulkanResourceManager :: struct {
    #as using public_data : ResourceManager;

    MemoryPool :: struct(VulkanResource : Type, capacity : s64) {
        device_memory  : VkDeviceMemory;
        resources      : StaticArray(VulkanResource, capacity);
        names_subarena : Arena;
    }

    Memory :: struct(VulkanResource : Type, capacity : s64) {
        persistent : [POOLS_COUNT] MemoryPool(VulkanResource, capacity);
        per_scene  : [POOLS_COUNT] MemoryPool(VulkanResource, capacity);
        per_frame  : [POOLS_COUNT] StaticArray(MemoryPool(VulkanResource, capacity), Device.MAX_FRAME_BUFFERING);
    }

    buffers  : Memory(VulkanBuffer,  MAX_BUFFERS);
    textures : Memory(VulkanTexture, MAX_TEXTURES);

    names_arena : Arena;
}

createVulkanResourceManager :: (device : *VulkanDevice) -> *VulkanResourceManager #must {
    manager := pushToArena(*context.pet.persistent_arena, VulkanResourceManager);

    manager.destroyPlatformResourceManager = destroyVulkanResourceManager;
    manager.commitPlatformResourceMemory   = commitVulkanResourceMemory;
    manager.resetPlatformResourceMemory    = resetVulkanResourceMemory;

    manager.pushPlatformBuffer   = pushVulkanBuffer;
    manager.createPlatformBuffer = createVulkanBuffer;

    manager.pushPlatformTexture   = pushVulkanTexture;
    manager.createPlatformTexture = createVulkanTexture;

    BUFFERS_SUBARENA_CAPACITY  :: ResourceManager.MAX_BUFFERS  * ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH;
    TEXTURES_SUBARENA_CAPACITY :: ResourceManager.MAX_TEXTURES * ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH;
    MANAGER_ARENA_CAPACITY     :: (2 + Device.MAX_FRAME_BUFFERING)
                                * ResourceManager.POOLS_COUNT
                                * (BUFFERS_SUBARENA_CAPACITY + TEXTURES_SUBARENA_CAPACITY);

    createArena(*manager.names_arena, MANAGER_ARENA_CAPACITY, "VulkanResourceManager names");

    createVulkanResourceMemoryNamesSubarenas(*manager.buffers,  *manager.names_arena, BUFFERS_SUBARENA_CAPACITY,  device.frame_buffering);
    createVulkanResourceMemoryNamesSubarenas(*manager.textures, *manager.names_arena, TEXTURES_SUBARENA_CAPACITY, device.frame_buffering);

    return manager;
}

#scope_file

createVulkanResourceMemoryNamesSubarenas :: (
    memory            : *VulkanResourceManager.Memory,
    arena             : *Arena,
    subarena_capacity : s64,
    frames_buffering  : FrameBuffering
) {
    #if memory.VulkanResource == {
        case VulkanBuffer;  RESOURCE_KIND_NAME :: "Buffers";
        case VulkanTexture; RESOURCE_KIND_NAME :: "Textures";
        case;               #assert false, "Unhandled type";
    }

    for * memory.persistent {
        createSubarena(arena, *it.names_subarena, subarena_capacity, "%/Persistent/%", RESOURCE_KIND_NAME, cast(ResourceManager.Pool) it_index);
    }

    for * memory.per_scene {
        createSubarena(arena, *it.names_subarena, subarena_capacity, "%/Per scene/%", RESOURCE_KIND_NAME, cast(ResourceManager.Pool) it_index);
    }

    for * frame_pools, pool_index : memory.per_frame {
        frame_pools.count = frame_pools.capacity;

        for * frame_pools {
            createSubarena(arena, *it.names_subarena, subarena_capacity, "%/Frame #%/%", RESOURCE_KIND_NAME, it_index, cast(ResourceManager.Pool) pool_index);
        }

        frame_pools.count = cast,no_check(s64) frames_buffering;
    }
}

destroyVulkanResourceManager :: (device_ : *Device, manager_ : *ResourceManager) {
    device  := cast(*VulkanDevice)          device_;
    manager := cast(*VulkanResourceManager) manager_;

    destroyVulkanResourceMemory(device, *manager.buffers);
    destroyVulkanResourceMemory(device, *manager.textures);

    destroyArena(*manager.names_arena);
}

commitVulkanResourceMemory :: (device_ : *Device, manager_ : *ResourceManager, lifetime : ResourceManager.Lifetime) {
    device  := cast(*VulkanDevice)          device_;
    manager := cast(*VulkanResourceManager) manager_;

    if #complete lifetime == {
        case .PERSISTENT;
            for * manager.buffers.persistent  commitVulkanBufferMemory(device,  it, lifetime, cast(ResourceManager.Pool) it_index);
            for * manager.textures.persistent commitVulkanTextureMemory(device, it, lifetime, cast(ResourceManager.Pool) it_index);

        case .PER_SCENE;
            for * manager.buffers.per_scene  commitVulkanBufferMemory(device,  it, lifetime, cast(ResourceManager.Pool) it_index);
            for * manager.textures.per_scene commitVulkanTextureMemory(device, it, lifetime, cast(ResourceManager.Pool) it_index);

        case .PER_FRAME;
            for * manager.buffers.per_frame  commitVulkanBufferMemory(device,  *it.*[device.frame_index], lifetime, cast(ResourceManager.Pool) it_index);
            for * manager.textures.per_frame commitVulkanTextureMemory(device, *it.*[device.frame_index], lifetime, cast(ResourceManager.Pool) it_index);
    }
}

resetVulkanResourceMemory :: (device_ : *Device, manager_ : *ResourceManager, lifetime : ResourceManager.Lifetime) {
    device  := cast(*VulkanDevice)          device_;
    manager := cast(*VulkanResourceManager) manager_;

    if #complete lifetime == {
        case .PERSISTENT;
            for * manager.buffers.persistent  resetVulkanResourceMemoryPool(device, it);
            for * manager.textures.persistent resetVulkanResourceMemoryPool(device, it);

        case .PER_SCENE;
            for * manager.buffers.per_scene  resetVulkanResourceMemoryPool(device, it);
            for * manager.textures.per_scene resetVulkanResourceMemoryPool(device, it);

        case .PER_FRAME;
            // @TODO: #PerFrameTextures. #PerFrameBuffers. #FrameBuffering.
            //    - If manager.*.per_frame[*].count < device.frame_buffering then allocate new memory memory
            //    - If manager.*.per_frame[*].count > device.frame_buffering then free unusused memory

            for * manager.buffers.per_frame {
                assert(it.count == cast,no_check(s64) device.frame_buffering, "It's illegal to change frame buffering for now.");
                it.count = cast,no_check(s64) device.frame_buffering;

                resetVulkanResourceMemoryPool(device, *it.*[device.frame_index]);
            }

            for * manager.textures.per_frame {
                assert(it.count == cast,no_check(s64) device.frame_buffering, "It's illegal to change frame buffering for now.");
                it.count = cast,no_check(s64) device.frame_buffering;

                resetVulkanResourceMemoryPool(device, *it.*[device.frame_index]);
            }
    }
}

destroyVulkanResourceMemory :: (device : *VulkanDevice, memory : *VulkanResourceManager.Memory) {
    destroyPool :: (device : *VulkanDevice, memory_pool : *VulkanResourceManager.MemoryPool, pool : ResourceManager.Pool) {
        for * memory_pool.resources {
            warningMessage("% has not been freed", it.name);

            // @TODO: VkAllocationCallbacks
            #if memory.VulkanResource == {
                case VulkanBuffer;
                    vkDestroyBuffer(device.device, it.buffer, null);
                    it.buffer = VK_NULL_HANDLE;

                case VulkanTexture;
                    vkDestroyImageView(device.device, it.view, null);
                    it.view = VK_NULL_HANDLE;

                    vkDestroyImage(device.device, it.image, null);
                    it.image = VK_NULL_HANDLE;

                case;
                    #assert false, "Unhandled type";
            }
        }
        memory_pool.resources.count = 0;

        if memory_pool.device_memory {
            #if memory.VulkanResource == {
                case VulkanBuffer;  RESOURCE_KIND_NAME :: "Buffer";
                case VulkanTexture; RESOURCE_KIND_NAME :: "Texture";
                case;               #assert false, "Unhandled type";
            }

            warningMessage("%/% device memory has not been freed", RESOURCE_KIND_NAME, pool);

            // @TODO: VkAllocationCallbacks
            vkFreeMemory(device.device, memory_pool.device_memory, null);
            memory_pool.device_memory = VK_NULL_HANDLE;
        }

        destroySubarena(*memory_pool.names_subarena);
    }

    for * memory.persistent         destroyPool(device, it, cast(ResourceManager.Pool) it_index);
    for * memory.per_scene          destroyPool(device, it, cast(ResourceManager.Pool) it_index);
    for * memory.per_frame for * it destroyPool(device, it, cast(ResourceManager.Pool) it_index);
}

resetVulkanResourceMemoryPool :: (device : *VulkanDevice, memory_pool : *VulkanResourceManager.MemoryPool) {
    for * memory_pool.resources {
        // @TODO: VkAllocationCallbacks
        #if memory_pool.VulkanResource == {
            case VulkanBuffer;
                vkDestroyBuffer(device.device, it.buffer, null);
                it.buffer = VK_NULL_HANDLE;

            case VulkanTexture;
                vkDestroyImageView(device.device, it.view, null);
                it.view = VK_NULL_HANDLE;

                vkDestroyImage(device.device, it.image, null);
                it.image = VK_NULL_HANDLE;

            case;
                #assert false, "Unhandled type";
        }
    }
    memory_pool.resources.count = 0;

    if memory_pool.device_memory {
        // @TODO: VkAllocationCallbacks
        vkFreeMemory(device.device, memory_pool.device_memory, null);
        memory_pool.device_memory = VK_NULL_HANDLE;
    }

    resetArena(*memory_pool.names_subarena);
}

//
// Buffers
//

commitVulkanBufferMemory :: (
    device      : *VulkanDevice,
    memory_pool : *VulkanResourceManager.MemoryPool,
    lifetime    : ResourceManager.Lifetime,
    pool        : ResourceManager.Pool
) {
    assert(memory_pool.device_memory == VK_NULL_HANDLE);
    if memory_pool.resources.count <= 0 return;

    assert(pool == .DEFAULT); // @Incomplete, @Continue
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

    bind_infos    := pushToArena(*context.pet.per_frame_arena, VkBindBufferMemoryInfo, memory_pool.resources.count);
    bind_infos_it := bind_infos;

    memory_requirements_info : VkBufferMemoryRequirementsInfo2;
    memory_requirements      : VkMemoryRequirements2;
    memory_offset            : VkDeviceSize;

    for memory_pool.resources {
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
    debugCheckVK(vkAllocateMemory(device.device, *allocate_info, null, *memory_pool.device_memory));

    setVulkanObjectName(device, memory_pool.device_memory, "Memory/Buffers/%/%", lifetime, pool);

    bind_infos_it = bind_infos;
    for 0 .. memory_pool.resources.count - 1 {
        bind_infos_it.memory = memory_pool.device_memory;
        bind_infos_it += 1;
    }

    debugCheckVK(vkBindBufferMemory2(device.device, cast(u32) memory_pool.resources.count, bind_infos));

    // @TODO: #Views
}

//
// Textures
//

// @TODO: VkPhysicalDeviceVulkan11Properties::maxMemoryAllocationSize
commitVulkanTextureMemory :: (
    device      : *VulkanDevice,
    memory_pool : *VulkanResourceManager.MemoryPool,
    lifetime    : ResourceManager.Lifetime,
    pool        : ResourceManager.Pool
) {
    assert(memory_pool.device_memory == VK_NULL_HANDLE);
    if memory_pool.resources.count <= 0 return;

    assert(pool == .DEFAULT); // @Incomplete, @Continue
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

    bind_infos    := pushToArena(*context.pet.per_frame_arena, VkBindImageMemoryInfo, memory_pool.resources.count);
    bind_infos_it := bind_infos;

    memory_requirements_info : VkImageMemoryRequirementsInfo2;
    memory_requirements      : VkMemoryRequirements2;
    memory_offset            : VkDeviceSize;

    for memory_pool.resources {
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
    debugCheckVK(vkAllocateMemory(device.device, *allocate_info, null, *memory_pool.device_memory));

    setVulkanObjectName(device, memory_pool.device_memory, "Memory/Textures/%/%", lifetime, pool);

    bind_infos_it = bind_infos;
    for 0 .. memory_pool.resources.count - 1 {
        bind_infos_it.memory = memory_pool.device_memory;
        bind_infos_it += 1;
    }

    debugCheckVK(vkBindImageMemory2(device.device, cast(u32) memory_pool.resources.count, bind_infos));

    //
    // @Hardcoded: #Views.
    //    Views must be created to already bound images.
    //

    for * memory_pool.resources {
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
