ResourceManager :: struct {
    // For each lifetime
    MAX_BUFFERS       :: 64;
    MAX_TEXTURES      :: 64;
    MAX_TEXTURE_VIEWS :: 32 * MAX_TEXTURES;
    MAX_SAMPLERS      :: 64;

    MAX_RESOURCE_NAME_LENGTH      :: 512;
    MAX_RESOURCE_FULL_NAME_LENGTH :: 2 * MAX_RESOURCE_NAME_LENGTH;

    POOLS_COUNT :: #run Basic.enum_highest_value(Pool) + 1;

    Lifetime :: enum u8 {
        PERSISTENT;
        PER_SCENE;
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

    destroyPlatformResourceManager : (device : *Device, manager : *ResourceManager);
    commitPlatformResourceMemory   : (device : *Device, manager : *ResourceManager, lifetime : Lifetime);
    resetPlatformResourceMemory    : (device : *Device, manager : *ResourceManager, lifetime : Lifetime);

    pushPlatformBuffer   : (device : *Device, manager : *ResourceManager, lifetime : Lifetime, pool : Pool) -> *Buffer #must;
    createPlatformBuffer : (device : *Device, manager : *ResourceManager, buffer : *Buffer, lifetime : Lifetime, pool : Pool, name : string);

    pushPlatformTexture   : (device : *Device, manager : *ResourceManager, lifetime : Lifetime) -> *Texture #must;
    createPlatformTexture : (device : *Device, manager : *ResourceManager, texture : *Texture, lifetime : Lifetime, name : string);

    pushPlatformTextureView   : (device : *Device, manager : *ResourceManager, lifetime : Lifetime) -> *TextureView #must;
    createPlatformTextureView : (device : *Device, manager : *ResourceManager, view : *TextureView, lifetime : Lifetime, name : string);

    pushPlatformSampler   : (device : *Device, manager : *ResourceManager, lifetime : Lifetime) -> *Sampler #must;
    createPlatformSampler : (device : *Device, manager : *ResourceManager, sampler : *Sampler, state : *SamplerState, lifetime : Lifetime, name : string);
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

commitResourceMemory :: inline (device : *Device, manager : *ResourceManager, lifetime : ResourceManager.Lifetime) {
    manager.commitPlatformResourceMemory(device, manager, lifetime);
}

resetResourceMemory :: inline (device : *Device, manager : *ResourceManager, lifetime : ResourceManager.Lifetime) {
    manager.resetPlatformResourceMemory(device, manager, lifetime);
}

#load "buffer.jai";
#load "texture.jai";
#load "texture_view.jai";
#load "sampler.jai";

#scope_file

#load "vulkan/resource_manager.jai";
