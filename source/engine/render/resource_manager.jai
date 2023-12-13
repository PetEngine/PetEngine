// @TODO: Get rid of resolution dependent memory kinds. Leave it just as a texture flag and translate it to real device memory in backends.
//        Also, it seems like after that it will be better to rename MemoryKind to Lifetime.

ResourceManager :: struct {
    MAX_BUFFERS  :: 64; // For each memory kind (except resolution dependent)
    MAX_TEXTURES :: 64; // For each memory kind

    MAX_RESOURCE_NAME_LENGTH      :: 512;
    MAX_RESOURCE_FULL_NAME_LENGTH :: 2 * MAX_RESOURCE_NAME_LENGTH;

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

    destroyPlatformResourceManager            : (device : *Device, manager : *ResourceManager);
    commitPlatformResourceMemory              : (device : *Device, manager : *ResourceManager, memory_kind : MemoryKind);
    resetPlatformResourceMemory               : (device : *Device, manager : *ResourceManager, memory_kind : MemoryKind);
    resizePlatformResolutionDependentTextures : (device : *Device, manager : *ResourceManager);

    pushPlatformBuffer   : (device : *Device, manager : *ResourceManager, memory_kind : MemoryKind) -> *Buffer #must;
    createPlatformBuffer : (device : *Device, manager : *ResourceManager, buffer : *Buffer, name : string, memory_kind : MemoryKind);

    pushPlatformTexture   : (device : *Device, manager : *ResourceManager, memory_kind : MemoryKind) -> *Texture #must;
    createPlatformTexture : (device : *Device, manager : *ResourceManager, texture : *Texture, name : string, memory_kind : MemoryKind);
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
