pushVulkanCommandBuffer :: (device : *VulkanDevice, swapchain_buffer_index : u32, queue_type : QueueType) -> *VkCommandBuffer #must {
    frame_data := *device.frame_data[swapchain_buffer_index];

    command_buffers_used := *frame_data.command_buffers_used[queue_type];
    assert(<<command_buffers_used < Device.MAX_COMMAND_BUFFERS, "Command buffers overflow");

    command_buffer := frame_data.command_buffers[cast(s32) queue_type * Device.MAX_COMMAND_BUFFERS + <<command_buffers_used];

    <<command_buffers_used += 1;

    return command_buffer;
}
