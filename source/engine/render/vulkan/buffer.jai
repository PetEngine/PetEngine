// @TODO: #VulkanBuffer.
//    - #Views

VulkanBuffer :: struct {
    #as using public_data : Buffer;

    buffer : VkBuffer;
}

pushVulkanBuffer :: (device_ : *Device, manager_ : *ResourceManager, memory_kind : ResourceManager.MemoryKind) -> *Buffer #must {
    device  := cast(*VulkanDevice)          device_;
    manager := cast(*VulkanResourceManager) manager_;

    memory : *VulkanResourceManager.Memory = ---;
    if #complete memory_kind == {
        case .PERSISTENT;                      memory = *manager.buffer_memory.persistent;
        case .PERSISTENT_RESOLUTION_DEPENDENT; assertMessage("Resolution dependent memory is not supported for buffers");
        case .PER_SCENE;                       memory = *manager.buffer_memory.per_scene;
        case .PER_SCENE_RESOLUTION_DEPENDENT;  assertMessage("Resolution dependent memory is not supported for buffers");
        case .PER_FRAME;                       memory = *manager.buffer_memory.per_frame[device.frame_index];
    }

    return pushBack(*memory.buffers);
}

createVulkanBuffer :: (device_ : *Device, manager_ : *ResourceManager, buffer_ : *Buffer) {
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