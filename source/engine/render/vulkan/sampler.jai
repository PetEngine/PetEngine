VulkanSampler :: struct {
    #as using public_data : Sampler;

    sampler : VkSampler;
}

pushVulkanSampler :: (device_ : *Device, manager_ : *ResourceManager, lifetime : ResourceManager.Lifetime) -> *Sampler #must {
    device  := cast(*VulkanDevice)          device_;
    manager := cast(*VulkanResourceManager) manager_;

    sampler : *VulkanSampler;
    if #complete lifetime == {
        case .PERSISTENT; sampler = pushBack(*manager.samplers.persistent.resources);
        case .PER_SCENE;  sampler = pushBack(*manager.samplers.per_scene.resources);
        case .PER_FRAME;  sampler = pushBack(*manager.samplers.per_frame[device.frame_index].resources);
    }
    return sampler;
}

createVulkanSampler :: (
    device_   : *Device,
    manager_  : *ResourceManager,
    sampler_  : *Sampler,
    lifetime  : ResourceManager.Lifetime,
    name      : string
) {
    device  := cast(*VulkanDevice) device_;
    manager := cast(*VulkanResourceManager) manager_;
    sampler := cast(*VulkanSampler) sampler_;

    // @Continue: #Samplers.
    create_info : VkSamplerCreateInfo;

    debugCheckVK(vkCreateSampler(device.device, *create_info, null, *sampler.sampler));

    if #complete lifetime == {
        case .PERSISTENT; composeVulkanSamplerName(sampler, *manager.samplers.persistent,                    lifetime, name);
        case .PER_SCENE;  composeVulkanSamplerName(sampler, *manager.samplers.per_scene,                     lifetime, name);
        case .PER_FRAME;  composeVulkanSamplerName(sampler, *manager.samplers.per_frame[device.frame_index], lifetime, name);
    }

    setVulkanObjectName(device, sampler.sampler, sampler.name);
}

#scope_file

// "Sampler/<lifetime>/<name>"
composeVulkanSamplerName :: (
    sampler     : *VulkanSampler,
    memory_pool : *VulkanResourceManager.MemorylessPool,
    lifetime    : ResourceManager.Lifetime,
    name        : string
) {
    lifetime_name := Reflection.enum_value_to_name(lifetime);
    assert(lifetime_name);

    full_name_length := "Sampler/".count
                      + lifetime_name.count + "/".count
                      + name.count;

    assert(full_name_length <= ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH,
           "Sampler full name length (%) > ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH (%)",
           full_name_length,
           ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH);

    sampler.name.data = pushToArena(*memory_pool.names_subarena, full_name_length);

    appendToString(*sampler.name, full_name_length, "Sampler/", lifetime_name, "/", name);
    assert(sampler.name.count == full_name_length);
}
