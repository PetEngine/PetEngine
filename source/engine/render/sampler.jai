Sampler :: struct {
    name : string;
}

createSampler :: (device : *Device, manager : *ResourceManager, lifetime : ResourceManager.Lifetime, name : string) -> *Sampler {
    sampler := manager.pushPlatformSampler(device, manager, lifetime);

    manager.createPlatformSampler(device, manager, sampler, lifetime, name);

    return sampler;
}