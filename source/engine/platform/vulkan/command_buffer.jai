pushVulkanCommandBuffer :: (device : *VulkanDevice, queue_type : QueueType, swapchain_buffer_index : u32) -> *VkCommandBuffer #must {
    command_buffers_used_index := swapchain_buffer_index * VulkanDevice.queues.count
                                + cast(u32) queue_type;

    command_buffers_used_ptr := *device.command_buffers_used[command_buffers_used_index];
    defer <<command_buffers_used_ptr += 1;

    command_buffers_used := <<command_buffers_used_ptr;
    assert(command_buffers_used < Device.MAX_COMMAND_BUFFERS_OF_EACH_TYPE_PER_FRAME, "Command buffers overflow");

    command_buffer_index := swapchain_buffer_index * VulkanDevice.queues.count * Device.MAX_COMMAND_BUFFERS_OF_EACH_TYPE_PER_FRAME
                          + cast(u32) queue_type * Device.MAX_COMMAND_BUFFERS_OF_EACH_TYPE_PER_FRAME
                          + command_buffers_used;

    return device.command_buffers[command_buffer_index];
}
