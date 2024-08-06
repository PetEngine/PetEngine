// @TODO:
//    - #SwapchainBuffers. Make a function for swapchain buffers initialization?
//    - #ResourceLayout. Rework resource layout changing mechanism. If we gonna compile our command buffers concurrently,
//      current tracking of current texture layout will not work.
//    - Use reserved resources or something instead of freeing memory on reset. Use sparce bindings maybe?
//    - #RobustAccess. Robust buffer and image access
//    - #MTRendering. Thread safety for memory pools and name arenas.

VulkanResourceManager :: struct {
    #as using public_data : ResourceManager;

    MAX_DESCRIPTOR_BUFFERS :: 16;

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

createVulkanResourceManager :: () {
    manager := pushToArena(*context.pet.arenas.persistent, VulkanResourceManager);
    context.pet.render.resource_manager = manager;

    #insert -> string { return generatePlatformVtableInitialization(ResourceManager, "manager", "Vulkan"); }

    device := cast(*VulkanDevice) context.pet.render.device;

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
            Basic.print(*builder, "    [%]: Properties: %\n         Heap size:  % GB\n         Heap flags: %\n",
                        it_index,
                        it.propertyFlags,
                        bytesToGigaBytes(heap.size),
                        heap.flags);
        }
        verboseMessage("%", Basic.builder_to_string(*builder,, allocator = Basic.temp));
    }

    fillMemoryTypeIndices();

    Basic.print(*builder, "Pools memory types (%):\n", ResourceManager.POOLS_COUNT);
    for manager.memory_type_indices {
        memory_type := device.memory_properties.memoryProperties.memoryTypes[it];
        heap := memory_heaps[memory_type.heapIndex];
        Basic.print(*builder, "    %:\n        Properties: %\n        Heap size:  % GB\n        Heap flags: %\n",
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

    createVulkanBufferMemoryNamesSubarenas(BUFFERS_SUBARENA_CAPACITY);
    createVulkanTextureMemoryNamesSubarenas(TEXTURES_SUBARENA_CAPACITY);
    createVulkanTextureViewMemoryNamesSubarenas(TEXTURE_VIEWS_SUBARENA_CAPACITY);
    createVulkanSamplerMemoryNamesSubarenas(SAMPLERS_SUBARENA_CAPACITY);
    createVulkanDescriptorBufferMemoryNamesSubarenas(DESCRIPTOR_BUFFERS_SUBARENA_CAPACITY);
}

#scope_file

destroyVulkanResourceManager :: () {
    destroyVulkanBufferMemory();
    destroyVulkanTextureMemory();
    destroyVulkanTextureViewMemory();
    destroyVulkanSamplerMemory();
    destroyVulkanDescriptorBufferMemory();

    manager := cast(*VulkanResourceManager) context.pet.render.resource_manager;
    destroyArena(*manager.names_arena);
}

commitVulkanResourceMemory :: (lifetime : ResourceManager.Lifetime) {
    device  := context.pet.render.device;
    manager := cast(*VulkanResourceManager) context.pet.render.resource_manager;

    if #complete lifetime == {
        case .PERSISTENT;
            for * manager.buffers.persistent {
                commitVulkanBufferMemoryPool(it, lifetime, cast(ResourceManager.Pool) it_index);
            }
            commitVulkanTextureMemoryPool(*manager.textures.persistent, lifetime);
            commitVulkanTextureViewMemoryPool(*manager.texture_views.persistent);
            commitVulkanDescriptorBufferMemoryPool(*manager.descriptor_buffers.persistent);

        case .PER_SCENE;
            for * manager.buffers.per_scene {
                commitVulkanBufferMemoryPool(it, lifetime, cast(ResourceManager.Pool) it_index);
            }
            commitVulkanTextureMemoryPool(*manager.textures.per_scene, lifetime);
            commitVulkanTextureViewMemoryPool(*manager.texture_views.per_scene);

        case .PER_FRAME;
            for * manager.buffers.per_frame[device.frame_index] {
                commitVulkanBufferMemoryPool(it, lifetime, cast(ResourceManager.Pool) it_index);
            }
            commitVulkanTextureMemoryPool(*manager.textures.per_frame[device.frame_index], lifetime);
            commitVulkanTextureViewMemoryPool(*manager.texture_views.per_frame[device.frame_index]);
    }
}

resetVulkanResourceMemory :: (lifetime : ResourceManager.Lifetime) {
    device  := context.pet.render.device;
    manager := cast(*VulkanResourceManager) context.pet.render.resource_manager;

    if #complete lifetime == {
        case .PERSISTENT;
            for * manager.buffers.persistent resetVulkanBufferMemoryPool(it, cast(ResourceManager.Pool) it_index);
            resetVulkanTextureMemoryPool(*manager.textures.persistent);
            resetVulkanTextureViewMemoryPool(*manager.texture_views.persistent);
            resetVulkanSamplerMemoryPool(*manager.samplers.persistent);
            resetVulkanDescriptorBufferMemoryPool(*manager.descriptor_buffers.persistent);

        case .PER_SCENE;
            for * manager.buffers.per_scene resetVulkanBufferMemoryPool(it, cast(ResourceManager.Pool) it_index);
            resetVulkanTextureMemoryPool(*manager.textures.per_scene);
            resetVulkanTextureViewMemoryPool(*manager.texture_views.per_scene);
            resetVulkanSamplerMemoryPool(*manager.samplers.per_scene);

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
                resetVulkanBufferMemoryPool(it, cast(ResourceManager.Pool) it_index);
            }
            resetVulkanTextureMemoryPool(*manager.textures.per_frame[device.frame_index]);
            resetVulkanTextureViewMemoryPool(*manager.texture_views.per_frame[device.frame_index]);
            resetVulkanSamplerMemoryPool(*manager.samplers.per_frame[device.frame_index]);
    }
}

//
// Buffers
//

createVulkanBufferMemoryNamesSubarenas :: (subarena_capacity : s64) {
    manager := cast(*VulkanResourceManager) context.pet.render.resource_manager;

    for * manager.buffers.persistent {
        createSubarena(*manager.names_arena, *it.names_subarena, subarena_capacity, "Buffers/Persistent/%", cast(ResourceManager.Pool) it_index);
    }

    for * manager.buffers.per_scene {
        createSubarena(*manager.names_arena, *it.names_subarena, subarena_capacity, "Buffers/Per scene/%", cast(ResourceManager.Pool) it_index);
    }

    manager.buffers.per_frame.count = cast,no_check(s64) context.pet.render.device.frame_buffering;
    for * frame_pools, frame_index : manager.buffers.per_frame.data {
        for * frame_pools.* {
            createSubarena(*manager.names_arena, *it.names_subarena, subarena_capacity, "Buffers/Frame #%/%", frame_index, cast(ResourceManager.Pool) it_index);
        }
    }
}

destroyVulkanBufferMemory :: () {
    manager := cast(*VulkanResourceManager) context.pet.render.resource_manager;

    for * manager.buffers.persistent {
        assert(it.device_memory == VK_NULL_HANDLE);
        assert(it.resources.count == 0);
        destroySubarena(*it.names_subarena);
    }

    for * manager.buffers.per_scene  {
        assert(it.device_memory == VK_NULL_HANDLE);
        assert(it.resources.count == 0);
        destroySubarena(*it.names_subarena);
    }

    manager.buffers.per_frame.count = 0;
    for * manager.buffers.per_frame.data {
        for * it.* {
            assert(it.device_memory == VK_NULL_HANDLE);
            assert(it.resources.count == 0);
            destroySubarena(*it.names_subarena);
        }
    }
}

resetVulkanBufferMemoryPool :: (memory_pool : *VulkanResourceManager.MemoryPool, pool : ResourceManager.Pool) {
    device := cast(*VulkanDevice) context.pet.render.device;

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
    memory_pool : *VulkanResourceManager.MemoryPool,
    lifetime    : ResourceManager.Lifetime,
    pool        : ResourceManager.Pool
) {
    assert(memory_pool.device_memory == VK_NULL_HANDLE);
    if memory_pool.resources.count <= 0 return;

    device  := cast(*VulkanDevice)          context.pet.render.device;
    manager := cast(*VulkanResourceManager) context.pet.render.resource_manager;

    allocate_flags_info := VkMemoryAllocateFlagsInfo.{
        flags = .VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT
    };

    allocate_info := VkMemoryAllocateInfo.{
        pNext           = *allocate_flags_info,
        memoryTypeIndex = manager.memory_type_indices[pool]
    };

    bind_infos    := pushToArena(*context.pet.arenas.per_frame, VkBindBufferMemoryInfo, memory_pool.resources.count);
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
        setVulkanObjectName(memory_pool.device_memory, "Memory/Buffers/Frame #%/%", device.frame_index, pool);
    } else {
        setVulkanObjectName(memory_pool.device_memory, "Memory/Buffers/%/%", lifetime, pool);
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

createVulkanTextureMemoryNamesSubarenas :: (subarena_capacity : s64) {
    manager := cast(*VulkanResourceManager) context.pet.render.resource_manager;

    createSubarena(*manager.names_arena, *manager.textures.persistent.names_subarena, subarena_capacity, "Textures/Persistent");
    createSubarena(*manager.names_arena, *manager.textures.per_scene.names_subarena, subarena_capacity, "Textures/Per scene");

    manager.textures.per_frame.count = cast,no_check(s64) context.pet.render.device.frame_buffering;
    for * manager.textures.per_frame.data {
        createSubarena(*manager.names_arena, *it.names_subarena, subarena_capacity, "Textures/Frame #%", it_index);
    }
}

destroyVulkanTextureMemory :: () {
    manager := cast(*VulkanResourceManager) context.pet.render.resource_manager;

    assert(manager.textures.persistent.device_memory == VK_NULL_HANDLE);
    assert(manager.textures.persistent.resources.count == 0);
    destroySubarena(*manager.textures.persistent.names_subarena);

    assert(manager.textures.per_scene.device_memory == VK_NULL_HANDLE);
    assert(manager.textures.per_scene.resources.count == 0);
    destroySubarena(*manager.textures.per_scene.names_subarena);

    manager.textures.per_frame.count = 0;
    for * manager.textures.per_frame.data {
        assert(it.device_memory == VK_NULL_HANDLE);
        assert(it.resources.count == 0);
        destroySubarena(*it.names_subarena);
    }
}

resetVulkanTextureMemoryPool :: (memory_pool : *VulkanResourceManager.MemoryPool) {
    device := cast(*VulkanDevice) context.pet.render.device;

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

commitVulkanTextureMemoryPool :: (memory_pool : *VulkanResourceManager.MemoryPool, lifetime : ResourceManager.Lifetime) {
    assert(memory_pool.device_memory == VK_NULL_HANDLE);
    if memory_pool.resources.count <= 0 return;

    device  := cast(*VulkanDevice)          context.pet.render.device;
    manager := cast(*VulkanResourceManager) context.pet.render.resource_manager;

    allocate_info := VkMemoryAllocateInfo.{
        memoryTypeIndex = manager.memory_type_indices[ResourceManager.Pool.DEFAULT]
    };

    bind_infos    := pushToArena(*context.pet.arenas.per_frame, VkBindImageMemoryInfo, memory_pool.resources.count);
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
        setVulkanObjectName(memory_pool.device_memory, "Memory/Textures/Frame #%", device.frame_index);
    } else {
        setVulkanObjectName(memory_pool.device_memory, "Memory/Textures/%", lifetime);
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

createVulkanTextureViewMemoryNamesSubarenas :: (subarena_capacity : s64) {
    manager := cast(*VulkanResourceManager) context.pet.render.resource_manager;

    createSubarena(*manager.names_arena, *manager.texture_views.persistent.names_subarena, subarena_capacity, "Texture views/Persistent");
    createSubarena(*manager.names_arena, *manager.texture_views.per_scene.names_subarena, subarena_capacity, "Texture views/Per scene");

    manager.texture_views.per_frame.count = cast,no_check(s64) context.pet.render.device.frame_buffering;
    for * manager.texture_views.per_frame.data {
        createSubarena(*manager.names_arena, *it.names_subarena, subarena_capacity, "Texture views/Frame #%", it_index);
    }
}

destroyVulkanTextureViewMemory :: () {
    manager := cast(*VulkanResourceManager) context.pet.render.resource_manager;

    assert(manager.texture_views.persistent.resources.count == 0);
    destroySubarena(*manager.texture_views.persistent.names_subarena);

    assert(manager.texture_views.per_scene.resources.count == 0);
    destroySubarena(*manager.texture_views.per_scene.names_subarena);

    manager.texture_views.per_frame.count = 0;
    for * manager.texture_views.per_frame.data {
        assert(it.resources.count == 0);
        destroySubarena(*it.names_subarena);
    }
}

resetVulkanTextureViewMemoryPool :: (memory_pool : *VulkanResourceManager.TextureViewMemory.Pool) {
    device := cast(*VulkanDevice) context.pet.render.device;

    for * memory_pool.resources {
        vkDestroyImageView(device.device, it.view, null);
        it.view = VK_NULL_HANDLE;
    }
    reset(*memory_pool.resources);

    resetArena(*memory_pool.names_subarena);
}

commitVulkanTextureViewMemoryPool :: (memory_pool : *VulkanResourceManager.TextureViewMemory.Pool) {
    device := cast(*VulkanDevice) context.pet.render.device;

    for * memory_pool.resources {
        texture := cast(*VulkanTexture) it.texture;

        usage_info := VkImageViewUsageCreateInfo.{
            usage = textureUsageToVulkanUsageFlags(it.usage, false)
        };

        create_info := VkImageViewCreateInfo.{
            pNext            = *usage_info,
            flags            = 0,
            image            = texture.image,
            format           = textureFormatToVulkanFormat(it.format),
            components       = .{
                r = .VK_COMPONENT_SWIZZLE_R,
                g = .VK_COMPONENT_SWIZZLE_G,
                b = .VK_COMPONENT_SWIZZLE_B,
                a = .VK_COMPONENT_SWIZZLE_A,
            },
            subresourceRange = .{
                aspectMask     = getVulkanImageAspectFlags(it.format),
                baseMipLevel   = it.first_mip,
                levelCount     = it.mips_count,
                baseArrayLayer = it.first_layer,
                layerCount     = max(it.layers_count, 1),
            },
        };

        if it.flags & .ARRAY {
            if it.dimension == {
                case ._1D;
                    create_info.viewType = .VK_IMAGE_VIEW_TYPE_1D_ARRAY;
                case ._2D;
                    create_info.viewType = ifx  it.flags & .CUBE
                                           then .VK_IMAGE_VIEW_TYPE_CUBE_ARRAY
                                           else .VK_IMAGE_VIEW_TYPE_2D_ARRAY;
            }
        } else {
            if #complete it.dimension == {
                case ._1D;
                    create_info.viewType = .VK_IMAGE_VIEW_TYPE_1D;
                case ._2D;
                    create_info.viewType = ifx  it.flags & .CUBE
                                           then .VK_IMAGE_VIEW_TYPE_CUBE
                                           else .VK_IMAGE_VIEW_TYPE_2D;
                case ._3D;
                    create_info.viewType = .VK_IMAGE_VIEW_TYPE_3D;
            }
        }

        debugCheckVK(vkCreateImageView(device.device, *create_info, null, *it.view));

        setVulkanObjectName(it.view, it.name);
    }
}

//
// Samplers
//

createVulkanSamplerMemoryNamesSubarenas :: (subarena_capacity : s64) {
    manager := cast(*VulkanResourceManager) context.pet.render.resource_manager;

    createSubarena(*manager.names_arena, *manager.samplers.persistent.names_subarena, subarena_capacity, "Samplers/Persistent");
    createSubarena(*manager.names_arena, *manager.samplers.per_scene.names_subarena, subarena_capacity, "Samplers/Per scene");

    manager.samplers.per_frame.count = cast,no_check(s64) context.pet.render.device.frame_buffering;
    for * manager.samplers.per_frame.data {
        createSubarena(*manager.names_arena, *it.names_subarena, subarena_capacity, "Samplers/Frame #%", it_index);
    }
}

destroyVulkanSamplerMemory :: () {
    manager := cast(*VulkanResourceManager) context.pet.render.resource_manager;

    assert(manager.samplers.persistent.resources.count == 0);
    destroySubarena(*manager.samplers.persistent.names_subarena);

    assert(manager.samplers.per_scene.resources.count == 0);
    destroySubarena(*manager.samplers.per_scene.names_subarena);

    manager.samplers.per_frame.count = 0;
    for * manager.samplers.per_frame.data {
        assert(it.resources.count == 0);
        destroySubarena(*it.names_subarena);
    }
}

resetVulkanSamplerMemoryPool :: (memory_pool : *VulkanResourceManager.MemorylessPool) {
    device := cast(*VulkanDevice) context.pet.render.device;

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

createVulkanDescriptorBufferMemoryNamesSubarenas :: inline (subarena_capacity : s64) {
    manager := cast(*VulkanResourceManager) context.pet.render.resource_manager;

    createSubarena(*manager.names_arena, *manager.descriptor_buffers.persistent.names_subarena, subarena_capacity, "Descriptor buffers/Persistent");
}

destroyVulkanDescriptorBufferMemory :: () {
    manager := cast(*VulkanResourceManager) context.pet.render.resource_manager;

    assert(manager.descriptor_buffers.persistent.device_memory == VK_NULL_HANDLE);
    assert(manager.descriptor_buffers.persistent.resources.count == 0);
    destroySubarena(*manager.descriptor_buffers.persistent.names_subarena);
}

resetVulkanDescriptorBufferMemoryPool :: (memory_pool : *VulkanResourceManager.MemoryPool) {
    device := cast(*VulkanDevice) context.pet.render.device;

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

commitVulkanDescriptorBufferMemoryPool :: (memory_pool : *VulkanResourceManager.MemoryPool) {
    assert(memory_pool.device_memory == VK_NULL_HANDLE);
    if memory_pool.resources.count <= 0 return;

    device  := cast(*VulkanDevice)          context.pet.render.device;
    manager := cast(*VulkanResourceManager) context.pet.render.resource_manager;

    allocate_flags_info := VkMemoryAllocateFlagsInfo.{
        flags = .VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT
    };

    allocate_info := VkMemoryAllocateInfo.{
        pNext           = *allocate_flags_info,
        memoryTypeIndex = manager.memory_type_indices[ResourceManager.Pool.UPLOAD]
    };

    bind_infos    := pushToArena(*context.pet.arenas.per_frame, VkBindBufferMemoryInfo, memory_pool.resources.count);
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

    setVulkanObjectName(memory_pool.device_memory, "Memory/Descriptor buffers/Persistent");

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

fillMemoryTypeIndices :: () {
    device  := cast(*VulkanDevice)          context.pet.render.device;
    manager := cast(*VulkanResourceManager) context.pet.render.resource_manager;

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
