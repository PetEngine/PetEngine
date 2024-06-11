// @TODO: #BindingManager.
//     - Separate bindings for compute queue?
//     - BUFFER_SRV, BUFFER_UAV

VulkanBindingManager :: struct {
    #as using public_data : BindingManager;

    DescriptorSetLayout :: struct {
        INVALID_OFFSET :: cast,trunc(VkDeviceSize) 0xFFFF_FFFF_FFFF_FFFF;

        layout       : VkDescriptorSetLayout;
        size         : VkDeviceSize;
        usage        : VkBufferUsageFlags;
        slot_offsets : [BindingManager.MAX_DESCRIPTOR_SET_SLOTS] VkDeviceSize;
    }

    DescriptorSetBindings :: struct {
        descriptor_buffer : *VulkanBuffer;
        mutex             : Mutex;
    }

    descriptor_set_layouts : [MAX_DESCRIPTOR_SETS] DescriptorSetLayout;

    per_frame_bindings  : StaticArray(DescriptorSetBindings, Device.MAX_FRAME_BUFFERING);
    per_scene_bindings  : DescriptorSetBindings;
    persistent_bindings : DescriptorSetBindings;
}

createVulkanBindingManager :: (device : *VulkanDevice, resource_manager : *VulkanResourceManager) -> *VulkanBindingManager {
    manager := pushToArena(*context.pet.persistent_arena, VulkanBindingManager);

    #insert -> string { return generatePlatformVtableInitialization(BindingManager, "manager", "Vulkan"); }

BINDINGS_LIMITS_FORMAT_STRING :: #string END
Bindings limits:
    Max bound descriptor buffers:                                  %
    Max bound resource descriptor buffers:                         %
    Max bound sampler descriptor buffers:                          %
    Max resource descriptor buffer range accessible to a shader:   %
    Max sampler descriptor buffer range accessible to a shader:    %
    Max resource descriptor buffer address space size:             %
    Max sampler descriptor buffer address space size:              %
    Max resource and sampler descriptor buffer address space size: %
END;

    verboseMessage(BINDINGS_LIMITS_FORMAT_STRING,
                   device.descriptor_buffer_properties.maxDescriptorBufferBindings,
                   device.descriptor_buffer_properties.maxResourceDescriptorBufferBindings,
                   device.descriptor_buffer_properties.maxSamplerDescriptorBufferBindings,
                   device.descriptor_buffer_properties.maxResourceDescriptorBufferRange,
                   device.descriptor_buffer_properties.maxSamplerDescriptorBufferRange,
                   device.descriptor_buffer_properties.resourceDescriptorBufferAddressSpaceSize,
                   device.descriptor_buffer_properties.samplerDescriptorBufferAddressSpaceSize,
                   device.descriptor_buffer_properties.descriptorBufferAddressSpaceSize);

    manager.per_frame_bindings.count = cast,no_check(s64) device.frame_buffering;

    createVulkanDescriptorSetLayout(device, manager, .PER_FRAME,  .[ .UNIFORM, .SAMPLERS, .TEXTURES, .IMAGES ]);
    createVulkanDescriptorSetLayout(device, manager, .PER_SCENE,  .[ .SAMPLERS, .TEXTURES, .IMAGES ]);
    createVulkanDescriptorSetLayout(device, manager, .PERSISTENT, .[ .UNIFORM, .SAMPLERS, .TEXTURES, .IMAGES ]);

    for * manager.per_frame_bindings createVulkanDescriptorSetBindings(device, manager, resource_manager, it, .PER_FRAME, Basic.tprint("Frame #%", it_index));
    createVulkanDescriptorSetBindings(device, manager, resource_manager, *manager.per_scene_bindings, .PER_SCENE, "Per Scene");
    createVulkanDescriptorSetBindings(device, manager, resource_manager, *manager.persistent_bindings, .PERSISTENT, "Persistent");

    return manager;
}

#scope_file

destroyVulkanBindingManager :: (device_ : *Device, manager_ : *BindingManager) {
    device  := cast(*VulkanDevice) device_;
    manager := cast(*VulkanBindingManager) manager_;

    for manager.descriptor_set_layouts {
        vkDestroyDescriptorSetLayout(device.device, it.layout, null);
    }
}

resetVulkanBindings :: (device_ : *Device, manager_ : *BindingManager, descriptor_set : DescriptorSet) {
    device  := cast(*VulkanDevice)         device_;
    manager := cast(*VulkanBindingManager) manager_;

    assertThreadKind(.MAIN);

    // @TODO: #FrameBuffering.
    //    - If manager.per_frame_*.count < device.frame_buffering then allocate new memory
    //    - If manager.per_frame_*.count > device.frame_buffering then free unusused memory

    if #complete descriptor_set == {
        case .PER_FRAME;
            assert(manager.per_frame_bindings.count == cast,no_check(s64) device.frame_buffering, "It's illegal to change frame buffering for now");
            manager.per_frame_bindings.count = cast,no_check(s64) device.frame_buffering;

        case .PER_SCENE; #through;
        case .PERSISTENT;
            // Do nothing
    }
}

commitVulkanBindings :: (
    device_           : *Device,
    manager_          : *BindingManager,
    resource_manager_ : *ResourceManager,
    descriptor_set    : DescriptorSet
) {
    device           := cast(*VulkanDevice)          device_;
    manager          := cast(*VulkanBindingManager)  manager_;
    resource_manager := cast(*VulkanResourceManager) resource_manager_;

    layout := *manager.descriptor_set_layouts[descriptor_set];

    // Commit of per view bindings may arrive from different threads except others,
    // so we need to lock the mutex only for committing per view bindings.

    if #complete descriptor_set == {
        case .PER_FRAME;
            assertThreadKind(.MAIN);

            bindings   := *manager.per_frame_bindings[device.frame_index];
            set_memory := bindings.descriptor_buffer.mapped_memory;

            for slot_offset, slot : layout.slot_offsets {
                if slot_offset == VulkanBindingManager.DescriptorSetLayout.INVALID_OFFSET {
                    continue;
                }

                slot_memory := set_memory + cast(u64) slot_offset;

                if #complete cast(DescriptorSetSlot) slot == {
                    case .UNIFORM;  fillUniforms(device, resource_manager, .PER_FRAME, .PER_FRAME,     slot_memory);
                    case .SAMPLERS; fillSamplers(device, resource_manager, .PER_FRAME, descriptor_set, slot_memory);
                    case .TEXTURES; fillTextures(device, resource_manager, .PER_FRAME, descriptor_set, slot_memory);
                    case .IMAGES;   fillImages(device,   resource_manager, .PER_FRAME, descriptor_set, slot_memory);
                }
            }

        case .PER_SCENE;
            assertThreadKind(.MAIN);

            bindings   := *manager.per_scene_bindings;
            set_memory := bindings.descriptor_buffer.mapped_memory;

            for slot_offset, slot : layout.slot_offsets {
                if slot_offset == VulkanBindingManager.DescriptorSetLayout.INVALID_OFFSET {
                    continue;
                }

                slot_memory := set_memory + cast(u64) slot_offset;

                if #complete cast(DescriptorSetSlot) slot == {
                    case .UNIFORM;  fillUniforms(device, resource_manager, .PER_SCENE, .PER_SCENE,     slot_memory);
                    case .SAMPLERS; fillSamplers(device, resource_manager, .PER_SCENE, descriptor_set, slot_memory);
                    case .TEXTURES; fillTextures(device, resource_manager, .PER_SCENE, descriptor_set, slot_memory);
                    case .IMAGES;   fillImages(device,   resource_manager, .PER_SCENE, descriptor_set, slot_memory);
                }
            }

        case .PERSISTENT;
            assertThreadKind(.MAIN);

            bindings   := *manager.persistent_bindings;
            set_memory := bindings.descriptor_buffer.mapped_memory;

            for slot_offset, slot : layout.slot_offsets {
                if slot_offset == VulkanBindingManager.DescriptorSetLayout.INVALID_OFFSET {
                    continue;
                }

                slot_memory := set_memory + cast(u64) slot_offset;

                if #complete cast(DescriptorSetSlot) slot == {
                    case .UNIFORM;  fillUniforms(device, resource_manager, .PERSISTENT, .PERSISTENT,    slot_memory);
                    case .SAMPLERS; fillSamplers(device, resource_manager, .PERSISTENT, descriptor_set, slot_memory);
                    case .TEXTURES; fillTextures(device, resource_manager, .PERSISTENT, descriptor_set, slot_memory);
                    case .IMAGES;   fillImages(device,   resource_manager, .PERSISTENT, descriptor_set, slot_memory);
                }
            }
    }
}

createVulkanDescriptorSetBindings :: (
    device                 : *VulkanDevice,
    manager                : *VulkanBindingManager,
    resource_manager       : *VulkanResourceManager,
    bindings               : *VulkanBindingManager.DescriptorSetBindings,
    descriptor_set         : DescriptorSet,
    descriptor_buffer_name : string
) {
    layout := *manager.descriptor_set_layouts[descriptor_set];

    bindings.descriptor_buffer = pushVulkanDescriptorBuffer(device, resource_manager);

    bindings.descriptor_buffer.size                  = cast(u32) layout.size;
    bindings.descriptor_buffer.current_owner         = QueueType.GRAPHICS;
    bindings.descriptor_buffer.possible_owners.count = 1;
    bindings.descriptor_buffer.possible_owners[0]    = QueueType.GRAPHICS;

    createVulkanDescriptorBuffer(device, resource_manager, bindings.descriptor_buffer, layout.usage, descriptor_buffer_name);
}

createVulkanDescriptorSetLayout :: (
    device  : *VulkanDevice,
    manager : *VulkanBindingManager,
    set     : DescriptorSet,
    slots   : [] DescriptorSetSlot
) {
    assert(slots.count <= BindingManager.MAX_DESCRIPTOR_SET_SLOTS);

    pushBinding :: (type : VkDescriptorType, count : u32) #expand {
        `binding_layouts_it.binding         = cast(u32) `it;
        `binding_layouts_it.descriptorType  = type;
        `binding_layouts_it.descriptorCount = count;
        `binding_layouts_it.stageFlags      = .VK_SHADER_STAGE_VERTEX_BIT | .VK_SHADER_STAGE_FRAGMENT_BIT;

        `binding_layouts_it += 1;
    }

    layout := *manager.descriptor_set_layouts[set];

    binding_layouts    : [BindingManager.MAX_DESCRIPTOR_SET_SLOTS] VkDescriptorSetLayoutBinding;
    binding_layouts_it := binding_layouts.data;

    for slots {
        if #complete it == {
            case .UNIFORM;
                count := ifx set == .PERSISTENT then cast(u32) BindingManager.MAX_PER_VIEW_UNIFORMS else 1;
                pushBinding(.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, count);
                layout.usage |= .VK_BUFFER_USAGE_RESOURCE_DESCRIPTOR_BUFFER_BIT_EXT;

            case .SAMPLERS;
                pushBinding(.VK_DESCRIPTOR_TYPE_SAMPLER, BindingManager.MAX_SAMPLERS);
                layout.usage |= .VK_BUFFER_USAGE_SAMPLER_DESCRIPTOR_BUFFER_BIT_EXT;

            case .TEXTURES;
                pushBinding(.VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE, BindingManager.MAX_TEXTURES);
                layout.usage |= .VK_BUFFER_USAGE_RESOURCE_DESCRIPTOR_BUFFER_BIT_EXT;

            case .IMAGES;
                pushBinding(.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, BindingManager.MAX_IMAGES);
                layout.usage |= .VK_BUFFER_USAGE_RESOURCE_DESCRIPTOR_BUFFER_BIT_EXT;
        }
    }
    assert(binding_layouts_it <= binding_layouts.data + binding_layouts.count);

    create_info := VkDescriptorSetLayoutCreateInfo.{
        flags        = .VK_DESCRIPTOR_SET_LAYOUT_CREATE_DESCRIPTOR_BUFFER_BIT_EXT,
        bindingCount = cast(u32) (binding_layouts_it - binding_layouts.data),
        pBindings    = binding_layouts.data,
    };

    debugCheckVK(vkCreateDescriptorSetLayout(device.device, *create_info, null, *layout.layout));

    setVulkanObjectName(device, layout.layout, "% descriptor set layout", set);

    device.loader.extensions.device.required.vkGetDescriptorSetLayoutSizeEXT(device.device, layout.layout, *layout.size);
    layout.size = alignUpWithPowerOfTwo(layout.size, device.descriptor_buffer_properties.descriptorBufferOffsetAlignment);

    for * layout.slot_offsets {
        it.* = VulkanBindingManager.DescriptorSetLayout.INVALID_OFFSET;
    }

    for slots {
        device.loader.extensions.device.required.vkGetDescriptorSetLayoutBindingOffsetEXT(device.device,
                                                                                          layout.layout,
                                                                                          cast(u32) it,
                                                                                          *layout.slot_offsets[it]);
    }
}

fillUniforms :: (
    device           : *VulkanDevice,
    resource_manager : *VulkanResourceManager,
    $lifetime        : ResourceManager.Lifetime,
    $descriptor_set  : DescriptorSet,
    slot_memory      : *void
) {
    pool : *VulkanResourceManager.BufferMemory.Pool;
    #if #complete lifetime == {
        case .PER_FRAME;  pool = *resource_manager.buffers.per_frame[device.frame_index][ResourceManager.Pool.UPLOAD];
        case .PER_SCENE;  pool = *resource_manager.buffers.per_scene[ResourceManager.Pool.UPLOAD];
        case .PERSISTENT; pool = *resource_manager.buffers.persistent[ResourceManager.Pool.UPLOAD];
    }
    assert(pool);

    descriptor_size   := device.descriptor_buffer_properties.uniformBufferDescriptorSize;
    descriptor_memory := slot_memory;

    descriptors_count := 0;
    MAX_DESCRIPTORS   := #ifx descriptor_set == .PERSISTENT then BindingManager.MAX_PER_VIEW_UNIFORMS else 1;

    for pool.resources {
        if !(it.usage & .UNIFORM) continue;

        assert(descriptors_count < MAX_DESCRIPTORS, "Too much uniforms for descriptor set %. Max: %", descriptor_set, MAX_DESCRIPTORS);
        descriptors_count += 1;

        address_info := VkDescriptorAddressInfoEXT.{
            address = cast(VkDeviceAddress) it.device_address,
            range   = cast(VkDeviceSize) it.size,
            format  = .VK_FORMAT_UNDEFINED,
        };

        descriptor_info := VkDescriptorGetInfoEXT.{
            type                = .VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            data.pUniformBuffer = *address_info,
        };

        device.loader.extensions.device.required.vkGetDescriptorEXT(device.device, *descriptor_info, descriptor_size, descriptor_memory);

        descriptor_memory += descriptor_size;
    }
}

fillSamplers :: (
    device           : *VulkanDevice,
    resource_manager : *VulkanResourceManager,
    $lifetime        : ResourceManager.Lifetime,
    descriptor_set   : DescriptorSet,
    slot_memory      : *void
) {
    pool : *VulkanResourceManager.SamplerMemory.Pool;
    #if #complete lifetime == {
        case .PER_FRAME;  pool = *resource_manager.samplers.per_frame[device.frame_index];
        case .PER_SCENE;  pool = *resource_manager.samplers.per_scene;
        case .PERSISTENT; pool = *resource_manager.samplers.persistent;
    }
    assert(pool);

    descriptor_size   := device.descriptor_buffer_properties.samplerDescriptorSize;
    descriptor_memory := slot_memory;

    descriptors_count := 0;
    MAX_DESCRIPTORS   :: BindingManager.MAX_SAMPLERS;

    for pool.resources {
        assert(descriptors_count < MAX_DESCRIPTORS, "Too much samplers for descriptor set %. Max: %", descriptor_set, MAX_DESCRIPTORS);
        descriptors_count += 1;

        descriptor_info := VkDescriptorGetInfoEXT.{
            type          = .VK_DESCRIPTOR_TYPE_SAMPLER,
            data.pSampler = *it.sampler,
        };

        device.loader.extensions.device.required.vkGetDescriptorEXT(device.device, *descriptor_info, descriptor_size, descriptor_memory);

        descriptor_memory += descriptor_size;
    }
}

fillTextures :: (
    device           : *VulkanDevice,
    resource_manager : *VulkanResourceManager,
    $lifetime        : ResourceManager.Lifetime,
    descriptor_set   : DescriptorSet,
    slot_memory      : *void
) {
    pool : *VulkanResourceManager.TextureViewMemory.Pool;
    #if #complete lifetime == {
        case .PER_FRAME;  pool = *resource_manager.texture_views.per_frame[device.frame_index];
        case .PER_SCENE;  pool = *resource_manager.texture_views.per_scene;
        case .PERSISTENT; pool = *resource_manager.texture_views.persistent;
    }
    assert(pool);

    descriptor_size   := device.descriptor_buffer_properties.sampledImageDescriptorSize;
    descriptor_memory := slot_memory;

    descriptors_count := 0;
    MAX_DESCRIPTORS   :: BindingManager.MAX_TEXTURES;

    for pool.resources {
        if it.usage != .SHADER_READ continue;

        assert(descriptors_count < MAX_DESCRIPTORS, "Too much textures for descriptor set %. Max: %", descriptor_set, MAX_DESCRIPTORS);
        descriptors_count += 1;

        image_info := VkDescriptorImageInfo.{
            imageView   = it.view,
            imageLayout = ifx  textureFormatFlags(it.format) & (.DEPTH | .STENCIL)
                          then .VK_IMAGE_LAYOUT_DEPTH_STENCIL_READ_ONLY_OPTIMAL
                          else .VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        };

        descriptor_info := VkDescriptorGetInfoEXT.{
            type               = .VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE,
            data.pSampledImage = *image_info,
        };

        device.loader.extensions.device.required.vkGetDescriptorEXT(device.device, *descriptor_info, descriptor_size, descriptor_memory);

        descriptor_memory += descriptor_size;
    }
}

fillImages :: (
    device           : *VulkanDevice,
    resource_manager : *VulkanResourceManager,
    $lifetime        : ResourceManager.Lifetime,
    descriptor_set   : DescriptorSet,
    slot_memory      : *void
) {
    pool : *VulkanResourceManager.TextureViewMemory.Pool;
    #if #complete lifetime == {
        case .PER_FRAME;  pool = *resource_manager.texture_views.per_frame[device.frame_index];
        case .PER_SCENE;  pool = *resource_manager.texture_views.per_scene;
        case .PERSISTENT; pool = *resource_manager.texture_views.persistent;
    }
    assert(pool);

    descriptor_size   := device.descriptor_buffer_properties.storageImageDescriptorSize;
    descriptor_memory := slot_memory;

    descriptors_count := 0;
    MAX_DESCRIPTORS   :: BindingManager.MAX_IMAGES;

    for pool.resources {
        if it.usage != .SHADER_WRITE continue;

        assert(descriptors_count < MAX_DESCRIPTORS, "Too much images for descriptor set %. Max: %", descriptor_set, MAX_DESCRIPTORS);
        descriptors_count += 1;

        image_info := VkDescriptorImageInfo.{
            imageView   = it.view,
            imageLayout = .VK_IMAGE_LAYOUT_GENERAL,
        };

        descriptor_info := VkDescriptorGetInfoEXT.{
            type               = .VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
            data.pStorageImage = *image_info,
        };

        device.loader.extensions.device.required.vkGetDescriptorEXT(device.device, *descriptor_info, descriptor_size, descriptor_memory);

        descriptor_memory += descriptor_size;
    }
}
