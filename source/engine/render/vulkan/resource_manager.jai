// @TODO: #VulkanTexture.
//    - #Views. Image view(s) creation, maybe with usages to be more consistent with other graphics APIs.
//    - #SwapchainBuffers. Make a function for swapchain buffers initialization?
//    - #ResourceLayout. Rework resource layout changing mechanism. If we gonna compile our command buffers concurrently,
//      current tracking of current texture layout will not work.
//    - Use placement resources or something instead of freeing memory on reset. But we have to find a way to unbind resource memory.

VulkanResourceManager :: struct {
    #as using public_data : ResourceManager;

    MemoryPool :: struct(VulkanResource : Type, capacity : s64) {
        device_memory  : VkDeviceMemory;
        resources      : StaticArray(VulkanResource, capacity);
        names_subarena : Arena;
    }

    BufferMemory :: struct {
        Pools :: [POOLS_COUNT] MemoryPool(VulkanBuffer, MAX_BUFFERS);

        persistent : Pools;
        per_scene  : Pools;
        per_frame  : StaticArray(Pools, Device.MAX_FRAME_BUFFERING);
    }

    TextureMemory :: struct {
        Pool :: MemoryPool(VulkanTexture, MAX_TEXTURES);

        persistent : Pool;
        per_scene  : Pool;
        per_frame  : StaticArray(Pool, Device.MAX_FRAME_BUFFERING);
    }

    max_allocation_size : VkDeviceSize;
    memory_type_indices : [POOLS_COUNT] u32;

    buffers  : BufferMemory;
    textures : TextureMemory;

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

    manager.max_allocation_size = device.properties11.maxMemoryAllocationSize;

    builder : Basic.String_Builder;
    builder.allocator = Basic.temp;

    memory_heaps := toView(device.memory_properties.memoryProperties.memoryHeaps.data, device.memory_properties.memoryProperties.memoryHeapCount);

    #if PRINT_VERBOSE_MESSAGES {
        Basic.print(*builder, "Available memory heaps (%):\n", device.memory_properties.memoryProperties.memoryHeapCount);
        for memory_heaps {
            Basic.print(*builder, "    Size: % GB, Flags: %\n", bytesToGigaBytes(it.size), it.flags);
        }
        verboseMessage("%", Basic.builder_to_string(*builder,, allocator = Basic.temp), new_line = false);

        Basic.print(*builder, "Available memory types (%):\n", device.memory_properties.memoryProperties.memoryTypeCount);
        for toView(device.memory_properties.memoryProperties.memoryTypes.data, device.memory_properties.memoryProperties.memoryTypeCount) {
            heap := memory_heaps[it.heapIndex];
            Basic.print(*builder, "    [%]: Properties: %\n         Heap size: % GB\n         Heap flags: %\n",
                        it_index,
                        it.propertyFlags,
                        bytesToGigaBytes(heap.size),
                        heap.flags);
        }
        verboseMessage("%", Basic.builder_to_string(*builder,, allocator = Basic.temp), new_line = false);
    }

    fillMemoryTypeIndex(device, manager);

    Basic.print(*builder, "Pools memory types (%):\n", ResourceManager.POOLS_COUNT);
    for manager.memory_type_indices {
        memory_type := device.memory_properties.memoryProperties.memoryTypes[it];
        heap := memory_heaps[memory_type.heapIndex];
        Basic.print(*builder, "    %:\n        Properties: %\n        Heap size: % GB\n        Heap flags: %\n",
                    cast(ResourceManager.Pool) it_index,
                    memory_type.propertyFlags,
                    bytesToGigaBytes(heap.size),
                    heap.flags);
    }
    infoMessage("%", Basic.builder_to_string(*builder,, allocator = Basic.temp), new_line = false);

    BUFFERS_SUBARENA_CAPACITY  :: ResourceManager.MAX_BUFFERS  * ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH;
    TEXTURES_SUBARENA_CAPACITY :: ResourceManager.MAX_TEXTURES * ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH;
    MANAGER_ARENA_CAPACITY     :: (2 + Device.MAX_FRAME_BUFFERING)
                                * (ResourceManager.POOLS_COUNT * BUFFERS_SUBARENA_CAPACITY + TEXTURES_SUBARENA_CAPACITY);

    createArena(*manager.names_arena, MANAGER_ARENA_CAPACITY, "VulkanResourceManager names");

    createVulkanBufferMemoryNamesSubarenas(*manager.buffers,   *manager.names_arena, BUFFERS_SUBARENA_CAPACITY,  device.frame_buffering);
    createVulkanTextureMemoryNamesSubarenas(*manager.textures, *manager.names_arena, TEXTURES_SUBARENA_CAPACITY, device.frame_buffering);

    return manager;
}

#scope_file

destroyVulkanResourceManager :: (device_ : *Device, manager_ : *ResourceManager) {
    device  := cast(*VulkanDevice)          device_;
    manager := cast(*VulkanResourceManager) manager_;

    destroyVulkanBufferMemory(device, *manager.buffers);
    destroyVulkanTextureMemory(device, *manager.textures);

    destroyArena(*manager.names_arena);
}

commitVulkanResourceMemory :: (device_ : *Device, manager_ : *ResourceManager, lifetime : ResourceManager.Lifetime) {
    device  := cast(*VulkanDevice)          device_;
    manager := cast(*VulkanResourceManager) manager_;

    if #complete lifetime == {
        case .PERSISTENT;
            for * manager.buffers.persistent {
                commitVulkanBufferMemory(device, manager, it, lifetime, cast(ResourceManager.Pool) it_index);
            }
            commitVulkanTextureMemory(device, manager, *manager.textures.persistent, lifetime);

        case .PER_SCENE;
            for * manager.buffers.per_scene {
                commitVulkanBufferMemory(device, manager, it, lifetime, cast(ResourceManager.Pool) it_index);
            }
            commitVulkanTextureMemory(device, manager, *manager.textures.per_scene, lifetime);

        case .PER_FRAME;
            for * manager.buffers.per_frame[device.frame_index] {
                commitVulkanBufferMemory(device, manager, it, lifetime, cast(ResourceManager.Pool) it_index);
            }
            commitVulkanTextureMemory(device, manager, *manager.textures.per_frame[device.frame_index], lifetime);
    }
}

resetVulkanResourceMemory :: (device_ : *Device, manager_ : *ResourceManager, lifetime : ResourceManager.Lifetime) {
    device  := cast(*VulkanDevice)          device_;
    manager := cast(*VulkanResourceManager) manager_;

    if #complete lifetime == {
        case .PERSISTENT;
            for * manager.buffers.persistent resetVulkanResourceMemoryPool(device, it);
            resetVulkanResourceMemoryPool(device, *manager.textures.persistent);

        case .PER_SCENE;
            for * manager.buffers.per_scene resetVulkanResourceMemoryPool(device, it);
            resetVulkanResourceMemoryPool(device, *manager.textures.per_scene);

        case .PER_FRAME;
            // @TODO: #PerFrameTextures. #PerFrameBuffers. #FrameBuffering.
            //    - If manager.*.per_frame.count < device.frame_buffering then allocate new memory memory
            //    - If manager.*.per_frame.count > device.frame_buffering then free unusused memory

            assert(manager.buffers.per_frame.count  == cast,no_check(s64) device.frame_buffering, "It's illegal to change frame buffering for now.");
            assert(manager.textures.per_frame.count == cast,no_check(s64) device.frame_buffering, "It's illegal to change frame buffering for now.");

            manager.buffers.per_frame.count  = cast,no_check(s64) device.frame_buffering;
            manager.textures.per_frame.count = cast,no_check(s64) device.frame_buffering;

            for * manager.buffers.per_frame[device.frame_index] {
                resetVulkanResourceMemoryPool(device, it);
            }
            resetVulkanResourceMemoryPool(device, *manager.textures.per_frame[device.frame_index]);
    }
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

createVulkanBufferMemoryNamesSubarenas :: (
    memory            : *VulkanResourceManager.BufferMemory,
    arena             : *Arena,
    subarena_capacity : s64,
    frames_buffering  : FrameBuffering
) {
    for * memory.persistent {
        createSubarena(arena, *it.names_subarena, subarena_capacity, "Buffers/Persistent/%", cast(ResourceManager.Pool) it_index);
    }

    for * memory.per_scene {
        createSubarena(arena, *it.names_subarena, subarena_capacity, "Buffers/Per scene/%", cast(ResourceManager.Pool) it_index);
    }

    memory.per_frame.count = memory.per_frame.capacity;
    for * frame_pools, frame_index : memory.per_frame {
        for * frame_pools.* {
            createSubarena(arena, *it.names_subarena, subarena_capacity, "Buffers/Frame #%/%", frame_index, cast(ResourceManager.Pool) it_index);
        }
    }
    memory.per_frame.count = cast,no_check(s64) frames_buffering;
}

destroyVulkanBufferMemory :: (device : *VulkanDevice, memory : *VulkanResourceManager.BufferMemory) {
    destroyPool :: (
        device      : *VulkanDevice,
        memory_pool : *VulkanResourceManager.MemoryPool(VulkanBuffer, ResourceManager.MAX_BUFFERS),
        lifetime    : ResourceManager.Lifetime,
        pool        : ResourceManager.Pool,
        frame_index : u8 = 0
    ) {
        for * memory_pool.resources {
            warningMessage("% has not been freed", it.name);

            // @TODO: VkAllocationCallbacks
            vkDestroyBuffer(device.device, it.buffer, null);
            it.buffer = VK_NULL_HANDLE;
        }
        memory_pool.resources.count = 0;

        if memory_pool.device_memory {
            if lifetime == .PER_FRAME {
                assert(0 <= frame_index && frame_index <= Device.MAX_FRAME_BUFFERING);
                warningMessage("Buffers/Frame #%/% device memory has not been freed", frame_index, pool);
            } else {
                warningMessage("Buffers/%/% device memory has not been freed", lifetime, pool);
            }

            // @TODO: VkAllocationCallbacks
            vkFreeMemory(device.device, memory_pool.device_memory, null);
            memory_pool.device_memory = VK_NULL_HANDLE;
        }

        destroySubarena(*memory_pool.names_subarena);
    }

    for * memory.persistent {
        destroyPool(device, it, .PERSISTENT, cast(ResourceManager.Pool) it_index);
    }

    for * memory.per_scene  {
        destroyPool(device, it, .PER_SCENE, cast(ResourceManager.Pool) it_index);
    }

    memory.per_frame.count = memory.per_frame.capacity;
    for * frame_pools, frame_index : memory.per_frame {
        for * frame_pools.* {
            destroyPool(device, it, .PER_FRAME, cast(ResourceManager.Pool) it_index, cast(u8) frame_index);
        }
    }
    memory.per_frame.count = 0;
}

commitVulkanBufferMemory :: (
    device      : *VulkanDevice,
    manager     : *VulkanResourceManager,
    memory_pool : *VulkanResourceManager.MemoryPool,
    lifetime    : ResourceManager.Lifetime,
    pool        : ResourceManager.Pool
) {
    assert(memory_pool.device_memory == VK_NULL_HANDLE);
    if memory_pool.resources.count <= 0 return;

    allocate_info := VkMemoryAllocateInfo.{
        allocationSize  = 0, // Will be set in the loop
        memoryTypeIndex = manager.memory_type_indices[pool]
    };

    bind_infos    := pushToArena(*context.pet.per_frame_arena, VkBindBufferMemoryInfo, memory_pool.resources.count);
    bind_infos_it := bind_infos;

    memory_requirements_info : VkBufferMemoryRequirementsInfo2;
    memory_requirements      : VkMemoryRequirements2;

    for memory_pool.resources {
        bind_infos_it.buffer       = it.buffer;
        bind_infos_it.memoryOffset = allocate_info.allocationSize;

        memory_requirements_info.buffer = it.buffer;
        vkGetBufferMemoryRequirements2(device.device, *memory_requirements_info, *memory_requirements);

        requirements := *memory_requirements.memoryRequirements;
        allocate_info.allocationSize += alignUpWithPowerOfTwo(requirements.size, requirements.alignment);

        bind_infos_it += 1;
    }

    if allocate_info.allocationSize > manager.max_allocation_size {
        if lifetime == .PER_FRAME {
            assertMessage("Buffers/Frame #%/% memory pool allocation size (% MB) exceeds maximum allowed allocation size: % MB",
                          device.frame_index,
                          pool,
                          bytesToMegaBytes(allocate_info.allocationSize),
                          bytesToMegaBytes(manager.max_allocation_size));
        } else {
            assertMessage("Buffers/%/% memory pool allocation size (% MB) exceeds maximum allowed allocation size: % MB",
                          lifetime,
                          pool,
                          bytesToMegaBytes(allocate_info.allocationSize),
                          bytesToMegaBytes(manager.max_allocation_size));
        }
    }

    // @TODO: VkAllocationCallbacks
    debugCheckVK(vkAllocateMemory(device.device, *allocate_info, null, *memory_pool.device_memory));

    if lifetime == .PER_FRAME {
        setVulkanObjectName(device, memory_pool.device_memory, "Memory/Buffers/Frame #%/%", device.frame_index, pool);
    } else {
        setVulkanObjectName(device, memory_pool.device_memory, "Memory/Buffers/%/%", lifetime, pool);
    }

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

createVulkanTextureMemoryNamesSubarenas :: (
    memory            : *VulkanResourceManager.TextureMemory,
    arena             : *Arena,
    subarena_capacity : s64,
    frames_buffering  : FrameBuffering
) {
    createSubarena(arena, *memory.persistent.names_subarena, subarena_capacity, "Textures/Persistent");
    createSubarena(arena, *memory.per_scene.names_subarena, subarena_capacity, "Textures/Per scene");

    memory.per_frame.count = memory.per_frame.capacity;
    for * memory.per_frame {
        createSubarena(arena, *it.names_subarena, subarena_capacity, "Textures/Frame #%", it_index);
    }
    memory.per_frame.count = cast,no_check(s64) frames_buffering;
}

destroyVulkanTextureMemory :: (device : *VulkanDevice, memory : *VulkanResourceManager.TextureMemory) {
    destroyPool :: (
        device      : *VulkanDevice,
        memory_pool : *VulkanResourceManager.MemoryPool(VulkanTexture, ResourceManager.MAX_TEXTURES),
        lifetime    : ResourceManager.Lifetime,
        frame_index : u8 = 0
    ) {
        for * memory_pool.resources {
            warningMessage("% has not been freed", it.name);

            // @TODO: VkAllocationCallbacks
            vkDestroyImageView(device.device, it.view, null);
            it.view = VK_NULL_HANDLE;

            // @TODO: VkAllocationCallbacks
            vkDestroyImage(device.device, it.image, null);
            it.image = VK_NULL_HANDLE;
        }
        memory_pool.resources.count = 0;

        if memory_pool.device_memory {
            if lifetime == .PER_FRAME {
                assert(0 <= frame_index && frame_index <= Device.MAX_FRAME_BUFFERING);
                warningMessage("Textures/Frame #% device memory has not been freed", frame_index);
            } else {
                warningMessage("Textures/% device memory has not been freed", lifetime);
            }

            // @TODO: VkAllocationCallbacks
            vkFreeMemory(device.device, memory_pool.device_memory, null);
            memory_pool.device_memory = VK_NULL_HANDLE;
        }

        destroySubarena(*memory_pool.names_subarena);
    }

    destroyPool(device, *memory.persistent, .PERSISTENT);
    destroyPool(device, *memory.per_scene, .PER_SCENE);
    memory.per_frame.count = memory.per_frame.capacity;
    for * memory.per_frame {
        destroyPool(device, it, .PER_FRAME, cast(u8) it_index);
    }
    memory.per_frame.count = 0;
}

commitVulkanTextureMemory :: (
    device      : *VulkanDevice,
    manager     : *VulkanResourceManager,
    memory_pool : *VulkanResourceManager.MemoryPool,
    lifetime    : ResourceManager.Lifetime
) {
    assert(memory_pool.device_memory == VK_NULL_HANDLE);
    if memory_pool.resources.count <= 0 return;

    allocate_info := VkMemoryAllocateInfo.{
        allocationSize  = 0, // Will be set in the loop
        memoryTypeIndex = manager.memory_type_indices[ResourceManager.Pool.DEFAULT]
    };

    bind_infos    := pushToArena(*context.pet.per_frame_arena, VkBindImageMemoryInfo, memory_pool.resources.count);
    bind_infos_it := bind_infos;

    memory_requirements_info : VkImageMemoryRequirementsInfo2;
    memory_requirements      : VkMemoryRequirements2;

    for memory_pool.resources {
        bind_infos_it.image        = it.image;
        bind_infos_it.memoryOffset = allocate_info.allocationSize;

        memory_requirements_info.image = it.image;
        vkGetImageMemoryRequirements2(device.device, *memory_requirements_info, *memory_requirements);

        requirements := *memory_requirements.memoryRequirements;
        allocate_info.allocationSize += alignUpWithPowerOfTwo(requirements.size, requirements.alignment);

        bind_infos_it += 1;
    }

    if allocate_info.allocationSize > manager.max_allocation_size {
        if lifetime == .PER_FRAME {
            assertMessage("Textures/Frame #% memory pool allocation size (% MB) exceeds maximum allowed allocation size: % MB",
                          device.frame_index,
                          bytesToMegaBytes(allocate_info.allocationSize),
                          bytesToMegaBytes(manager.max_allocation_size));
        } else {
            assertMessage("Textures/% memory pool allocation size (% MB) exceeds maximum allowed allocation size: % MB",
                          lifetime,
                          bytesToMegaBytes(allocate_info.allocationSize),
                          bytesToMegaBytes(manager.max_allocation_size));
        }
    }

    // @TODO: VkAllocationCallbacks
    debugCheckVK(vkAllocateMemory(device.device, *allocate_info, null, *memory_pool.device_memory));

    if lifetime == .PER_FRAME {
        setVulkanObjectName(device, memory_pool.device_memory, "Memory/Textures/Frame #%", device.frame_index);
    } else {
        setVulkanObjectName(device, memory_pool.device_memory, "Memory/Textures/%", lifetime);
    }

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

//
// Other
//

fillMemoryTypeIndex :: (device : *VulkanDevice, manager : *VulkanResourceManager) {
    // [0] - ideal
    // [1] - minimal
    MEMORY_PROPERTIES : [ResourceManager.POOLS_COUNT][2] VkMemoryPropertyFlags : .[
        .[
            .VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            .VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
        ], .[
            .VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | .VK_MEMORY_PROPERTY_HOST_COHERENT_BIT | .VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            .VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | .VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
        ], .[
            .VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | .VK_MEMORY_PROPERTY_HOST_COHERENT_BIT | .VK_MEMORY_PROPERTY_HOST_CACHED_BIT,
            .VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | .VK_MEMORY_PROPERTY_HOST_COHERENT_BIT | .VK_MEMORY_PROPERTY_HOST_CACHED_BIT
        ]
    ];

    memory_types := toView(device.memory_properties.memoryProperties.memoryTypes.data, device.memory_properties.memoryProperties.memoryTypeCount);

    for pool_properties, pool_index : MEMORY_PROPERTIES {
        manager.memory_type_indices[pool_index] = 0xFFFF_FFFF;

        for properties : pool_properties {
            for memory_types {
                if (it.propertyFlags & properties) == properties {
                    manager.memory_type_indices[pool_index] = cast(u32) it_index;
                    break properties;
                }
            }
        }

        assert(manager.memory_type_indices[pool_index] != 0xFFFF_FFFF, "Device local memory is not supported on this device");
    }
}
