// @TODO:
//    - #SwapchainBuffers. Make a function for swapchain buffers initialization?
//    - #ResourceLayout. Rework resource layout changing mechanism. If we gonna compile our command buffers concurrently,
//      current tracking of current texture layout will not work.
//    - Use reserved resources or something instead of freeing memory on reset. Use sparce bindings maybe?
//    - #RobustAccess. Robust buffer and image access
//    - #MTRendering. Thread safety for memory pools and name arenas.

VulkanResourceManager :: struct {
    #as using public_data : ResourceManager;

    MAX_DESCRIPTOR_BUFFERS :: Device.MAX_FRAME_BUFFERING;

    MemoryPool :: struct(VulkanResource : Type, capacity : s64) {
        device_memory  : VkDeviceMemory;
        resources      : StaticArray(VulkanResource, capacity);
        names_subarena : Arena;
    }

    MemorylessPool :: struct(VulkanResource : Type, capacity : s64) {
        resources      : StaticArray(VulkanResource, capacity);
        names_subarena : Arena;
    }

    BufferMemory :: struct {
        Pool  :: MemoryPool(VulkanBuffer, MAX_BUFFERS);
        Pools :: [POOLS_COUNT] Pool;

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

    TextureViewMemory :: struct {
        Pool :: MemorylessPool(VulkanTextureView, MAX_TEXTURE_VIEWS);

        persistent : Pool;
        per_scene  : Pool;
        per_frame  : StaticArray(Pool, Device.MAX_FRAME_BUFFERING);
    }

    SamplerMemory :: struct {
        Pool :: MemorylessPool(VulkanSampler, MAX_SAMPLERS);

        persistent : Pool;
        per_scene  : Pool;
        per_frame  : StaticArray(Pool, Device.MAX_FRAME_BUFFERING);
    }

    DescriptorBufferMemory :: struct {
        Pool :: MemoryPool(VulkanBuffer, MAX_DESCRIPTOR_BUFFERS);

        persistent : Pool;
    }

    memory_type_indices : [POOLS_COUNT] u32;

    buffers            : BufferMemory;
    textures           : TextureMemory;
    texture_views      : TextureViewMemory;
    samplers           : SamplerMemory;
    descriptor_buffers : DescriptorBufferMemory;

    names_arena : Arena;
}

createVulkanResourceManager :: (device : *VulkanDevice) -> *VulkanResourceManager #must {
    manager := pushToArena(*context.pet.persistent_arena, VulkanResourceManager);

    #insert -> string { return generatePlatformVtableInitialization(ResourceManager, "manager", "Vulkan"); }

    builder := Basic.String_Builder.{ allocator = Basic.temp };

    memory_heaps := toView(device.memory_properties.memoryProperties.memoryHeaps.data, device.memory_properties.memoryProperties.memoryHeapCount);

    #if PRINT_VERBOSE_MESSAGES {
        Basic.print(*builder, "Available memory heaps (%):\n", device.memory_properties.memoryProperties.memoryHeapCount);
        for memory_heaps {
            Basic.print(*builder, "    Size: % GB, Flags: %\n", bytesToGigaBytes(it.size), it.flags);
        }
        verboseMessage("%", Basic.builder_to_string(*builder,, allocator = Basic.temp));

        Basic.print(*builder, "Available memory types (%):\n", device.memory_properties.memoryProperties.memoryTypeCount);
        for toView(device.memory_properties.memoryProperties.memoryTypes.data, device.memory_properties.memoryProperties.memoryTypeCount) {
            heap := memory_heaps[it.heapIndex];
            Basic.print(*builder, "    [%]: Properties: %\n         Heap size: % GB\n         Heap flags: %\n",
                        it_index,
                        it.propertyFlags,
                        bytesToGigaBytes(heap.size),
                        heap.flags);
        }
        verboseMessage("%", Basic.builder_to_string(*builder,, allocator = Basic.temp));
    }

    fillMemoryTypeIndices(device, manager);

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
    infoMessage("%", Basic.builder_to_string(*builder,, allocator = Basic.temp));

    BUFFERS_SUBARENA_CAPACITY            :: ResourceManager.MAX_BUFFERS                  * ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH;
    TEXTURES_SUBARENA_CAPACITY           :: ResourceManager.MAX_TEXTURES                 * ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH;
    TEXTURE_VIEWS_SUBARENA_CAPACITY      :: ResourceManager.MAX_TEXTURE_VIEWS            * ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH;
    SAMPLERS_SUBARENA_CAPACITY           :: ResourceManager.MAX_SAMPLERS                 * ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH;
    DESCRIPTOR_BUFFERS_SUBARENA_CAPACITY :: VulkanResourceManager.MAX_DESCRIPTOR_BUFFERS * ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH;
    MANAGER_ARENA_CAPACITY               :: BUFFERS_SUBARENA_CAPACITY       * (2 + Device.MAX_FRAME_BUFFERING) * ResourceManager.POOLS_COUNT
                                          + TEXTURES_SUBARENA_CAPACITY      * (2 + Device.MAX_FRAME_BUFFERING)
                                          + TEXTURE_VIEWS_SUBARENA_CAPACITY * (2 + Device.MAX_FRAME_BUFFERING)
                                          + SAMPLERS_SUBARENA_CAPACITY      * (2 + Device.MAX_FRAME_BUFFERING)
                                          + DESCRIPTOR_BUFFERS_SUBARENA_CAPACITY;

    createArena(*manager.names_arena, MANAGER_ARENA_CAPACITY, "VulkanResourceManager names");

    createVulkanBufferMemoryNamesSubarenas(*manager.buffers, *manager.names_arena, BUFFERS_SUBARENA_CAPACITY, device.frame_buffering);
    createVulkanTextureMemoryNamesSubarenas(*manager.textures, *manager.names_arena, TEXTURES_SUBARENA_CAPACITY, device.frame_buffering);
    createVulkanTextureViewMemoryNamesSubarenas(*manager.texture_views, *manager.names_arena, TEXTURE_VIEWS_SUBARENA_CAPACITY, device.frame_buffering);
    createVulkanSamplerMemoryNamesSubarenas(*manager.samplers, *manager.names_arena, SAMPLERS_SUBARENA_CAPACITY, device.frame_buffering);
    createVulkanDescriptorBufferMemoryNamesSubarenas(*manager.descriptor_buffers, *manager.names_arena, DESCRIPTOR_BUFFERS_SUBARENA_CAPACITY, device.frame_buffering);

    return manager;
}

#scope_file

destroyVulkanResourceManager :: (device_ : *Device, manager_ : *ResourceManager) {
    device  := cast(*VulkanDevice)          device_;
    manager := cast(*VulkanResourceManager) manager_;

    destroyVulkanBufferMemory(device, *manager.buffers);
    destroyVulkanTextureMemory(device, *manager.textures);
    destroyVulkanTextureViewMemory(device, *manager.texture_views);
    destroyVulkanSamplerMemory(device, *manager.samplers);
    destroyVulkanDescriptorBufferMemory(device, *manager.descriptor_buffers);

    destroyArena(*manager.names_arena);
}

commitVulkanResourceMemory :: (device_ : *Device, manager_ : *ResourceManager, lifetime : ResourceManager.Lifetime) {
    device  := cast(*VulkanDevice)          device_;
    manager := cast(*VulkanResourceManager) manager_;

    if #complete lifetime == {
        case .PERSISTENT;
            for * manager.buffers.persistent {
                commitVulkanBufferMemoryPool(device, manager, it, lifetime, cast(ResourceManager.Pool) it_index);
            }
            commitVulkanTextureMemoryPool(device, manager, *manager.textures.persistent, lifetime);
            commitVulkanDescriptorBufferMemoryPool(device, manager, *manager.descriptor_buffers.persistent);

        case .PER_SCENE;
            for * manager.buffers.per_scene {
                commitVulkanBufferMemoryPool(device, manager, it, lifetime, cast(ResourceManager.Pool) it_index);
            }
            commitVulkanTextureMemoryPool(device, manager, *manager.textures.per_scene, lifetime);

        case .PER_FRAME;
            for * manager.buffers.per_frame[device.frame_index] {
                commitVulkanBufferMemoryPool(device, manager, it, lifetime, cast(ResourceManager.Pool) it_index);
            }
            commitVulkanTextureMemoryPool(device, manager, *manager.textures.per_frame[device.frame_index], lifetime);
    }
}

resetVulkanResourceMemory :: (device_ : *Device, manager_ : *ResourceManager, lifetime : ResourceManager.Lifetime) {
    device  := cast(*VulkanDevice)          device_;
    manager := cast(*VulkanResourceManager) manager_;

    if #complete lifetime == {
        case .PERSISTENT;
            for * manager.buffers.persistent resetVulkanBufferMemoryPool(device, it, cast(ResourceManager.Pool) it_index);
            resetVulkanTextureMemoryPool(device, *manager.textures.persistent);
            resetVulkanTextureViewMemoryPool(device, *manager.texture_views.persistent);
            resetVulkanSamplerMemoryPool(device, *manager.samplers.persistent);
            resetVulkanDescriptorBufferMemoryPool(device, *manager.descriptor_buffers.persistent);

        case .PER_SCENE;
            for * manager.buffers.per_scene resetVulkanBufferMemoryPool(device, it, cast(ResourceManager.Pool) it_index);
            resetVulkanTextureMemoryPool(device, *manager.textures.per_scene);
            resetVulkanTextureViewMemoryPool(device, *manager.texture_views.per_scene);
            resetVulkanSamplerMemoryPool(device, *manager.samplers.per_scene);

        case .PER_FRAME;
            // @TODO: #PerFrameTextures. #PerFrameBuffers. #FrameBuffering.
            //    - If manager.*.per_frame.count < device.frame_buffering then allocate new memory
            //    - If manager.*.per_frame.count > device.frame_buffering then free unusused memory

            assert(manager.buffers.per_frame.count       == cast,no_check(s64) device.frame_buffering, "It's illegal to change frame buffering for now");
            assert(manager.textures.per_frame.count      == cast,no_check(s64) device.frame_buffering, "It's illegal to change frame buffering for now");
            assert(manager.texture_views.per_frame.count == cast,no_check(s64) device.frame_buffering, "It's illegal to change frame buffering for now");
            assert(manager.samplers.per_frame.count      == cast,no_check(s64) device.frame_buffering, "It's illegal to change frame buffering for now");

            manager.buffers.per_frame.count       = cast,no_check(s64) device.frame_buffering;
            manager.textures.per_frame.count      = cast,no_check(s64) device.frame_buffering;
            manager.texture_views.per_frame.count = cast,no_check(s64) device.frame_buffering;
            manager.samplers.per_frame.count      = cast,no_check(s64) device.frame_buffering;

            for * manager.buffers.per_frame[device.frame_index] {
                resetVulkanBufferMemoryPool(device, it, cast(ResourceManager.Pool) it_index);
            }
            resetVulkanTextureMemoryPool(device, *manager.textures.per_frame[device.frame_index]);
            resetVulkanTextureViewMemoryPool(device, *manager.texture_views.per_frame[device.frame_index]);
            resetVulkanSamplerMemoryPool(device, *manager.samplers.per_frame[device.frame_index]);
    }
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

    memory.per_frame.count = cast,no_check(s64) frames_buffering;
    for * frame_pools, frame_index : memory.per_frame.data {
        for * frame_pools.* {
            createSubarena(arena, *it.names_subarena, subarena_capacity, "Buffers/Frame #%/%", frame_index, cast(ResourceManager.Pool) it_index);
        }
    }
}

destroyVulkanBufferMemory :: (device : *VulkanDevice, memory : *VulkanResourceManager.BufferMemory) {
    for * memory.persistent {
        assert(it.device_memory == VK_NULL_HANDLE);
        assert(it.resources.count == 0);
        destroySubarena(*it.names_subarena);
    }

    for * memory.per_scene  {
        assert(it.device_memory == VK_NULL_HANDLE);
        assert(it.resources.count == 0);
        destroySubarena(*it.names_subarena);
    }

    memory.per_frame.count = 0;
    for * memory.per_frame.data {
        for * it.* {
            assert(it.device_memory == VK_NULL_HANDLE);
            assert(it.resources.count == 0);
            destroySubarena(*it.names_subarena);
        }
    }
}

resetVulkanBufferMemoryPool :: (
    device      : *VulkanDevice,
    memory_pool : *VulkanResourceManager.MemoryPool,
    pool        : ResourceManager.Pool
) {
    for * memory_pool.resources {
        it.mapped_memory = null;

        vkDestroyBuffer(device.device, it.buffer, null);
        it.buffer = VK_NULL_HANDLE;
    }
    reset(*memory_pool.resources);

    if memory_pool.device_memory {
        if pool != .DEFAULT {
            vkUnmapMemory(device.device, memory_pool.device_memory);
        }

        vkFreeMemory(device.device, memory_pool.device_memory, null);
        memory_pool.device_memory = VK_NULL_HANDLE;
    }

    resetArena(*memory_pool.names_subarena);
}

commitVulkanBufferMemoryPool :: (
    device      : *VulkanDevice,
    manager     : *VulkanResourceManager,
    memory_pool : *VulkanResourceManager.MemoryPool,
    lifetime    : ResourceManager.Lifetime,
    pool        : ResourceManager.Pool
) {
    assert(memory_pool.device_memory == VK_NULL_HANDLE);
    if memory_pool.resources.count <= 0 return;

    allocate_flags_info := VkMemoryAllocateFlagsInfo.{
        flags = .VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT
    };

    allocate_info := VkMemoryAllocateInfo.{
        pNext           = *allocate_flags_info,
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

    if allocate_info.allocationSize > device.properties11.maxMemoryAllocationSize {
        if lifetime == .PER_FRAME {
            assertMessage("Buffers/Frame #%/% memory pool allocation size (% MB) exceeds maximum allowed allocation size: % MB",
                          device.frame_index,
                          pool,
                          bytesToMegaBytes(allocate_info.allocationSize),
                          bytesToMegaBytes(device.properties11.maxMemoryAllocationSize));
        } else {
            assertMessage("Buffers/%/% memory pool allocation size (% MB) exceeds maximum allowed allocation size: % MB",
                          lifetime,
                          pool,
                          bytesToMegaBytes(allocate_info.allocationSize),
                          bytesToMegaBytes(device.properties11.maxMemoryAllocationSize));
        }
    }

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

    if pool != .DEFAULT {
        mapped_device_memory : *void;
        debugCheckVK(vkMapMemory(device.device, memory_pool.device_memory, 0, VK_WHOLE_SIZE, 0, *mapped_device_memory));
        assert(mapped_device_memory);

        bind_infos_it = bind_infos;
        for * memory_pool.resources {
            assert(!it.mapped_memory);
            it.mapped_memory = mapped_device_memory + cast(u64) bind_infos_it.memoryOffset;

            info := VkBufferDeviceAddressInfo.{ buffer = it.buffer };
            it.device_address = cast(u64) vkGetBufferDeviceAddress(device.device, *info);
            assert(it.device_address);

            bind_infos_it += 1;
        }
    } else {
        for * memory_pool.resources {
            info := VkBufferDeviceAddressInfo.{ buffer = it.buffer };
            it.device_address = cast(u64) vkGetBufferDeviceAddress(device.device, *info);
            assert(it.device_address);
        }
    }
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

    memory.per_frame.count = cast,no_check(s64) frames_buffering;
    for * memory.per_frame.data {
        createSubarena(arena, *it.names_subarena, subarena_capacity, "Textures/Frame #%", it_index);
    }
}

destroyVulkanTextureMemory :: (device : *VulkanDevice, memory : *VulkanResourceManager.TextureMemory) {
    assert(memory.persistent.device_memory == VK_NULL_HANDLE);
    assert(memory.persistent.resources.count == 0);
    destroySubarena(*memory.persistent.names_subarena);

    assert(memory.per_scene.device_memory == VK_NULL_HANDLE);
    assert(memory.per_scene.resources.count == 0);
    destroySubarena(*memory.per_scene.names_subarena);

    memory.per_frame.count = 0;
    for * memory.per_frame.data {
        assert(it.device_memory == VK_NULL_HANDLE);
        assert(it.resources.count == 0);
        destroySubarena(*it.names_subarena);
    }
}

resetVulkanTextureMemoryPool :: (device : *VulkanDevice, memory_pool : *VulkanResourceManager.MemoryPool) {
    for * memory_pool.resources {
        vkDestroyImage(device.device, it.image, null);
        it.image = VK_NULL_HANDLE;
    }
    reset(*memory_pool.resources);

    if memory_pool.device_memory {
        vkFreeMemory(device.device, memory_pool.device_memory, null);
        memory_pool.device_memory = VK_NULL_HANDLE;
    }

    resetArena(*memory_pool.names_subarena);
}

commitVulkanTextureMemoryPool :: (
    device      : *VulkanDevice,
    manager     : *VulkanResourceManager,
    memory_pool : *VulkanResourceManager.MemoryPool,
    lifetime    : ResourceManager.Lifetime
) {
    assert(memory_pool.device_memory == VK_NULL_HANDLE);
    if memory_pool.resources.count <= 0 return;

    allocate_info := VkMemoryAllocateInfo.{
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

    if allocate_info.allocationSize > device.properties11.maxMemoryAllocationSize {
        if lifetime == .PER_FRAME {
            assertMessage("Textures/Frame #% memory pool allocation size (% MB) exceeds maximum allowed allocation size: % MB",
                          device.frame_index,
                          bytesToMegaBytes(allocate_info.allocationSize),
                          bytesToMegaBytes(device.properties11.maxMemoryAllocationSize));
        } else {
            assertMessage("Textures/% memory pool allocation size (% MB) exceeds maximum allowed allocation size: % MB",
                          lifetime,
                          bytesToMegaBytes(allocate_info.allocationSize),
                          bytesToMegaBytes(device.properties11.maxMemoryAllocationSize));
        }
    }

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
}

//
// Texture views
//

createVulkanTextureViewMemoryNamesSubarenas :: (
    memory            : *VulkanResourceManager.TextureViewMemory,
    arena             : *Arena,
    subarena_capacity : s64,
    frames_buffering  : FrameBuffering
) {
    createSubarena(arena, *memory.persistent.names_subarena, subarena_capacity, "Texture views/Persistent");
    createSubarena(arena, *memory.per_scene.names_subarena, subarena_capacity, "Texture views/Per scene");

    memory.per_frame.count = cast,no_check(s64) frames_buffering;
    for * memory.per_frame.data {
        createSubarena(arena, *it.names_subarena, subarena_capacity, "Texture views/Frame #%", it_index);
    }
}

destroyVulkanTextureViewMemory :: (device : *VulkanDevice, memory : *VulkanResourceManager.TextureViewMemory) {
    assert(memory.persistent.resources.count == 0);
    destroySubarena(*memory.persistent.names_subarena);

    assert(memory.per_scene.resources.count == 0);
    destroySubarena(*memory.per_scene.names_subarena);

    memory.per_frame.count = 0;
    for * memory.per_frame.data {
        assert(it.resources.count == 0);
        destroySubarena(*it.names_subarena);
    }
}

resetVulkanTextureViewMemoryPool :: (device : *VulkanDevice, memory_pool : *VulkanResourceManager.MemorylessPool) {
    for * memory_pool.resources {
        vkDestroyImageView(device.device, it.view, null);
        it.view = VK_NULL_HANDLE;
    }
    reset(*memory_pool.resources);

    resetArena(*memory_pool.names_subarena);
}

//
// Samplers
//

createVulkanSamplerMemoryNamesSubarenas :: (
    memory            : *VulkanResourceManager.SamplerMemory,
    arena             : *Arena,
    subarena_capacity : s64,
    frames_buffering  : FrameBuffering
) {
    createSubarena(arena, *memory.persistent.names_subarena, subarena_capacity, "Samplers/Persistent");
    createSubarena(arena, *memory.per_scene.names_subarena, subarena_capacity, "Samplers/Per scene");

    memory.per_frame.count = cast,no_check(s64) frames_buffering;
    for * memory.per_frame.data {
        createSubarena(arena, *it.names_subarena, subarena_capacity, "Samplers/Frame #%", it_index);
    }
}

destroyVulkanSamplerMemory :: (device : *VulkanDevice, memory : *VulkanResourceManager.SamplerMemory) {
    assert(memory.persistent.resources.count == 0);
    destroySubarena(*memory.persistent.names_subarena);

    assert(memory.per_scene.resources.count == 0);
    destroySubarena(*memory.per_scene.names_subarena);

    memory.per_frame.count = 0;
    for * memory.per_frame.data {
        assert(it.resources.count == 0);
        destroySubarena(*it.names_subarena);
    }
}

resetVulkanSamplerMemoryPool :: (device : *VulkanDevice, memory_pool : *VulkanResourceManager.MemorylessPool) {
    for * memory_pool.resources {
        vkDestroySampler(device.device, it.sampler, null);
        it.sampler = VK_NULL_HANDLE;
    }
    reset(*memory_pool.resources);

    resetArena(*memory_pool.names_subarena);
}

//
// Descriptor buffers
//

createVulkanDescriptorBufferMemoryNamesSubarenas :: inline (
    memory            : *VulkanResourceManager.DescriptorBufferMemory,
    arena             : *Arena,
    subarena_capacity : s64,
    frames_buffering  : FrameBuffering
) {
    createSubarena(arena, *memory.persistent.names_subarena, subarena_capacity, "Descriptor buffers/Persistent");
}

destroyVulkanDescriptorBufferMemory :: (device : *VulkanDevice, memory : *VulkanResourceManager.DescriptorBufferMemory) {
    assert(memory.persistent.device_memory == VK_NULL_HANDLE);
    assert(memory.persistent.resources.count == 0);
    destroySubarena(*memory.persistent.names_subarena);
}

resetVulkanDescriptorBufferMemoryPool :: (device : *VulkanDevice, memory_pool : *VulkanResourceManager.MemoryPool) {
    for * memory_pool.resources {
        it.mapped_memory = null;

        vkDestroyBuffer(device.device, it.buffer, null);
        it.buffer = VK_NULL_HANDLE;
    }
    reset(*memory_pool.resources);

    if memory_pool.device_memory {
        vkUnmapMemory(device.device, memory_pool.device_memory);

        vkFreeMemory(device.device, memory_pool.device_memory, null);
        memory_pool.device_memory = VK_NULL_HANDLE;
    }

    resetArena(*memory_pool.names_subarena);
}

commitVulkanDescriptorBufferMemoryPool :: (
    device      : *VulkanDevice,
    manager     : *VulkanResourceManager,
    memory_pool : *VulkanResourceManager.MemoryPool
) {
    assert(memory_pool.device_memory == VK_NULL_HANDLE);
    if memory_pool.resources.count <= 0 return;

    allocate_flags_info := VkMemoryAllocateFlagsInfo.{
        flags = .VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT
    };

    allocate_info := VkMemoryAllocateInfo.{
        pNext           = *allocate_flags_info,
        memoryTypeIndex = manager.memory_type_indices[ResourceManager.Pool.UPLOAD]
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

    if allocate_info.allocationSize > device.properties11.maxMemoryAllocationSize {
        assertMessage("Descriptor buffers/Persistent memory pool allocation size (% MB) exceeds maximum allowed allocation size: % MB",
                      bytesToMegaBytes(allocate_info.allocationSize),
                      bytesToMegaBytes(device.properties11.maxMemoryAllocationSize));
    }

    debugCheckVK(vkAllocateMemory(device.device, *allocate_info, null, *memory_pool.device_memory));

    setVulkanObjectName(device, memory_pool.device_memory, "Memory/Descriptor buffers/Persistent");

    bind_infos_it = bind_infos;
    for 0 .. memory_pool.resources.count - 1 {
        bind_infos_it.memory = memory_pool.device_memory;
        bind_infos_it += 1;
    }

    debugCheckVK(vkBindBufferMemory2(device.device, cast(u32) memory_pool.resources.count, bind_infos));

    mapped_device_memory : *void;
    debugCheckVK(vkMapMemory(device.device, memory_pool.device_memory, 0, VK_WHOLE_SIZE, 0, *mapped_device_memory));
    assert(mapped_device_memory);

    bind_infos_it = bind_infos;
    for * memory_pool.resources {
        assert(!it.mapped_memory);
        it.mapped_memory = mapped_device_memory + cast(u64) bind_infos_it.memoryOffset;

        info := VkBufferDeviceAddressInfo.{ buffer = it.buffer };
        it.device_address = cast(u64) vkGetBufferDeviceAddress(device.device, *info);
        assert(it.device_address);

        bind_infos_it += 1;
    }
}

//
// Other
//

fillMemoryTypeIndices :: (device : *VulkanDevice, manager : *VulkanResourceManager) {
    // [0] - ideal
    // [1] - minimal
    MEMORY_PROPERTIES : [ResourceManager.POOLS_COUNT][2] VkMemoryPropertyFlags : .[
        .[ // Default
            .VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            .VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
        ], .[ // Upload
            .VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | .VK_MEMORY_PROPERTY_HOST_COHERENT_BIT | .VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            .VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | .VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
        ], .[ // Readback
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

#load "buffer.jai";
#load "texture.jai";
#load "texture_view.jai";
#load "sampler.jai";
