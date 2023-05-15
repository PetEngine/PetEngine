CommandBuffer :: struct {
    handles : [] *void;
}

// @TODO: Per-frame command buffers
createCommandBuffer :: (device : *Device) -> CommandBuffer #must {
    command_buffer : CommandBuffer;

    QUEUES_COUNT :: #run Basic.enum_highest_value(QueueType) + 1;

    command_buffer.handles.count = device.swapchain_buffers_count * QUEUES_COUNT;
    command_buffer.handles.data  = pushToArena(*context.pet_engine_state.persistent_arena, *void, command_buffer.handles.count);

    handles_it := command_buffer.handles.data;

    if #complete device.graphics_api == {
        case .VULKAN;
            for swapchain_buffer_index : 0 .. device.swapchain_buffers_count - 1 {
                for queue_type : 0 .. QUEUES_COUNT - 1 {
                    <<handles_it = pushVulkanCommandBuffer(cast(*VulkanDevice) device, swapchain_buffer_index, cast(QueueType) queue_type);
                    handles_it += 1;
                }
            }
    }

    assert(handles_it == command_buffer.handles.data + command_buffer.handles.count);

    return command_buffer;
}

destroyCommandBuffer :: (device : *Device, command_buffer : *CommandBuffer) {
}

#scope_file

#load "../platform/vulkan/command_buffer.jai";
