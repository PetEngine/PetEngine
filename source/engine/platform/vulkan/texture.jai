VulkanTextureManager :: struct {
    #as using public_data : TextureManager;
}

VulkanTexture :: struct {
    #as using public_data : Texture;

    image          : VkImage;
    current_layout : VkImageLayout = .VK_IMAGE_LAYOUT_UNDEFINED;
    current_owner  : QueueType;
}

// @Speed: Figure out something more optimal with access masks and pipeline stages.
vulkanTextureBarrier :: (
    device         : *VulkanDevice,
    command_buffer : VkCommandBuffer,
    texture        : *VulkanTexture,
    new_layout     : VkImageLayout,
    new_owner      : QueueType
) {
    if texture.current_layout == new_layout && texture.current_owner == new_owner {
        return;
    }

    image_barrier := VkImageMemoryBarrier.{
        sType               = .VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
        pNext               = null,
        srcAccessMask       = VkAccessFlags.VK_ACCESS_MEMORY_READ_BIT | .VK_ACCESS_MEMORY_WRITE_BIT,
        dstAccessMask       = VkAccessFlags.VK_ACCESS_MEMORY_READ_BIT | .VK_ACCESS_MEMORY_WRITE_BIT,
        oldLayout           = texture.current_layout,
        newLayout           = new_layout,
        srcQueueFamilyIndex = device.queues[texture.current_owner].family_index,
        dstQueueFamilyIndex = device.queues[new_owner].family_index,
        image               = texture.image,
        subresourceRange    = .{
            aspectMask     = .VK_IMAGE_ASPECT_COLOR_BIT,
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
    texture.current_owner  = new_owner;
}

// @TODO: #VulkanTexture. MIPs, layers, clear_value should not be VkClearColorValue.
clearVulkanTexture :: (device : *VulkanDevice, command_buffer : VkCommandBuffer, texture : *VulkanTexture, clear_value : Texture.ClearValue) {
    if texture.current_layout != .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL {
        vulkanTextureBarrier(device, command_buffer, texture, .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, .GRAPHICS);
    }

    RANGE :: VkImageSubresourceRange.{
        aspectMask     = .VK_IMAGE_ASPECT_COLOR_BIT,
        baseMipLevel   = 0,
        levelCount     = 1,
        baseArrayLayer = 0,
        layerCount     = 1
    };

    vk_clear_value := VkClearColorValue.{
        float32_ = clear_value.f32_
    };

    vkCmdClearColorImage(command_buffer, texture.image, texture.current_layout, *vk_clear_value, 1, *RANGE);
}
