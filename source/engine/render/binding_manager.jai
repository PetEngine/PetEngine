// @TODO: #BindingManager.
//     - Per view & per material bindings.

BindingManager :: struct {
    MAX_DESCRIPTOR_SETS      :: #run Basic.enum_highest_value(DescriptorSet)     + 1;
    MAX_DESCRIPTOR_SET_SLOTS :: #run Basic.enum_highest_value(DescriptorSetSlot) + 1;

    // @Important: Should be synced with defines in graphics_bindings.shader_header
    MAX_PER_VIEW_UNIFORMS :: Device.MAX_FRAME_BUFFERING * PerViewUniform.MAX_VERSIONS;
    MAX_SAMPLERS          :: 64;
    MAX_TEXTURES          :: 1024;
    MAX_IMAGES            :: 512;

    handle_versions : [MAX_DESCRIPTOR_SETS] u32;

    //
    // VTable
    //

    destroyPlatformBindingManager : (device : *Device, manager : *BindingManager);

    resetPlatformBindings : (device : *Device, manager : *BindingManager, descriptor_set : DescriptorSet);

    pushPlatformBufferBinding  : (device : *Device, manager : *BindingManager, resource : *Buffer, descriptor_set : DescriptorSet) -> BindingHandle #must;
    pushPlatformTextureBinding : (device : *Device, manager : *BindingManager, resource : *TextureView, descriptor_set : DescriptorSet) -> BindingHandle #must;
    pushPlatformSamplerBinding : (device : *Device, manager : *BindingManager, resource : *Sampler, descriptor_set : DescriptorSet) -> BindingHandle #must;
}

// @Important: Should be synced with defines in graphics_bindings.shader_header
DescriptorSet :: enum u8 {
    PER_FRAME;
    PER_SCENE;
    PERSISTENT;
}

// @Important: Should be synced with defines in graphics_bindings.shader_header
DescriptorSetSlot :: enum u8 {
    UNIFORM;
    SAMPLERS;
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

createBindingManager :: (device : *Device, resource_manager : *ResourceManager) -> *BindingManager {
    manager : *BindingManager;

    if #complete device.graphics_api == {
        case .VULKAN;
            manager = createVulkanBindingManager(cast(*VulkanDevice) device, cast(*VulkanResourceManager) resource_manager);
    }

    return manager;
}

destroyBindingManager :: (device : *Device, manager : *BindingManager) {
    manager.destroyPlatformBindingManager(device, manager);
}

resetBindings :: (device : *Device, manager : *BindingManager, descriptor_set : DescriptorSet) {
    manager.resetPlatformBindings(device, manager, descriptor_set);
}

pushBinding :: (
    device           : *Device,
    manager          : *BindingManager,
    resource_manager : *ResourceManager,
    resource         : *$Resource,
    $descriptor_set  : DescriptorSet
) -> BindingHandle #must {
    assert(resourceMemoryCommitted(resource_manager, resource.lifetime),
           "All % bindings should be pushed after % resource memory is commited",
           descriptor_set,
           resource.lifetime);

    #if Resource == {
        case Buffer;
            return manager.pushPlatformBufferBinding(device, manager, resource, descriptor_set);

        case TextureView;
            return manager.pushPlatformTextureBinding(device, manager, resource, descriptor_set);

        case Sampler;
            return manager.pushPlatformSamplerBinding(device, manager, resource, descriptor_set);

        case;
            #assert false "Resource can be only Buffer, TextureView or Sampler";
    }
}

#scope_file

#load "vulkan/binding_manager.jai";
