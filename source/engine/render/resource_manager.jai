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

    memory_committed : u8;
    #assert size_of(type_of(memory_committed)) * 8 > Basic.enum_highest_value(Lifetime);

    //
    // VTable
    //

    destroyPlatformResourceManager : ();
    commitPlatformResourceMemory   : (lifetime : Lifetime);
    resetPlatformResourceMemory    : (lifetime : Lifetime);

    pushPlatformBuffer   : (lifetime : Lifetime, pool : Pool) -> *Buffer #must;
    createPlatformBuffer : (buffer : *Buffer, pool : Pool, name : string);

    pushPlatformTexture   : (lifetime : Lifetime) -> *Texture #must;
    createPlatformTexture : (texture : *Texture, lifetime : Lifetime, name : string);

    pushPlatformTextureView   : (lifetime : Lifetime) -> *TextureView #must;
    createPlatformTextureView : (view : *TextureView, name : string);

    pushPlatformSampler   : (lifetime : Lifetime) -> *Sampler #must;
    createPlatformSampler : (sampler : *Sampler, state : *SamplerState, name : string);
}

createResourceManager :: inline () {
    assert(!context.pet.render.resource_manager);

    if #complete context.pet.render.device.graphics_api == {
        case .VULKAN;
            createVulkanResourceManager();
    }
}

destroyResourceManager :: inline () {
    context.pet.render.resource_manager.destroyPlatformResourceManager();
}

commitResourceMemory :: inline (lifetime : ResourceManager.Lifetime) {
    context.pet.render.resource_manager.commitPlatformResourceMemory(lifetime);
    context.pet.render.resource_manager.memory_committed |= cast(u8) 1 << lifetime;
}

resetResourceMemory :: inline (lifetime : ResourceManager.Lifetime) {
    context.pet.render.resource_manager.resetPlatformResourceMemory(lifetime);
    context.pet.render.resource_manager.memory_committed &= ~(cast(u8) 1 << lifetime);
}

resourceMemoryCommitted :: inline (lifetime : ResourceManager.Lifetime) -> bool {
    return cast(bool) ((context.pet.render.resource_manager.memory_committed >> lifetime) & 1);
}

#load "buffer.jai";
#load "texture.jai";
#load "texture_view.jai";
#load "sampler.jai";

#scope_file

#load "vulkan/resource_manager.jai";
