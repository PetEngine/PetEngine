VulkanBindingManager :: struct {
    #as using public_data : BindingManager;

    SamplerDescriptorSetLayout :: struct {
        layout                 : VkDescriptorSetLayout;
        descriptor_buffer_size : VkDeviceSize;
    }

    ResourceDescriptorSetLayout :: struct {
        INVALID_OFFSET :: cast(VkDeviceSize) 0xFFFF_FFFF_FFFF_FFFF;

        layout : VkDescriptorSetLayout;
        union {
            struct {
                descriptor_buffer_size         : VkDeviceSize;
                descriptor_buffer_slot_offsets : [MAX_DESCRIPTOR_SET_SLOTS] VkDeviceSize;
            }
            descriptor_pool_sizes : StaticArray(VkDescriptorPoolSize, MAX_DESCRIPTOR_SET_SLOTS);
        }
    }

    SamplerDescriptorSetBindings :: struct {
        union {
            descriptor_buffer : *VulkanBuffer;
            struct {
                descriptor_pool : VkDescriptorPool;
                descriptor_set  : VkDescriptorSet;
            }
        }

        descriptors_pushed : u16;
    }

    ResourceDescriptorSetBindings :: struct {
        union {
            descriptor_buffer : *VulkanBuffer;
            struct {
                descriptor_pool : VkDescriptorPool;
                descriptor_set  : VkDescriptorSet;
            }
        }

        union {
            descriptors_pushed        : [MAX_DESCRIPTOR_SET_SLOTS] u16;
            descriptors_pushed_packed : u64;
        }

        #assert size_of(type_of(descriptors_pushed)) <= size_of(type_of(descriptors_pushed_packed));
    }

    sampler_descriptor_set_layout   : SamplerDescriptorSetLayout;
    resource_descriptor_set_layouts : [MAX_DESCRIPTOR_SETS - 1] ResourceDescriptorSetLayout; // -1 because minus samplers

    samplers_bindings   : SamplerDescriptorSetBindings;
    persistent_bindings : ResourceDescriptorSetBindings;
    per_scene_bindings  : ResourceDescriptorSetBindings;
    per_frame_bindings  : StaticArray(ResourceDescriptorSetBindings, Device.MAX_FRAME_BUFFERING);
}

createVulkanBindingManager :: () {
    manager := pushToArena(*context.pet.arenas.persistent, VulkanBindingManager);
    context.pet.render.binding_manager = manager;

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

DESCRIPTOR_BUFFER_DESCRIPTOR_SIZES :: #string END
Descriptor sizes:
    Sampler:                     %
    Sampled image:               %
    Storage image:               %
    Combined image sampler:      %
    Uniform texel buffer:        %
    Storage texel buffer:        %
    Uniform buffer:              %
    Storage buffer:              %
    Robust uniform texel buffer: %
    Robust storage texel buffer: %
    Robust uniform buffer:       %
    Robust storage buffer:       %
    Input attachment:            %
    Acceleration structure:      %
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

        verboseMessage(DESCRIPTOR_BUFFER_DESCRIPTOR_SIZES,
                       device.descriptor_buffer_properties.samplerDescriptorSize,
                       device.descriptor_buffer_properties.sampledImageDescriptorSize,
                       device.descriptor_buffer_properties.storageImageDescriptorSize,
                       device.descriptor_buffer_properties.combinedImageSamplerDescriptorSize,
                       device.descriptor_buffer_properties.uniformTexelBufferDescriptorSize,
                       device.descriptor_buffer_properties.storageTexelBufferDescriptorSize,
                       device.descriptor_buffer_properties.uniformBufferDescriptorSize,
                       device.descriptor_buffer_properties.storageBufferDescriptorSize,
                       device.descriptor_buffer_properties.robustUniformTexelBufferDescriptorSize,
                       device.descriptor_buffer_properties.robustStorageTexelBufferDescriptorSize,
                       device.descriptor_buffer_properties.robustUniformBufferDescriptorSize,
                       device.descriptor_buffer_properties.robustStorageBufferDescriptorSize,
                       device.descriptor_buffer_properties.inputAttachmentDescriptorSize,
                       device.descriptor_buffer_properties.accelerationStructureDescriptorSize);
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

    createVulkanSamplerDescriptorSetLayout();
    createVulkanResourceDescriptorSetLayout(.PERSISTENT, .[ .UNIFORMS, .TEXTURES, .IMAGES ]);
    createVulkanResourceDescriptorSetLayout(.PER_SCENE,  .[ .TEXTURES,            .IMAGES ]);
    createVulkanResourceDescriptorSetLayout(.PER_FRAME,  .[ .UNIFORMS, .TEXTURES, .IMAGES ]);

    createVulkanSamplerDescriptorSetBindings(*manager.samplers_bindings, "Samplers");
    createVulkanResourceDescriptorSetBindings(*manager.persistent_bindings, .PERSISTENT, "Persistent");
    createVulkanResourceDescriptorSetBindings(*manager.per_scene_bindings, .PER_SCENE, "Per Scene");
    for * manager.per_frame_bindings createVulkanResourceDescriptorSetBindings(it, .PER_FRAME, Basic.tprint("Frame #%", it_index));
}

destroyVulkanBindingManager :: () {
    device  := cast(*VulkanDevice)         context.pet.render.device;
    manager := cast(*VulkanBindingManager) context.pet.render.binding_manager;

    if !device.descriptor_buffers_supported {
        vkDestroyDescriptorPool(device.device, manager.samplers_bindings.descriptor_pool, null);
        vkDestroyDescriptorPool(device.device, manager.persistent_bindings.descriptor_pool, null);
        vkDestroyDescriptorPool(device.device, manager.per_scene_bindings.descriptor_pool, null);
        for manager.per_frame_bindings vkDestroyDescriptorPool(device.device, it.descriptor_pool, null);
    }

    vkDestroyDescriptorSetLayout(device.device, manager.sampler_descriptor_set_layout.layout, null);
    for manager.resource_descriptor_set_layouts {
        vkDestroyDescriptorSetLayout(device.device, it.layout, null);
    }
}

resetVulkanBindings :: ($descriptor_set : DescriptorSet) {
    assertThreadKind(.MAIN);

    manager := cast(*VulkanBindingManager) context.pet.render.binding_manager;

    #ifx descriptor_set == .SAMPLERS {
        bindings : *VulkanBindingManager.SamplerDescriptorSetBindings;
    } else {
        bindings : *VulkanBindingManager.ResourceDescriptorSetBindings;
    }
    #if #complete descriptor_set == {
        case .SAMPLERS;
            bindings = *manager.samplers_bindings;

        case .PERSISTENT;
            bindings = *manager.persistent_bindings;

        case .PER_SCENE;
            bindings = *manager.per_scene_bindings;

        case .PER_FRAME;
            // @TODO: #FrameBuffering.
            assert(manager.per_frame_bindings.count == cast,no_check(s64) context.pet.render.device.frame_buffering, "It's illegal to change frame buffering for now");
            manager.per_frame_bindings.count = cast,no_check(s64) context.pet.render.device.frame_buffering;

            bindings = *manager.per_frame_bindings[context.pet.render.device.frame_index];
    }
    assert(bindings);

    #if descriptor_set == .SAMPLERS {
        bindings.descriptors_pushed = 0;
    } else {
        bindings.descriptors_pushed_packed = 0;
    }
}

pushVulkanBufferDescriptor :: ($descriptor_set : DescriptorSet, resource : *Buffer, offset : u32, size : u32) -> u16 {
    device  := cast(*VulkanDevice)         context.pet.render.device;
    manager := cast(*VulkanBindingManager) context.pet.render.binding_manager;
    buffer  := cast(*VulkanBuffer)         resource;

    assert(buffer.usage == .UNIFORM, "Only uniform buffer bindings are supported right now");

    if size > device.limits.maxUniformBufferRange {
        assertMessage("Size (%) should be <= VkDeviceLimits.maxUniformBufferRange (%)",
                      size,
                      device.limits.maxUniformBufferRange);
    }

    bindings        : *VulkanBindingManager.ResourceDescriptorSetBindings;
    max_descriptors : u32 = ---;
    #if #complete descriptor_set == {
        case .SAMPLERS;
            #assert false "Samplers are bound using bindVulkanSamplers function";

        case .PERSISTENT;
            bindings        = *manager.persistent_bindings;
            max_descriptors = BindingManager.MAX_PER_VIEW_UNIFORMS;

        case .PER_SCENE;
            bindings        = *manager.per_scene_bindings;
            max_descriptors = 1;

        case .PER_FRAME;
            bindings        = *manager.per_frame_bindings[device.frame_index];
            max_descriptors = 1;
    }
    assert(bindings);

    descriptor_index := Atomics.atomic_add(*bindings.descriptors_pushed[DescriptorSetSlot.UNIFORMS], 1);
    assert(descriptor_index < max_descriptors, "Too much uniforms for % descriptor set. Max: %", descriptor_set, max_descriptors);

    if device.descriptor_buffers_supported {
        layout := getResourceDescriptorSetLayout(descriptor_set);
        assert(layout.descriptor_buffer_slot_offsets[DescriptorSetSlot.UNIFORMS] != VulkanBindingManager.ResourceDescriptorSetLayout.INVALID_OFFSET,
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
                           + cast(u64) layout.descriptor_buffer_slot_offsets[DescriptorSetSlot.UNIFORMS]
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
            dstBinding      = cast(u32) DescriptorSetSlot.UNIFORMS,
            dstArrayElement = descriptor_index,
            descriptorCount = 1,
            descriptorType  = .VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            pBufferInfo     = *buffer_info,
        };

        vkUpdateDescriptorSets(device.device, 1, *write_descriptor_set, 0, null);
    }

    return descriptor_index;
}

pushVulkanTextureBinding :: ($descriptor_set : DescriptorSet, resource : *TextureView) -> BindingHandle {
    device       := cast(*VulkanDevice)         context.pet.render.device;
    manager      := cast(*VulkanBindingManager) context.pet.render.binding_manager;
    texture_view := cast(*VulkanTextureView)    resource;

    bindings : *VulkanBindingManager.ResourceDescriptorSetBindings;
    #if #complete descriptor_set == {
        case .SAMPLERS;   #assert false "Samplers are bound using bindVulkanSamplers function";
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
        layout := getResourceDescriptorSetLayout(descriptor_set);
        assert(layout.descriptor_buffer_slot_offsets[descriptor_set_slot] != VulkanBindingManager.ResourceDescriptorSetLayout.INVALID_OFFSET,
               "There are no any slots for %s in % descriptor set",
               descriptor_name,
               descriptor_set);

        descriptor_memory := bindings.descriptor_buffer.mapped_memory
                           + cast(u64) layout.descriptor_buffer_slot_offsets[descriptor_set_slot]
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

bindVulkanSamplers :: () {
    assertThreadKind(.MAIN);

    device           := cast(*VulkanDevice)          context.pet.render.device;
    manager          := cast(*VulkanBindingManager)  context.pet.render.binding_manager;
    resource_manager := cast(*VulkanResourceManager) context.pet.render.resource_manager;

    assert(manager.samplers_bindings.descriptors_pushed == 0, "Samplers were already bound");
    assert(resource_manager.samplers.count == ResourceManager.MAX_SAMPLERS);
    manager.samplers_bindings.descriptors_pushed += cast(u16) resource_manager.samplers.count;

    if device.descriptor_buffers_supported {
        layout := *manager.sampler_descriptor_set_layout;

        descriptor_info   := VkDescriptorGetInfoEXT.{ type = .VK_DESCRIPTOR_TYPE_SAMPLER };
        descriptor_size   := device.descriptor_buffer_properties.samplerDescriptorSize;
        descriptor_memory := manager.samplers_bindings.descriptor_buffer.mapped_memory;

        for resource_manager.samplers {
            descriptor_info.data.pSampler = *it.sampler;
            device.loader.extensions.device.optional.vkGetDescriptorEXT(device.device, *descriptor_info, descriptor_size, descriptor_memory);
            descriptor_memory += descriptor_size;
        }
    } else {
        sampler_infos : [ResourceManager.MAX_SAMPLERS] VkDescriptorImageInfo = ---;
        assert(sampler_infos.count == resource_manager.samplers.count);

        for resource_manager.samplers {
            sampler_infos[it_index].sampler = it.sampler;
        }

        write_descriptor_set := VkWriteDescriptorSet.{
            dstSet          = manager.samplers_bindings.descriptor_set,
            dstBinding      = 0,
            dstArrayElement = 0,
            descriptorCount = sampler_infos.count,
            descriptorType  = .VK_DESCRIPTOR_TYPE_SAMPLER,
            pImageInfo      = sampler_infos.data,
        };

        vkUpdateDescriptorSets(device.device, 1, *write_descriptor_set, 0, null);
    }
}

#scope_file

createVulkanSamplerDescriptorSetLayout :: () {
    device  := cast(*VulkanDevice)         context.pet.render.device;
    manager := cast(*VulkanBindingManager) context.pet.render.binding_manager;

    layout := *manager.sampler_descriptor_set_layout;

    binding_layout : VkDescriptorSetLayoutBinding;
    binding_layout.binding         = 0;
    binding_layout.descriptorType  = .VK_DESCRIPTOR_TYPE_SAMPLER;
    binding_layout.descriptorCount = ResourceManager.MAX_SAMPLERS;
    binding_layout.stageFlags      = .VK_SHADER_STAGE_VERTEX_BIT | .VK_SHADER_STAGE_FRAGMENT_BIT;

    create_info := VkDescriptorSetLayoutCreateInfo.{
        bindingCount = 1,
        pBindings    = *binding_layout,
    };

    if device.descriptor_buffers_supported {
        create_info.flags |= .VK_DESCRIPTOR_SET_LAYOUT_CREATE_DESCRIPTOR_BUFFER_BIT_EXT;
    }

    debugCheckVK(vkCreateDescriptorSetLayout(device.device, *create_info, null, *layout.layout));
    setVulkanObjectName(layout.layout, "Descriptor Set Layout/%", DescriptorSet.SAMPLERS);

    if device.descriptor_buffers_supported {
        device.loader.extensions.device.optional.vkGetDescriptorSetLayoutSizeEXT(device.device, layout.layout, *layout.descriptor_buffer_size);
        assertAligned(layout.descriptor_buffer_size, device.descriptor_buffer_properties.descriptorBufferOffsetAlignment);

        #if DEBUG_BUILD {
            offset : VkDeviceSize;
            device.loader.extensions.device.optional.vkGetDescriptorSetLayoutBindingOffsetEXT(device.device, layout.layout, 0, *offset);
            assert(offset == 0);
        }
    }
}

createVulkanResourceDescriptorSetLayout :: ($set : DescriptorSet, slots : [] DescriptorSetSlot) {
    #assert set != .SAMPLERS "For samplers use createVulkanSamplerDescriptorSetLayout";
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

    layout := getResourceDescriptorSetLayout(set);

    binding_layouts    : [BindingManager.MAX_DESCRIPTOR_SET_SLOTS] VkDescriptorSetLayoutBinding;
    binding_layouts_it := binding_layouts.data;

    for slots {
        if #complete it == {
            case .UNIFORMS;
                COUNT :: #ifx set == .PERSISTENT then BindingManager.MAX_PER_VIEW_UNIFORMS else 1;
                pushBindingLayout(.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, COUNT);

            case .TEXTURES;
                pushBindingLayout(.VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE, BindingManager.MAX_TEXTURES);

            case .IMAGES;
                pushBindingLayout(.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, BindingManager.MAX_IMAGES);
        }
    }
    assert(binding_layouts_it <= binding_layouts.data + binding_layouts.count);

    create_info := VkDescriptorSetLayoutCreateInfo.{
        bindingCount = cast(u32, binding_layouts_it - binding_layouts.data),
        pBindings    = binding_layouts.data,
    };

    if device.descriptor_buffers_supported {
        create_info.flags |= .VK_DESCRIPTOR_SET_LAYOUT_CREATE_DESCRIPTOR_BUFFER_BIT_EXT;
    }

    debugCheckVK(vkCreateDescriptorSetLayout(device.device, *create_info, null, *layout.layout));
    setVulkanObjectName(layout.layout, "Descriptor Set Layout/%", set);

    if device.descriptor_buffers_supported {
        device.loader.extensions.device.optional.vkGetDescriptorSetLayoutSizeEXT(device.device, layout.layout, *layout.descriptor_buffer_size);
        assertAligned(layout.descriptor_buffer_size, device.descriptor_buffer_properties.descriptorBufferOffsetAlignment);

        for * layout.descriptor_buffer_slot_offsets {
            it.* = VulkanBindingManager.ResourceDescriptorSetLayout.INVALID_OFFSET;
        }

        for slots {
            device.loader.extensions.device.optional.vkGetDescriptorSetLayoutBindingOffsetEXT(device.device,
                                                                                              layout.layout,
                                                                                              cast(u32) it,
                                                                                              *layout.descriptor_buffer_slot_offsets[it]);
        }
    } else {
        layout.descriptor_pool_sizes.count = slots.count;

        descriptor_pool_sizes_it := layout.descriptor_pool_sizes.data.data;
        for slots {
            if #complete it == {
                case .UNIFORMS;
                    COUNT :: #ifx set == .PERSISTENT then BindingManager.MAX_PER_VIEW_UNIFORMS else 1;
                    descriptor_pool_sizes_it.type            = .VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
                    descriptor_pool_sizes_it.descriptorCount = COUNT;

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

createVulkanSamplerDescriptorSetBindings :: (bindings : *VulkanBindingManager.SamplerDescriptorSetBindings, set_name : string) {
    device  := cast(*VulkanDevice)         context.pet.render.device;
    manager := cast(*VulkanBindingManager) context.pet.render.binding_manager;

    layout := *manager.sampler_descriptor_set_layout;

    if device.descriptor_buffers_supported {
        bindings.descriptor_buffer = pushVulkanDescriptorBuffer();

        bindings.descriptor_buffer.size                  = cast(u32) layout.descriptor_buffer_size;
        bindings.descriptor_buffer.current_owner         = QueueType.GRAPHICS;
        bindings.descriptor_buffer.possible_owners.count = 1;
        bindings.descriptor_buffer.possible_owners[0]    = QueueType.GRAPHICS;

        createVulkanDescriptorBuffer(bindings.descriptor_buffer, .VK_BUFFER_USAGE_SAMPLER_DESCRIPTOR_BUFFER_BIT_EXT, set_name);
    } else {
        descriptor_pool_size := VkDescriptorPoolSize.{
            type            = .VK_DESCRIPTOR_TYPE_SAMPLER,
            descriptorCount = ResourceManager.MAX_SAMPLERS,
        };

        create_info := VkDescriptorPoolCreateInfo.{
            maxSets       = 1,
            poolSizeCount = 1,
            pPoolSizes    = *descriptor_pool_size,
        };

        debugCheckVK(vkCreateDescriptorPool(device.device, *create_info, null, *bindings.descriptor_pool));
        setVulkanObjectName(bindings.descriptor_pool, "Descriptor Pool/%", set_name);

        allocation_info := VkDescriptorSetAllocateInfo.{
            descriptorPool     = bindings.descriptor_pool,
            descriptorSetCount = 1,
            pSetLayouts        = *layout.layout,
        };

        debugCheckVK(vkAllocateDescriptorSets(device.device, *allocation_info, *bindings.descriptor_set));
        setVulkanObjectName(bindings.descriptor_set, "Descriptor Set/%", set_name);
    }
}

createVulkanResourceDescriptorSetBindings :: (
    bindings : *VulkanBindingManager.ResourceDescriptorSetBindings,
    $set     : DescriptorSet,
    set_name : string
) {
    #assert set != .SAMPLERS "For samplers use createVulkanSamplerDescriptorSetBindings";

    device  := cast(*VulkanDevice)         context.pet.render.device;
    manager := cast(*VulkanBindingManager) context.pet.render.binding_manager;

    layout := getResourceDescriptorSetLayout(set);

    if device.descriptor_buffers_supported {
        bindings.descriptor_buffer = pushVulkanDescriptorBuffer();

        bindings.descriptor_buffer.size                  = cast(u32) layout.descriptor_buffer_size;
        bindings.descriptor_buffer.current_owner         = QueueType.GRAPHICS;
        bindings.descriptor_buffer.possible_owners.count = 1;
        bindings.descriptor_buffer.possible_owners[0]    = QueueType.GRAPHICS;

        createVulkanDescriptorBuffer(bindings.descriptor_buffer, .VK_BUFFER_USAGE_RESOURCE_DESCRIPTOR_BUFFER_BIT_EXT, set_name);
    } else {
        create_info := VkDescriptorPoolCreateInfo.{
            maxSets       = 1,
            poolSizeCount = cast(u32) layout.descriptor_pool_sizes.count,
            pPoolSizes    = layout.descriptor_pool_sizes.data.data,
        };

        debugCheckVK(vkCreateDescriptorPool(device.device, *create_info, null, *bindings.descriptor_pool));
        setVulkanObjectName(bindings.descriptor_pool, "Descriptor Pool/%", set_name);

        allocation_info := VkDescriptorSetAllocateInfo.{
            descriptorPool     = bindings.descriptor_pool,
            descriptorSetCount = 1,
            pSetLayouts        = *layout.layout,
        };

        debugCheckVK(vkAllocateDescriptorSets(device.device, *allocation_info, *bindings.descriptor_set));
        setVulkanObjectName(bindings.descriptor_set, "Descriptor Set/%", set_name);
    }
}

getResourceDescriptorSetLayout :: (set : DescriptorSet) -> *VulkanBindingManager.ResourceDescriptorSetLayout {
    manager := cast(*VulkanBindingManager) context.pet.render.binding_manager;
    return *manager.resource_descriptor_set_layouts[set - 1]; // see declaration of resource_descriptor_set_layouts
}
