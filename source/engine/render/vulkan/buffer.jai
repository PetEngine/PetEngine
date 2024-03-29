// @TODO: #VulkanBuffer.
//    - #Views

VulkanBuffer :: struct {
    #as using public_data : Buffer;

    buffer : VkBuffer;
}

pushVulkanBuffer :: (
    device_  : *Device,
    manager_ : *ResourceManager,
    lifetime : ResourceManager.Lifetime,
    pool     : ResourceManager.Pool
) -> *Buffer #must {
    device  := cast(*VulkanDevice)          device_;
    manager := cast(*VulkanResourceManager) manager_;

    buffer : *VulkanBuffer;
    if #complete lifetime == {
        case .PERSISTENT; buffer = pushBack(*manager.buffers.persistent[pool].resources);
        case .PER_SCENE;  buffer = pushBack(*manager.buffers.per_scene[pool].resources);
        case .PER_FRAME;  buffer = pushBack(*manager.buffers.per_frame[device.frame_index][pool].resources);
    }

    assert(buffer);
    return buffer;
}

createVulkanBuffer :: (
    device_  : *Device,
    manager_ : *ResourceManager,
    buffer_  : *Buffer,
    lifetime : ResourceManager.Lifetime,
    pool     : ResourceManager.Pool,
    name     : string
) {
    device  := cast(*VulkanDevice)          device_;
    manager := cast(*VulkanResourceManager) manager_;
    buffer  := cast(*VulkanBuffer)          buffer_;

    queue_family_indices : [VulkanBuffer.possible_owners.capacity] u32;
    for buffer.possible_owners {
        queue_family_indices[it_index] = device.queues[it].family_index;
    }

    create_info := VkBufferCreateInfo.{
        size                  = buffer.bytes,
        usage                 = bufferUsageToVkBufferUsageFlags(buffer.usage),
        queueFamilyIndexCount = cast(u32) buffer.possible_owners.count,
        pQueueFamilyIndices   = queue_family_indices.data,
    };

    if buffer.possible_owners.count > 1 {
        create_info.sharingMode = .VK_SHARING_MODE_CONCURRENT;
    } else {
        create_info.sharingMode = .VK_SHARING_MODE_EXCLUSIVE;
    }

    // @TODO: #VkAllocationCallbacks
    debugCheckVK(vkCreateBuffer(device.device, *create_info, null, *buffer.buffer));

    if #complete lifetime == {
        case .PERSISTENT; composeVulkanBufferName(buffer, *manager.buffers.persistent[pool],                    lifetime, pool, name);
        case .PER_SCENE;  composeVulkanBufferName(buffer, *manager.buffers.per_scene[pool],                     lifetime, pool, name);
        case .PER_FRAME;  composeVulkanBufferName(buffer, *manager.buffers.per_frame[device.frame_index][pool], lifetime, pool, name);
    }

    setVulkanObjectName(device, buffer.buffer, buffer.name);
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
    lifetime    : ResourceManager.Lifetime,
    pool        : ResourceManager.Pool,
    name        : string
) {
    lifetime_name := Reflection.enum_value_to_name(lifetime);
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
    assert(buffer.name.count == full_name_length, "buffer.name.count (%) != full_name_length (%)", buffer.name.count, full_name_length);
}
