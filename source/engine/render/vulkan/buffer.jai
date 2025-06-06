VulkanBuffer :: struct {
    #as using public_data : Buffer;

    buffer : VkBuffer;
}

pushVulkanBuffer :: (lifetime : ResourceManager.Lifetime, pool : ResourceManager.Pool) -> *Buffer {
    manager := cast(*VulkanResourceManager) context.pet.render.resource_manager;

    buffer : *VulkanBuffer;
    if #complete lifetime == {
        case .PERSISTENT; buffer = pushBack(*manager.buffers.persistent[pool].resources);
        case .PER_SCENE;  buffer = pushBack(*manager.buffers.per_scene[pool].resources);
        case .PER_FRAME;  buffer = pushBack(*manager.buffers.per_frame[context.pet.render.device.frame_index][pool].resources);
    }
    return buffer;
}

pushVulkanDescriptorBuffer :: inline () -> *VulkanBuffer {
    manager := cast(*VulkanResourceManager) context.pet.render.resource_manager;

    return pushBack(*manager.descriptor_buffers.persistent.resources);
}

createVulkanBuffer :: (buffer_ : *Buffer, pool : ResourceManager.Pool, name : string) {
    device  := cast(*VulkanDevice)          context.pet.render.device;
    manager := cast(*VulkanResourceManager) context.pet.render.resource_manager;
    buffer  := cast(*VulkanBuffer)          buffer_;

    queue_family_indices : [VulkanBuffer.possible_owners.capacity] u32;
    for buffer.possible_owners {
        queue_family_indices[it_index] = device.queues[it].family_index;
    }

    create_info := VkBufferCreateInfo.{
        size                  = cast(VkDeviceSize) buffer.size,
        usage                 = bufferUsageToVkBufferUsageFlags(buffer.usage),
        queueFamilyIndexCount = cast(u32) buffer.possible_owners.count,
        pQueueFamilyIndices   = queue_family_indices.data,
    };

    if requiresDeviceAddress(buffer) {
        create_info.usage |= .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT;
    }

    if buffer.possible_owners.count > 1 {
        create_info.sharingMode = .VK_SHARING_MODE_CONCURRENT;
    } else {
        create_info.sharingMode = .VK_SHARING_MODE_EXCLUSIVE;
    }

    debugCheckVK(vkCreateBuffer(device.device, *create_info, null, *buffer.buffer));

    if #complete buffer.lifetime == {
        case .PERSISTENT; composeVulkanBufferName(buffer, *manager.buffers.persistent[pool],                    pool, name);
        case .PER_SCENE;  composeVulkanBufferName(buffer, *manager.buffers.per_scene[pool],                     pool, name);
        case .PER_FRAME;  composeVulkanBufferName(buffer, *manager.buffers.per_frame[device.frame_index][pool], pool, name);
    }

    setVulkanObjectName(buffer.buffer, buffer.name);
}

createVulkanDescriptorBuffer :: (buffer : *VulkanBuffer, usage : VkBufferUsageFlags, name : string) {
    device := cast(*VulkanDevice) context.pet.render.device;
    assert(device.descriptor_buffers_supported);

    assert(!resourceMemoryCommitted(.PERSISTENT),
           "You cannot create %1 descriptor buffer after %1 memory is committed",
           ResourceManager.Lifetime.PERSISTENT);

    manager := cast(*VulkanResourceManager) context.pet.render.resource_manager;

    queue_family_indices : [VulkanBuffer.possible_owners.capacity] u32;
    for buffer.possible_owners {
        queue_family_indices[it_index] = device.queues[it].family_index;
    }

    create_info := VkBufferCreateInfo.{
        size                  = cast(VkDeviceSize) buffer.size,
        usage                 = usage | .VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT,
        queueFamilyIndexCount = cast(u32) buffer.possible_owners.count,
        pQueueFamilyIndices   = queue_family_indices.data
    };

    if buffer.possible_owners.count > 1 {
        create_info.sharingMode = .VK_SHARING_MODE_CONCURRENT;
    } else {
        create_info.sharingMode = .VK_SHARING_MODE_EXCLUSIVE;
    }

    debugCheckVK(vkCreateBuffer(device.device, *create_info, null, *buffer.buffer));

    composeVulkanDescriptorBufferName(buffer, *manager.descriptor_buffers.persistent, name);

    setVulkanObjectName(buffer.buffer, buffer.name);
}

requiresDeviceAddress :: inline (buffer : *Buffer) -> bool {
    device := cast(*VulkanDevice) context.pet.render.device;
    return buffer.usage == .READ_ONLY
        || buffer.usage == .READ_WRITE
        || (buffer.usage == .UNIFORM && device.descriptor_buffers_supported);
}

#scope_file

bufferUsageToVkBufferUsageFlags :: inline (usage : Buffer.Usage) -> VkBufferUsageFlags #no_context {
    usage_flags := VkBufferUsageFlags.VK_BUFFER_USAGE_TRANSFER_SRC_BIT | .VK_BUFFER_USAGE_TRANSFER_DST_BIT;

    if #complete usage == {
        case .NONE;       // Do nothing
        case .UNIFORM;    usage_flags |= .VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT;
        case .READ_ONLY;  usage_flags |= .VK_BUFFER_USAGE_STORAGE_BUFFER_BIT;
        case .READ_WRITE; usage_flags |= .VK_BUFFER_USAGE_STORAGE_BUFFER_BIT;
    }

    return usage_flags;
}

// "Buffer/<lifetime>/<pool>/<usage>/<name>"
composeVulkanBufferName :: (
    buffer      : *Buffer,
    memory_pool : *VulkanResourceManager.MemoryPool,
    pool        : ResourceManager.Pool,
    name        : string
) {
    lifetime_name := Reflection.enum_value_to_name(buffer.lifetime);
    assert(lifetime_name);

    pool_name := Reflection.enum_value_to_name(pool);
    assert(pool_name);

    usage_name := Reflection.enum_value_to_name(buffer.usage);
    assert(usage_name);

    full_name_length := "Buffer/".count
                      + lifetime_name.count + "/".count
                      + pool_name.count     + "/".count
                      + usage_name.count    + "/".count
                      + name.count;

    assert(full_name_length <= ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH,
           "Buffer full name length (%) > ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH (%)",
           full_name_length,
           ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH);

    buffer.name.data = pushToArena(*memory_pool.names_subarena, full_name_length);

    appendToString(*buffer.name, full_name_length, "Buffer/", lifetime_name, "/", pool_name, "/", usage_name, "/", name);
    assert(buffer.name.count == full_name_length);
}

// "Descriptor Buffer/<name>"
composeVulkanDescriptorBufferName :: (buffer : *Buffer, memory_pool : *VulkanResourceManager.MemoryPool, name : string) {
    full_name_length := "Descriptor Buffer/".count
                      + name.count;

    assert(full_name_length <= ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH,
           "Buffer full name length (%) > ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH (%)",
           full_name_length,
           ResourceManager.MAX_RESOURCE_FULL_NAME_LENGTH);

    buffer.name.data = pushToArena(*memory_pool.names_subarena, full_name_length);

    appendToString(*buffer.name, full_name_length, "Descriptor Buffer/", name);
    assert(buffer.name.count == full_name_length);
}
