// @TODO: #BindingManager.
//     - Per draw and/or per material bindings.

BindingManager :: struct {
    MAX_DESCRIPTOR_SETS      :: #run Basic.enum_highest_value(DescriptorSet)     + 1;
    MAX_DESCRIPTOR_SET_SLOTS :: #run Basic.enum_highest_value(DescriptorSetSlot) + 1;

    // @Important: Should be synced with defines in graphics_bindings.shader_header
    MAX_PER_VIEW_UNIFORMS :: 64;
    MAX_SAMPLERS          :: 64;
    MAX_TEXTURES          :: 1024;
    MAX_IMAGES            :: 512;

    //
    // VTable
    //

    destroyPlatformBindingManager : (device : *Device, manager : *BindingManager);

    resetPlatformBindings  : (device : *Device, manager : *BindingManager, descriptor_set : DescriptorSet);
    commitPlatformBindings : (device : *Device, manager : *BindingManager, resource_manager : *ResourceManager, descriptor_set : DescriptorSet);
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
    INVALID_DESCRIPTOR :: -1;

    set        : DescriptorSet     = INVALID_SET;
    slot       : DescriptorSetSlot = INVALID_SLOT;
    descriptor : s16               = INVALID_DESCRIPTOR;
}

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

commitBindings :: (device : *Device, manager : *BindingManager, resource_manager : *ResourceManager, descriptor_set : DescriptorSet) {
    manager.commitPlatformBindings(device, manager, resource_manager, descriptor_set);
}

#scope_file

#load "vulkan/binding_manager.jai";
