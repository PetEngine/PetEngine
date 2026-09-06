BindingManager :: struct {
    MAX_DESCRIPTOR_SETS      :: #run Basic.enum_highest_value(DescriptorSet)     + 1;
    MAX_DESCRIPTOR_SET_SLOTS :: #run Basic.enum_highest_value(DescriptorSetSlot) + 1;

    // @Important: Should be synced with defines in graphics_bindings.shader_header
    MAX_PER_VIEW_UNIFORMS :: Device.MAX_FRAME_BUFFERING * PerViewUniform.MAX_VERSIONS;
    MAX_TEXTURES          :: 1024;
    MAX_IMAGES            :: 512;

    uniform_buffer_offset_alignment : u32;
}

// @Important: Should be synced with defines in graphics_bindings.shader_header
DescriptorSet :: enum u8 {
    SAMPLERS;
    PERSISTENT;
    PER_SCENE;
    PER_FRAME;
}

// @Important: Should be synced with defines in graphics_bindings.shader_header
DescriptorSetSlot :: enum u8 {
    UNIFORMS;
    TEXTURES;
    IMAGES;
}

BindingHandle :: struct {
    INVALID_SET        :: BindingManager.MAX_DESCRIPTOR_SETS;
    INVALID_SLOT       :: BindingManager.MAX_DESCRIPTOR_SET_SLOTS;
    INVALID_DESCRIPTOR :: 0xFFFF;

    set        : DescriptorSet     = INVALID_SET;
    slot       : DescriptorSetSlot = INVALID_SLOT;
    descriptor : u16               = INVALID_DESCRIPTOR;
}
#assert size_of(BindingHandle) <= size_of(u64);

createBindingManager :: inline () {
    assert(!context.pet.render.binding_manager);

    #if #complete GRAPHICS_API == {
        case .VULKAN; createVulkanBindingManager();
    }
}

destroyBindingManager :: () {
    #if #complete GRAPHICS_API == {
        case .VULKAN; destroyVulkanBindingManager();
    }
}

resetBindings :: ($descriptor_set : DescriptorSet) {
    #if #complete GRAPHICS_API == {
        case .VULKAN; resetVulkanBindings(descriptor_set);
    }
}

pushBinding :: ($descriptor_set : DescriptorSet, buffer : *Buffer, offset : u32 = 0, size : u32 = CopyRegion.REMAINING_BYTES) -> BindingHandle {
    #assert descriptor_set != .SAMPLERS "Samplers are bound using bindSamplers function";

    assert(resourceMemoryCommitted(buffer.lifetime),
           "All % bindings should be pushed after % resource memory is commited",
           descriptor_set,
           buffer.lifetime);

    assert(offset < buffer.size);

    if offset & (context.pet.render.binding_manager.uniform_buffer_offset_alignment - 1) {
        assertMessage("Offset (%) should be multiple of BindingManager.uniform_buffer_offset_alignment (%)",
                      offset,
                      context.pet.render.binding_manager.uniform_buffer_offset_alignment);
    }

    if size == CopyRegion.REMAINING_BYTES {
        size = buffer.size - offset;
    } else {
        assert(size <= buffer.size - offset);
    }

    binding := BindingHandle.{
        set  = descriptor_set,
        slot = .UNIFORMS,
    };

    #if #complete GRAPHICS_API == {
        case .VULKAN; binding.descriptor = pushVulkanBufferDescriptor(descriptor_set, buffer, offset, size);
    }

    return binding;
}

pushBinding :: ($descriptor_set : DescriptorSet, resource : *TextureView) -> BindingHandle {
    #assert descriptor_set != .SAMPLERS "Samplers are bound using bindSamplers function";

    assert(resourceMemoryCommitted(resource.lifetime),
           "All % bindings should be pushed after % resource memory is commited",
           descriptor_set,
           resource.lifetime);

    #if #complete GRAPHICS_API == {
        case .VULKAN; return pushVulkanTextureBinding(descriptor_set, resource);
    }
}

bindSamplers :: () {
    assert(resourceMemoryCommitted(.PERSISTENT), "All % bindings should be pushed after % resource memory is commited",
           DescriptorSet.SAMPLERS,
           ResourceManager.Lifetime.PERSISTENT);

    #if #complete GRAPHICS_API == {
        case .VULKAN; bindVulkanSamplers();
    }
}

#scope_file

#if #complete GRAPHICS_API == {
    case .VULKAN; #load "vulkan/binding_manager.jai";
}
