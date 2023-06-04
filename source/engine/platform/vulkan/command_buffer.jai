pushVulkanCommandBuffer :: (device : *VulkanDevice, swapchain_buffer_index : u32, queue_type : QueueType) -> *VkCommandBuffer #must {
    frame_data := *device.frame_data[swapchain_buffer_index];

    command_buffers_used := *frame_data.command_buffers_used[queue_type];
    assert(<<command_buffers_used < Device.MAX_COMMAND_BUFFERS, "Command buffers overflow");

    command_buffer := frame_data.command_buffers[cast(s32) queue_type * Device.MAX_COMMAND_BUFFERS + <<command_buffers_used];

    <<command_buffers_used += 1;

    return command_buffer;
}

// @Speed: Figure out something more optimal with access masks and pipeline stages.
vulkanTextureLayoutBarrier :: (command_buffer : VkCommandBuffer, texture : *VulkanTexture, new_layout : VkImageLayout) #no_context {
    if texture.current_layout == new_layout {
        return;
    }

    image_barrier := VkImageMemoryBarrier.{
        sType               = .VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
        pNext               = null,
        srcAccessMask       = VkAccessFlags.VK_ACCESS_MEMORY_READ_BIT | .VK_ACCESS_MEMORY_WRITE_BIT,
        dstAccessMask       = VkAccessFlags.VK_ACCESS_MEMORY_READ_BIT | .VK_ACCESS_MEMORY_WRITE_BIT,
        oldLayout           = texture.current_layout,
        newLayout           = new_layout,
        srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
        dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
        image               = texture.image,
        subresourceRange    = .{
            aspectMask     = getVulkanImageAspectFlags(texture),
            baseMipLevel   = 0,
            levelCount     = 1,
            baseArrayLayer = 0,
            layerCount     = 1
        },
    };

    vkCmdPipelineBarrier(command_buffer,
                         .VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
                         .VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
                         0,
                         0, null,
                         0, null,
                         1, *image_barrier);

    texture.current_layout = new_layout;
}

// @TODO: #VulkanTexture. MIPs, layers, clear_value should not be VkClearColorValue.
clearVulkanTexture :: (command_buffer : VkCommandBuffer, texture : *VulkanTexture, clear_value : Texture.ClearValue) {
    if texture.current_layout != .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL {
        vulkanTextureLayoutBarrier(command_buffer, texture, .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL);
    }

    if #complete texture.format == {
        case .UNKNOWN;
            // Just do nothing

        case .RGB8_UNORM;    #through;
        case .RGB8_SNORM;    #through;
        case .BGR8_UNORM;    #through;
        case .BGR8_SNORM;    #through;
        case .RGBA8_UNORM;   #through;
        case .BGRA8_UNORM;   #through;
        case .RGB10A2_UNORM; #through;
        case .BC7_UNORM;
            range :: VkImageSubresourceRange.{
                aspectMask     = .VK_IMAGE_ASPECT_COLOR_BIT,
                baseMipLevel   = 0,
                levelCount     = 1,
                baseArrayLayer = 0,
                layerCount     = 1
            };

            vk_clear_value := VkClearColorValue.{
                float32_ = clear_value.color_f32
            };

            vkCmdClearColorImage(command_buffer, texture.image, texture.current_layout, *vk_clear_value, 1, *range);

        case .D32;
            range :: VkImageSubresourceRange.{
                aspectMask     = .VK_IMAGE_ASPECT_DEPTH_BIT,
                baseMipLevel   = 0,
                levelCount     = 1,
                baseArrayLayer = 0,
                layerCount     = 1
            };

            vk_clear_value := VkClearDepthStencilValue.{
                depth = clear_value.depth
            };

            vkCmdClearDepthStencilImage(command_buffer, texture.image, texture.current_layout, *vk_clear_value, 1, *range);

        case .S8;
            range :: VkImageSubresourceRange.{
                aspectMask     = .VK_IMAGE_ASPECT_STENCIL_BIT,
                baseMipLevel   = 0,
                levelCount     = 1,
                baseArrayLayer = 0,
                layerCount     = 1
            };

            vk_clear_value := VkClearDepthStencilValue.{
                stencil = clear_value.stencil
            };

            vkCmdClearDepthStencilImage(command_buffer, texture.image, texture.current_layout, *vk_clear_value, 1, *range);
    }

}
