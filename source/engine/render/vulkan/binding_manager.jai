VulkanBindingManager :: struct {
    #as using public_data : BindingManager;

    DescriptorSetLayout :: struct {
        INVALID_OFFSET :: cast(VkDeviceSize) 0xFFFF_FFFF_FFFF_FFFF;

        layout : VkDescriptorSetLayout;
        union {
            struct {
                size         : VkDeviceSize;
                usage        : VkBufferUsageFlags;
                slot_offsets : [MAX_DESCRIPTOR_SET_SLOTS] VkDeviceSize;
            }
            struct {
                descriptor_pool_sizes : StaticArray(VkDescriptorPoolSize, MAX_DESCRIPTOR_SET_SLOTS);
            }
        }
    }

    DescriptorSetBindings :: struct {
        union {
            descriptor_buffer : *VulkanBuffer;
            struct {
                descriptor_pool : VkDescriptorPool;
                descriptor_set  : VkDescriptorSet;
            }
        };
        descriptors_pushed : [MAX_DESCRIPTOR_SET_SLOTS] u16;

        #place descriptors_pushed; descriptors_pushed_packed : u64;
        #assert size_of(type_of(descriptors_pushed_packed)) == size_of(type_of(descriptors_pushed));
    }

    descriptor_set_layouts : [MAX_DESCRIPTOR_SETS] DescriptorSetLayout;

    per_frame_bindings  : StaticArray(DescriptorSetBindings, Device.MAX_FRAME_BUFFERING);
    per_scene_bindings  : DescriptorSetBindings;
    persistent_bindings : DescriptorSetBindings;
}

createVulkanBindingManager :: () {
    manager := pushToArena(*context.pet.arenas.persistent, VulkanBindingManager);
    context.pet.render.binding_manager = manager;

    #insert -> string { return generatePlatformVtableInitialization(BindingManager, "manager", "Vulkan"); }

DESCRIPTOR_BUFFER_BINDINGS_LIMITS_FORMAT_STRING :: #string END
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

DESCRIPTOR_POOL_BINDINGS_LIMITS_FORMAT_STRING :: #string END
Bindings limits:
    Max bound descriptor sets: %
    Max resources per stage:   %
    Max samplers:
        per stage:    %
        per pipeline: %
    Max uniform buffers:
        per stage:    %
        per pipeline: %
    Max sampled images:
        per stage:    %
        per pipeline: %
    Max storage images:
        per stage:    %
        per pipeline: %
END;

    device := cast(*VulkanDevice) context.pet.render.device;

    manager.uniform_buffer_offset_alignment = cast(u32) device.limits.minUniformBufferOffsetAlignment;
    assert(isPowerOfTwo(manager.uniform_buffer_offset_alignment));

    if device.descriptor_buffers_supported {
        infoMessage("Descriptor buffers are supported");

        verboseMessage(DESCRIPTOR_BUFFER_BINDINGS_LIMITS_FORMAT_STRING,
                       device.descriptor_buffer_properties.maxDescriptorBufferBindings,
                       device.descriptor_buffer_properties.maxResourceDescriptorBufferBindings,
                       device.descriptor_buffer_properties.maxSamplerDescriptorBufferBindings,
                       device.descriptor_buffer_properties.maxResourceDescriptorBufferRange,
                       device.descriptor_buffer_properties.maxSamplerDescriptorBufferRange,
                       device.descriptor_buffer_properties.resourceDescriptorBufferAddressSpaceSize,
                       device.descriptor_buffer_properties.samplerDescriptorBufferAddressSpaceSize,
                       device.descriptor_buffer_properties.descriptorBufferAddressSpaceSize);
    } else {
        warningMessage("Descriptor buffers are not supported");

        verboseMessage(DESCRIPTOR_POOL_BINDINGS_LIMITS_FORMAT_STRING,
                       device.limits.maxBoundDescriptorSets,
                       device.limits.maxPerStageResources,
                       device.limits.maxPerStageDescriptorSamplers,
                       device.limits.maxDescriptorSetSamplers,
                       device.limits.maxPerStageDescriptorUniformBuffers,
                       device.limits.maxDescriptorSetUniformBuffers,
                       device.limits.maxPerStageDescriptorSampledImages,
                       device.limits.maxDescriptorSetSampledImages,
                       device.limits.maxPerStageDescriptorStorageImages,
                       device.limits.maxDescriptorSetStorageImages);
    }

    manager.per_frame_bindings.count = cast,no_check(s64) device.frame_buffering;

    createVulkanDescriptorSetLayout(.PER_FRAME,  .[ .UNIFORM, .SAMPLERS, .TEXTURES, .IMAGES ]);
    createVulkanDescriptorSetLayout(.PER_SCENE,  .[ .SAMPLERS, .TEXTURES, .IMAGES ]);
    createVulkanDescriptorSetLayout(.PERSISTENT, .[ .UNIFORM, .SAMPLERS, .TEXTURES, .IMAGES ]);

    for * manager.per_frame_bindings createVulkanDescriptorSetBindings(it, .PER_FRAME, Basic.tprint("Frame #%", it_index));
    createVulkanDescriptorSetBindings(*manager.per_scene_bindings, .PER_SCENE, "Per Scene");
    createVulkanDescriptorSetBindings(*manager.persistent_bindings, .PERSISTENT, "Persistent");
}

#scope_file

destroyVulkanBindingManager :: () {
    device  := cast(*VulkanDevice)         context.pet.render.device;
    manager := cast(*VulkanBindingManager) context.pet.render.binding_manager;

    if !device.descriptor_buffers_supported {
        vkDestroyDescriptorPool(device.device, manager.persistent_bindings.descriptor_pool, null);
        vkDestroyDescriptorPool(device.device, manager.per_scene_bindings.descriptor_pool, null);
        for manager.per_frame_bindings vkDestroyDescriptorPool(device.device, it.descriptor_pool, null);
    }

    for manager.descriptor_set_layouts {
        vkDestroyDescriptorSetLayout(device.device, it.layout, null);
    }
}

resetVulkanBindings :: (descriptor_set : DescriptorSet) {
    assertThreadKind(.MAIN);

    manager := cast(*VulkanBindingManager) context.pet.render.binding_manager;

    bindings : *VulkanBindingManager.DescriptorSetBindings;
    if #complete descriptor_set == {
        case .PER_FRAME;
            // @TODO: #FrameBuffering.
            assert(manager.per_frame_bindings.count == cast,no_check(s64) context.pet.render.device.frame_buffering, "It's illegal to change frame buffering for now");
            manager.per_frame_bindings.count = cast,no_check(s64) context.pet.render.device.frame_buffering;

            bindings = *manager.per_frame_bindings[context.pet.render.device.frame_index];

        case .PER_SCENE;
            bindings = *manager.per_scene_bindings;

        case .PERSISTENT;
            bindings = *manager.persistent_bindings;
    }
    assert(bindings);

    bindings.descriptors_pushed_packed = 0;
}

pushVulkanBufferBinding  :: (descriptor_set : DescriptorSet, resource : *Buffer, offset : u32, size : u32) -> BindingHandle #must {
    device  := cast(*VulkanDevice)         context.pet.render.device;
    manager := cast(*VulkanBindingManager) context.pet.render.binding_manager;
    buffer  := cast(*VulkanBuffer)         resource;

    assert(buffer.usage == .UNIFORM, "Only uniform bindings are supported right now");

    if size > device.limits.maxUniformBufferRange {
        assertMessage("Size (%) should be <= VkDeviceLimits.maxUniformBufferRange (%)",
                      size,
                      device.limits.maxUniformBufferRange);
    }

    bindings        : *VulkanBindingManager.DescriptorSetBindings;
    max_descriptors : u32 = ---;
    if #complete descriptor_set == {
        case .PER_FRAME;
            bindings        = *manager.per_frame_bindings[device.frame_index];
            max_descriptors = 1;

        case .PER_SCENE;
            bindings        = *manager.per_scene_bindings;
            max_descriptors = 1;

        case .PERSISTENT;
            bindings        = *manager.persistent_bindings;
            max_descriptors = BindingManager.MAX_PER_VIEW_UNIFORMS;
    }
    assert(bindings);

    descriptor_index := Atomics.atomic_add(*bindings.descriptors_pushed[DescriptorSetSlot.UNIFORM], 1);
    assert(descriptor_index < max_descriptors, "Too much uniforms for % descriptor set. Max: %", descriptor_set, max_descriptors);

    if device.descriptor_buffers_supported {
        layout := *manager.descriptor_set_layouts[descriptor_set];
        assert(layout.slot_offsets[DescriptorSetSlot.UNIFORM] != VulkanBindingManager.DescriptorSetLayout.INVALID_OFFSET,
               "There are no any slots for uniforms in % descriptor set",
               descriptor_set);

        address_info := VkDescriptorAddressInfoEXT.{
            address = cast(VkDeviceAddress) (buffer.device_address + offset),
            range   = cast(VkDeviceSize) size,
            format  = .VK_FORMAT_UNDEFINED,
        };

        descriptor_info := VkDescriptorGetInfoEXT.{
            type                = .VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            data.pUniformBuffer = *address_info,
        };

        descriptor_size := device.descriptor_buffer_properties.uniformBufferDescriptorSize;

        descriptor_memory := bindings.descriptor_buffer.mapped_memory
                           + cast(u64) layout.slot_offsets[DescriptorSetSlot.UNIFORM]
                           + descriptor_index * descriptor_size;

        device.loader.extensions.device.optional.vkGetDescriptorEXT(device.device, *descriptor_info, descriptor_size, descriptor_memory);
    } else {
        buffer_info := VkDescriptorBufferInfo.{
            buffer = buffer.buffer,
            offset = cast(VkDeviceSize) offset,
            range  = cast(VkDeviceSize) size,
        };

        write_descriptor_set := VkWriteDescriptorSet.{
            dstSet          = bindings.descriptor_set,
            dstBinding      = cast(u32) DescriptorSetSlot.UNIFORM,
            dstArrayElement = descriptor_index,
            descriptorCount = 1,
            descriptorType  = .VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            pBufferInfo     = *buffer_info,
        };

        vkUpdateDescriptorSets(device.device, 1, *write_descriptor_set, 0, null);
    }

    return .{
        set        = descriptor_set,
        slot       = DescriptorSetSlot.UNIFORM,
        descriptor = descriptor_index,
    };
}

pushVulkanTextureBinding :: (descriptor_set : DescriptorSet, resource : *TextureView) -> BindingHandle #must {
    device       := cast(*VulkanDevice)         context.pet.render.device;
    manager      := cast(*VulkanBindingManager) context.pet.render.binding_manager;
    texture_view := cast(*VulkanTextureView)    resource;

    bindings : *VulkanBindingManager.DescriptorSetBindings;
    if #complete descriptor_set == {
        case .PER_FRAME;  bindings = *manager.per_frame_bindings[device.frame_index];
        case .PER_SCENE;  bindings = *manager.per_scene_bindings;
        case .PERSISTENT; bindings = *manager.persistent_bindings;
    }
    assert(bindings);

    max_descriptors     : u32               = ---;
    descriptor_name     : string            = ---;
    descriptor_set_slot : DescriptorSetSlot = ---;
    descriptor_size     : u64               = ---;
    image_info          := VkDescriptorImageInfo.{ imageView = texture_view.view };
    descriptor_info     : VkDescriptorGetInfoEXT;
    if texture_view.usage == {
        case .SHADER_READ;
            max_descriptors                    = BindingManager.MAX_TEXTURES;
            descriptor_name                    = "texture";
            descriptor_set_slot                = .TEXTURES;
            descriptor_size                    = device.descriptor_buffer_properties.sampledImageDescriptorSize;
            image_info.imageLayout             = ifx  textureFormatFlags(texture_view.format) & (.DEPTH | .STENCIL)
                                                 then .VK_IMAGE_LAYOUT_DEPTH_STENCIL_READ_ONLY_OPTIMAL
                                                 else .VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
            descriptor_info.type               = .VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE;
            descriptor_info.data.pSampledImage = *image_info;

        case .SHADER_WRITE;
            max_descriptors                    = BindingManager.MAX_IMAGES;
            descriptor_name                    = "image";
            descriptor_set_slot                = .IMAGES;
            descriptor_size                    = device.descriptor_buffer_properties.storageImageDescriptorSize;
            image_info.imageLayout             = .VK_IMAGE_LAYOUT_GENERAL;
            descriptor_info.type               = .VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
            descriptor_info.data.pStorageImage = *image_info;

        case;
            assert(false, "Usage can only be SHADER_READ or SHADER_WRITE");
    }

    descriptor_index := Atomics.atomic_add(*bindings.descriptors_pushed[descriptor_set_slot], 1);
    assert(descriptor_index < max_descriptors, "Too much %s for % descriptor set. Max: %", descriptor_name, descriptor_set, max_descriptors);

    if device.descriptor_buffers_supported {
        layout := *manager.descriptor_set_layouts[descriptor_set];
        assert(layout.slot_offsets[descriptor_set_slot] != VulkanBindingManager.DescriptorSetLayout.INVALID_OFFSET,
               "There are no any slots for %s in % descriptor set",
               descriptor_name,
               descriptor_set);

        descriptor_memory := bindings.descriptor_buffer.mapped_memory
                           + cast(u64) layout.slot_offsets[descriptor_set_slot]
                           + descriptor_index * descriptor_size;

        device.loader.extensions.device.optional.vkGetDescriptorEXT(device.device, *descriptor_info, descriptor_size, descriptor_memory);
    } else {
        write_descriptor_set := VkWriteDescriptorSet.{
            dstSet          = bindings.descriptor_set,
            dstBinding      = cast(u32) descriptor_set_slot,
            dstArrayElement = descriptor_index,
            descriptorCount = 1,
            descriptorType  = descriptor_info.type,
            pImageInfo      = *image_info,
        };

        vkUpdateDescriptorSets(device.device, 1, *write_descriptor_set, 0, null);
    }

    return .{
        set        = descriptor_set,
        slot       = descriptor_set_slot,
        descriptor = descriptor_index,
    };
}

pushVulkanSamplerBinding :: (descriptor_set : DescriptorSet, resource : *Sampler) -> BindingHandle #must {
    device  := cast(*VulkanDevice)         context.pet.render.device;
    manager := cast(*VulkanBindingManager) context.pet.render.binding_manager;
    sampler := cast(*VulkanSampler)        resource;

    bindings : *VulkanBindingManager.DescriptorSetBindings;
    if #complete descriptor_set == {
        case .PER_FRAME;  bindings = *manager.per_frame_bindings[device.frame_index];
        case .PER_SCENE;  bindings = *manager.per_scene_bindings;
        case .PERSISTENT; bindings = *manager.persistent_bindings;
    }
    assert(bindings);

    MAX_DESCRIPTORS  :: BindingManager.MAX_SAMPLERS;
    descriptor_index := Atomics.atomic_add(*bindings.descriptors_pushed[DescriptorSetSlot.SAMPLERS], 1);
    assert(descriptor_index < MAX_DESCRIPTORS, "Too much samplers for % descriptor set. Max: %", descriptor_set, MAX_DESCRIPTORS);

    if device.descriptor_buffers_supported {
        layout := *manager.descriptor_set_layouts[descriptor_set];
        assert(layout.slot_offsets[DescriptorSetSlot.SAMPLERS] != VulkanBindingManager.DescriptorSetLayout.INVALID_OFFSET,
               "There are no any slots for samplers in % descriptor set",
               descriptor_set);

        descriptor_info := VkDescriptorGetInfoEXT.{
            type          = .VK_DESCRIPTOR_TYPE_SAMPLER,
            data.pSampler = *sampler.sampler,
        };

        descriptor_size := device.descriptor_buffer_properties.uniformBufferDescriptorSize;

        descriptor_memory := bindings.descriptor_buffer.mapped_memory
                           + cast(u64) layout.slot_offsets[DescriptorSetSlot.SAMPLERS]
                           + descriptor_index * descriptor_size;

        device.loader.extensions.device.optional.vkGetDescriptorEXT(device.device, *descriptor_info, descriptor_size, descriptor_memory);
    } else {
        sampler_info := VkDescriptorImageInfo.{
            sampler = sampler.sampler,
        };

        write_descriptor_set := VkWriteDescriptorSet.{
            dstSet          = bindings.descriptor_set,
            dstBinding      = cast(u32) DescriptorSetSlot.SAMPLERS,
            dstArrayElement = descriptor_index,
            descriptorCount = 1,
            descriptorType  = .VK_DESCRIPTOR_TYPE_SAMPLER,
            pImageInfo      = *sampler_info,
        };

        vkUpdateDescriptorSets(device.device, 1, *write_descriptor_set, 0, null);
    }

    return .{
        set        = descriptor_set,
        slot       = DescriptorSetSlot.SAMPLERS,
        descriptor = descriptor_index,
    };
}

createVulkanDescriptorSetBindings :: (
    bindings            : *VulkanBindingManager.DescriptorSetBindings,
    descriptor_set      : DescriptorSet,
    descriptor_set_name : string
) {
    device  := cast(*VulkanDevice)         context.pet.render.device;
    manager := cast(*VulkanBindingManager) context.pet.render.binding_manager;

    layout := *manager.descriptor_set_layouts[descriptor_set];

    if device.descriptor_buffers_supported {
        bindings.descriptor_buffer = pushVulkanDescriptorBuffer();

        bindings.descriptor_buffer.size                  = cast(u32) layout.size;
        bindings.descriptor_buffer.current_owner         = QueueType.GRAPHICS;
        bindings.descriptor_buffer.possible_owners.count = 1;
        bindings.descriptor_buffer.possible_owners[0]    = QueueType.GRAPHICS;

        createVulkanDescriptorBuffer(bindings.descriptor_buffer, layout.usage, descriptor_set_name);
    } else {
        create_info := VkDescriptorPoolCreateInfo.{
            maxSets       = 1,
            poolSizeCount = cast(u32) layout.descriptor_pool_sizes.count,
            pPoolSizes    = layout.descriptor_pool_sizes.data.data,
        };

        debugCheckVK(vkCreateDescriptorPool(device.device, *create_info, null, *bindings.descriptor_pool));
        setVulkanObjectName(bindings.descriptor_pool, "% descriptor pool", descriptor_set_name);

        allocation_info := VkDescriptorSetAllocateInfo.{
            descriptorPool     = bindings.descriptor_pool,
            descriptorSetCount = 1,
            pSetLayouts        = *layout.layout,
        };

        debugCheckVK(vkAllocateDescriptorSets(device.device, *allocation_info, *bindings.descriptor_set));
        setVulkanObjectName(bindings.descriptor_set, "% descriptor set", descriptor_set_name);
    }
}

createVulkanDescriptorSetLayout :: (set : DescriptorSet, slots : [] DescriptorSetSlot) {
    assert(slots.count <= BindingManager.MAX_DESCRIPTOR_SET_SLOTS);

    device  := cast(*VulkanDevice)         context.pet.render.device;
    manager := cast(*VulkanBindingManager) context.pet.render.binding_manager;

    pushBindingLayout :: (type : VkDescriptorType, count : u32) #expand {
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
                pushBindingLayout(.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, count);
                layout.usage |= .VK_BUFFER_USAGE_RESOURCE_DESCRIPTOR_BUFFER_BIT_EXT;

            case .SAMPLERS;
                pushBindingLayout(.VK_DESCRIPTOR_TYPE_SAMPLER, BindingManager.MAX_SAMPLERS);
                layout.usage |= .VK_BUFFER_USAGE_SAMPLER_DESCRIPTOR_BUFFER_BIT_EXT;

            case .TEXTURES;
                pushBindingLayout(.VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE, BindingManager.MAX_TEXTURES);
                layout.usage |= .VK_BUFFER_USAGE_RESOURCE_DESCRIPTOR_BUFFER_BIT_EXT;

            case .IMAGES;
                pushBindingLayout(.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, BindingManager.MAX_IMAGES);
                layout.usage |= .VK_BUFFER_USAGE_RESOURCE_DESCRIPTOR_BUFFER_BIT_EXT;
        }
    }
    assert(binding_layouts_it <= binding_layouts.data + binding_layouts.count);

    create_info := VkDescriptorSetLayoutCreateInfo.{
        bindingCount = cast(u32) (binding_layouts_it - binding_layouts.data),
        pBindings    = binding_layouts.data,
    };

    if device.descriptor_buffers_supported {
        create_info.flags |= .VK_DESCRIPTOR_SET_LAYOUT_CREATE_DESCRIPTOR_BUFFER_BIT_EXT;
    }

    debugCheckVK(vkCreateDescriptorSetLayout(device.device, *create_info, null, *layout.layout));

    setVulkanObjectName(layout.layout, "% descriptor set layout", set);

    if device.descriptor_buffers_supported {
        device.loader.extensions.device.optional.vkGetDescriptorSetLayoutSizeEXT(device.device, layout.layout, *layout.size);
        layout.size = alignUpWithPowerOfTwo(layout.size, device.descriptor_buffer_properties.descriptorBufferOffsetAlignment);

        for * layout.slot_offsets {
            it.* = VulkanBindingManager.DescriptorSetLayout.INVALID_OFFSET;
        }

        for slots {
            device.loader.extensions.device.optional.vkGetDescriptorSetLayoutBindingOffsetEXT(device.device,
                                                                                              layout.layout,
                                                                                              cast(u32) it,
                                                                                              *layout.slot_offsets[it]);
        }
    } else {
        layout.descriptor_pool_sizes.count = slots.count;

        descriptor_pool_sizes_it := layout.descriptor_pool_sizes.data.data;
        for slots {
            if #complete it == {
                case .UNIFORM;
                    count := ifx set == .PERSISTENT then cast(u32) BindingManager.MAX_PER_VIEW_UNIFORMS else 1;
                    descriptor_pool_sizes_it.type            = .VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
                    descriptor_pool_sizes_it.descriptorCount = count;

                case .SAMPLERS;
                    descriptor_pool_sizes_it.type            = .VK_DESCRIPTOR_TYPE_SAMPLER;
                    descriptor_pool_sizes_it.descriptorCount = BindingManager.MAX_SAMPLERS;

                case .TEXTURES;
                    descriptor_pool_sizes_it.type            = .VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE;
                    descriptor_pool_sizes_it.descriptorCount = BindingManager.MAX_TEXTURES;

                case .IMAGES;
                    descriptor_pool_sizes_it.type            = .VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
                    descriptor_pool_sizes_it.descriptorCount = BindingManager.MAX_IMAGES;
            }
            descriptor_pool_sizes_it += 1;
        }
    }
}
