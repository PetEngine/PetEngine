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
        slot_offsets : [MAX_DESCRIPTOR_SET_SLOTS] VkDeviceSize;
    }

    DescriptorSetBindings :: struct {
        descriptor_buffer  : *VulkanBuffer;
        descriptors_pushed : [MAX_DESCRIPTOR_SET_SLOTS] u16;

        #place descriptors_pushed; descriptors_pushed_packed : u64;
        #assert size_of(type_of(descriptors_pushed_packed)) == size_of(type_of(descriptors_pushed));
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

    bindings : *VulkanBindingManager.DescriptorSetBindings;
    if #complete descriptor_set == {
        case .PER_FRAME;
            // @TODO: #FrameBuffering.
            //    - If manager.per_frame_*.count < device.frame_buffering then allocate new memory
            //    - If manager.per_frame_*.count > device.frame_buffering then free unusused memory
            assert(manager.per_frame_bindings.count == cast,no_check(s64) device.frame_buffering, "It's illegal to change frame buffering for now");
            manager.per_frame_bindings.count = cast,no_check(s64) device.frame_buffering;

            bindings = *manager.per_frame_bindings[device.frame_index];

        case .PER_SCENE;
            bindings = *manager.per_scene_bindings;

        case .PERSISTENT;
            bindings = *manager.persistent_bindings;
    }
    assert(bindings);

    bindings.descriptors_pushed_packed = 0;
}

pushVulkanBufferBinding  :: (
    device_        : *Device,
    manager_       : *BindingManager,
    resource       : *Buffer,
    descriptor_set : DescriptorSet
) -> BindingHandle #must {
    device  := cast(*VulkanDevice)         device_;
    manager := cast(*VulkanBindingManager) manager_;
    buffer  := cast(*VulkanBuffer)         resource;

    assertThreadKind(.MAIN);

    assert(buffer.usage == .UNIFORM, "Only uniform bindings are supported right now");

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

    layout := *manager.descriptor_set_layouts[descriptor_set];
    assert(layout.slot_offsets[DescriptorSetSlot.UNIFORM] != VulkanBindingManager.DescriptorSetLayout.INVALID_OFFSET,
           "There are no any slots for uniforms in % descriptor set",
           descriptor_set);

    descriptor_index := bindings.descriptors_pushed[DescriptorSetSlot.UNIFORM];
    assert(descriptor_index < max_descriptors, "Too much uniforms for % descriptor set. Max: %", descriptor_set, max_descriptors);

    address_info := VkDescriptorAddressInfoEXT.{
        address = cast(VkDeviceAddress) buffer.device_address,
        range   = cast(VkDeviceSize) buffer.size,
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

    device.loader.extensions.device.required.vkGetDescriptorEXT(device.device, *descriptor_info, descriptor_size, descriptor_memory);

    bindings.descriptors_pushed[DescriptorSetSlot.UNIFORM] += 1;

    return .{
        set        = descriptor_set,
        slot       = DescriptorSetSlot.UNIFORM,
        descriptor = descriptor_index,
    };
}

pushVulkanTextureBinding :: (
    device_        : *Device,
    manager_       : *BindingManager,
    resource       : *TextureView,
    descriptor_set : DescriptorSet
) -> BindingHandle #must {
    device       := cast(*VulkanDevice)         device_;
    manager      := cast(*VulkanBindingManager) manager_;
    texture_view := cast(*VulkanTextureView)    resource;

    assertThreadKind(.MAIN);

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

    layout := *manager.descriptor_set_layouts[descriptor_set];
    assert(layout.slot_offsets[descriptor_set_slot] != VulkanBindingManager.DescriptorSetLayout.INVALID_OFFSET,
           "There are no any slots for %s in % descriptor set",
           descriptor_name,
           descriptor_set);

    descriptor_index := bindings.descriptors_pushed[descriptor_set_slot];
    assert(descriptor_index < max_descriptors, "Too much %s for % descriptor set. Max: %", descriptor_name, descriptor_set, max_descriptors);

    descriptor_memory := bindings.descriptor_buffer.mapped_memory
                       + cast(u64) layout.slot_offsets[descriptor_set_slot]
                       + descriptor_index * descriptor_size;

    device.loader.extensions.device.required.vkGetDescriptorEXT(device.device, *descriptor_info, descriptor_size, descriptor_memory);

    bindings.descriptors_pushed[descriptor_set_slot] += 1;

    return .{
        set        = descriptor_set,
        slot       = descriptor_set_slot,
        descriptor = descriptor_index,
    };
}

pushVulkanSamplerBinding :: (
    device_        : *Device,
    manager_       : *BindingManager,
    resource       : *Sampler,
    descriptor_set : DescriptorSet
) -> BindingHandle #must {
    device  := cast(*VulkanDevice)         device_;
    manager := cast(*VulkanBindingManager) manager_;
    sampler := cast(*VulkanSampler)        resource;

    assertThreadKind(.MAIN);

    bindings : *VulkanBindingManager.DescriptorSetBindings;
    if #complete descriptor_set == {
        case .PER_FRAME;  bindings = *manager.per_frame_bindings[device.frame_index];
        case .PER_SCENE;  bindings = *manager.per_scene_bindings;
        case .PERSISTENT; bindings = *manager.persistent_bindings;
    }
    assert(bindings);

    layout := *manager.descriptor_set_layouts[descriptor_set];
    assert(layout.slot_offsets[DescriptorSetSlot.SAMPLERS] != VulkanBindingManager.DescriptorSetLayout.INVALID_OFFSET,
           "There are no any slots for samplers in % descriptor set",
           descriptor_set);

    descriptor_index := bindings.descriptors_pushed[DescriptorSetSlot.SAMPLERS];
    MAX_DESCRIPTORS  :: BindingManager.MAX_SAMPLERS;
    assert(descriptor_index < MAX_DESCRIPTORS, "Too much samplers for % descriptor set. Max: %", descriptor_set, MAX_DESCRIPTORS);

    descriptor_info := VkDescriptorGetInfoEXT.{
        type          = .VK_DESCRIPTOR_TYPE_SAMPLER,
        data.pSampler = *sampler.sampler,
    };

    descriptor_size := device.descriptor_buffer_properties.uniformBufferDescriptorSize;

    descriptor_memory := bindings.descriptor_buffer.mapped_memory
                       + cast(u64) layout.slot_offsets[DescriptorSetSlot.SAMPLERS]
                       + descriptor_index * descriptor_size;

    device.loader.extensions.device.required.vkGetDescriptorEXT(device.device, *descriptor_info, descriptor_size, descriptor_memory);

    bindings.descriptors_pushed[DescriptorSetSlot.SAMPLERS] += 1;

    return .{
        set        = descriptor_set,
        slot       = DescriptorSetSlot.SAMPLERS,
        descriptor = descriptor_index,
    };
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
