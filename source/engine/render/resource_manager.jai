ResourceManager :: struct {
    MAX_BUFFERS  :: 64; // For each memory kind (except resolution dependent)
    MAX_TEXTURES :: 64; // For each memory kind

    MemoryKind :: enum u8 {
        PERSISTENT;
        PERSISTENT_RESOLUTION_DEPENDENT; // For textures only
        PER_SCENE;
        PER_SCENE_RESOLUTION_DEPENDENT;  // For textures only
        PER_FRAME;
    }

    Pool :: enum u8 {
        DEFAULT;
        UPLOAD;
        READ_BACK;
    }

    //
    // VTable
    //

    destroyPlatformResourceManager            : #type (device : *Device, manager : *ResourceManager);
    commitPlatformResourceMemory              : #type (device : *Device, manager : *ResourceManager, memory_kind : MemoryKind);
    resetPlatformResourceMemory               : #type (device : *Device, manager : *ResourceManager, memory_kind : MemoryKind);
    resizePlatformResolutionDependentTextures : #type (device : *Device, manager : *ResourceManager);

    pushPlatformBuffer   : #type (device : *Device, manager : *ResourceManager, memory_kind : MemoryKind) -> *Buffer #must;
    createPlatformBuffer : #type (device : *Device, manager : *ResourceManager, buffer : *Buffer);

    pushPlatformTexture   : #type (device : *Device, manager : *ResourceManager, memory_kind : MemoryKind) -> *Texture #must;
    createPlatformTexture : #type (device : *Device, manager : *ResourceManager, texture : *Texture);
}

createResourceManager :: (device : *Device) -> *ResourceManager #must {
    manager : *ResourceManager;

    if #complete device.graphics_api == {
        case .VULKAN;
            manager = createVulkanResourceManager(cast(*VulkanDevice) device);
    }

    return manager;
}

destroyResourceManager :: inline (device : *Device, manager : *ResourceManager) {
    manager.destroyPlatformResourceManager(device, manager);
}

commitResourceMemory :: inline (device : *Device, manager : *ResourceManager, memory_kind : ResourceManager.MemoryKind) {
    manager.commitPlatformResourceMemory(device, manager, memory_kind);
}

resetResourceMemory :: inline (device : *Device, manager : *ResourceManager, memory_kind : ResourceManager.MemoryKind) {
    manager.resetPlatformResourceMemory(device, manager, memory_kind);
}

resizeResolutionDependentTextures :: inline (device : *Device, manager : *ResourceManager) {
    manager.resizePlatformResolutionDependentTextures(device, manager);
}

#load "buffer.jai";
#load "texture.jai";

#scope_file

#load "vulkan/resource_manager.jai";
