pushVulkanCommandBuffer :: (device : *VulkanDevice, swapchain_buffer_index : u32, queue_type : QueueType) -> *VkCommandBuffer #must {
    frame_data := *device.frame_data[swapchain_buffer_index];

    command_buffers_used := *frame_data.command_buffers_used[queue_type];
    assert(command_buffers_used.* < Device.MAX_COMMAND_BUFFERS, "Command buffers overflow");

    command_buffer := frame_data.command_buffers[cast(s32) queue_type * Device.MAX_COMMAND_BUFFERS + command_buffers_used.*];

    command_buffers_used.* += 1;

    return command_buffer;
}

// @Speed: Figure out something more optimal with access masks and pipeline stages.
changeVulkanTextureLayout :: (command_buffer : VkCommandBuffer, texture : *VulkanTexture, new_layout : VkImageLayout) #no_context {
    if texture.current_layout == new_layout {
        return;
    }

    image_barrier := VkImageMemoryBarrier.{
        sType               = .VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
        pNext               = null,
        srcAccessMask       = .VK_ACCESS_MEMORY_READ_BIT | .VK_ACCESS_MEMORY_WRITE_BIT,
        dstAccessMask       = .VK_ACCESS_MEMORY_READ_BIT | .VK_ACCESS_MEMORY_WRITE_BIT,
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

// @TODO: #VulkanTexture. MIPs, layers.
clearVulkanTexture :: (command_buffer : VkCommandBuffer, texture : *VulkanTexture, clear_value : Texture.ClearValue) {
    if texture.current_layout != .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL {
        changeVulkanTextureLayout(command_buffer, texture, .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL);
    }

    range := VkImageSubresourceRange.{
        aspectMask     = .VK_IMAGE_ASPECT_NONE,
        baseMipLevel   = 0,
        levelCount     = VK_REMAINING_MIP_LEVELS,
        baseArrayLayer = 0,
        layerCount     = VK_REMAINING_ARRAY_LAYERS
    };

    format_flags := textureFormatFlags(texture.format);

    if format_flags & .COLOR {
        range.aspectMask |= .VK_IMAGE_ASPECT_COLOR_BIT;

        vk_clear_value := VkClearColorValue.{
            float32_ = clear_value.color_f32
        };

        vkCmdClearColorImage(command_buffer, texture.image, texture.current_layout, *vk_clear_value, 1, *range);
    } else if format_flags & (.DEPTH | .STENCIL) {
        if format_flags & .DEPTH   then range.aspectMask |= .VK_IMAGE_ASPECT_DEPTH_BIT;
        if format_flags & .STENCIL then range.aspectMask |= .VK_IMAGE_ASPECT_STENCIL_BIT;

        vk_clear_value := VkClearDepthStencilValue.{
            depth   = clear_value.depth,
            stencil = clear_value.stencil
        };

        vkCmdClearDepthStencilImage(command_buffer, texture.image, texture.current_layout, *vk_clear_value, 1, *range);
    } else {
        assertMessage("Unsupported texture format for clearing: %", texture.format);
    }
}

setVulkanViewport :: inline (command_buffer : VkCommandBuffer, viewport : *Viewport, render_target_height : u16) #no_context {
    vk_viewport := VkViewport.{
        x        = viewport.x,
        y        = cast(f32) render_target_height - viewport.y,
        width    = viewport.width,
        height   = -viewport.height,
        minDepth = 0.0,
        maxDepth = 1.0,
    };

    vkCmdSetViewport(command_buffer, 0, 1, *vk_viewport);
}

setVulkanScissorRect :: inline (command_buffer : VkCommandBuffer, scissor_rect : *ScissorRect) #no_context {
    vk_scissor_rect := VkRect2D.{
        offset = .{ scissor_rect.x,     scissor_rect.y      },
        extent = .{ scissor_rect.width, scissor_rect.height },
    };

    vkCmdSetScissor(command_buffer, 0, 1, *vk_scissor_rect);
}

// TODO: Compute shaders
setVulkanShader :: inline (command_buffer : VkCommandBuffer, shader : *VulkanShader) #no_context {
    vkCmdBindPipeline(command_buffer, .VK_PIPELINE_BIND_POINT_GRAPHICS, shader.pipeline);
}

// @TODO: #MSAA. Resolve attachments
// @Speed: Load/store actions
// @TODO: Mip selection
beginVulkanRendering :: (command_buffer : VkCommandBuffer, color_targets : [] ColorTargetDesc, depth_target : *DepthTargetDesc) {
    barriers    := pushToArena(*context.pet.per_frame_arena, VkImageMemoryBarrier, color_targets.count + cast,no_check(s64) (depth_target != null));
    barriers_it := barriers;

    color_attachments    := pushToArena(*context.pet.per_frame_arena, VkRenderingAttachmentInfo, color_targets.count);
    color_attachments_it := color_attachments;

    for color_targets {
        texture := cast(*VulkanTexture) it.texture;

        if texture.current_layout != .VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL {
            barriers_it.sType                           = .VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
            barriers_it.pNext                           = null;
            barriers_it.srcAccessMask                   = .VK_ACCESS_MEMORY_READ_BIT | .VK_ACCESS_MEMORY_WRITE_BIT;
            barriers_it.dstAccessMask                   = .VK_ACCESS_MEMORY_READ_BIT | .VK_ACCESS_MEMORY_WRITE_BIT;
            barriers_it.oldLayout                       = texture.current_layout;
            barriers_it.newLayout                       = .VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
            barriers_it.srcQueueFamilyIndex             = VK_QUEUE_FAMILY_IGNORED;
            barriers_it.dstQueueFamilyIndex             = VK_QUEUE_FAMILY_IGNORED;
            barriers_it.image                           = texture.image;
            barriers_it.subresourceRange.aspectMask     = .VK_IMAGE_ASPECT_COLOR_BIT;
            barriers_it.subresourceRange.baseMipLevel   = 0;
            barriers_it.subresourceRange.levelCount     = 1;
            barriers_it.subresourceRange.baseArrayLayer = 0;
            barriers_it.subresourceRange.layerCount     = 1;

            texture.current_layout = .VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

            barriers_it += 1;
        }

        color_attachments_it.sType              = .VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO;
        color_attachments_it.pNext              = null;
        color_attachments_it.imageView          = texture.view;
        color_attachments_it.imageLayout        = texture.current_layout;
        color_attachments_it.resolveMode        = .VK_RESOLVE_MODE_NONE;
        color_attachments_it.resolveImageView   = VK_NULL_HANDLE;
        color_attachments_it.resolveImageLayout = .VK_IMAGE_LAYOUT_UNDEFINED;
        color_attachments_it.loadOp             = loadActionToVulkanLoadOp(it.load_action);
        color_attachments_it.storeOp            = storeActionToVulkanStoreOp(it.store_action);
        color_attachments_it.clearValue         = .{
            color = .{ float32_ = it.clear_value.as_f32 }
        };

        color_attachments_it += 1;
    }

    rendering_extent : VkExtent2D = ---;
    if color_targets.count > 0 {
        rendering_extent = .{ color_targets[0].texture.width, color_targets[0].texture.height };
    } else {
        rendering_extent = .{ depth_target.texture.width, depth_target.texture.height };
    }

    rendering_info := VkRenderingInfo.{
        sType                = .VK_STRUCTURE_TYPE_RENDERING_INFO,
        pNext                = null,
        flags                = 0,
        renderArea           = .{
            offset = .{ 0, 0 },
            extent = rendering_extent
        },
        layerCount           = 1,
        viewMask             = 0,
        colorAttachmentCount = cast(u32) color_targets.count,
        pColorAttachments    = color_attachments,
        pDepthAttachment     = null,
        pStencilAttachment   = null,
    };

    depth_attachment   : VkRenderingAttachmentInfo = ---;
    stencil_attachment : VkRenderingAttachmentInfo = ---;

    if depth_target {
        texture := cast(*VulkanTexture) depth_target.texture;

        format_flags := textureFormatFlags(texture.format);

        if format_flags & .DEPTH {
            depth_attachment.sType              = .VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO;
            depth_attachment.pNext              = null;
            depth_attachment.imageView          = texture.view;
            depth_attachment.imageLayout        = texture.current_layout;
            depth_attachment.resolveMode        = .VK_RESOLVE_MODE_NONE;
            depth_attachment.resolveImageView   = VK_NULL_HANDLE;
            depth_attachment.resolveImageLayout = .VK_IMAGE_LAYOUT_UNDEFINED;
            depth_attachment.loadOp             = loadActionToVulkanLoadOp(depth_target.depth_load_action);
            depth_attachment.storeOp            = storeActionToVulkanStoreOp(depth_target.depth_store_action);
            depth_attachment.clearValue         = .{
                depthStencil = .{ depth = depth_target.depth_clear_value }
            };

            rendering_info.pDepthAttachment = *depth_attachment;
        }

        if format_flags & .STENCIL {
            stencil_attachment.sType              = .VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO;
            stencil_attachment.pNext              = null;
            stencil_attachment.imageView          = texture.view;
            stencil_attachment.imageLayout        = texture.current_layout;
            stencil_attachment.resolveMode        = .VK_RESOLVE_MODE_NONE;
            stencil_attachment.resolveImageView   = VK_NULL_HANDLE;
            stencil_attachment.resolveImageLayout = .VK_IMAGE_LAYOUT_UNDEFINED;
            stencil_attachment.loadOp             = loadActionToVulkanLoadOp(depth_target.stencil_load_action);
            stencil_attachment.storeOp            = storeActionToVulkanStoreOp(depth_target.stencil_store_action);
            stencil_attachment.clearValue         = .{
                depthStencil = .{ stencil = depth_target.stencil_clear_value }
            };

            rendering_info.pStencilAttachment = *stencil_attachment;
        }

        new_layout : VkImageLayout      = ---;
        aspectMask : VkImageAspectFlags = ---;

        if format_flags & (.DEPTH | .STENCIL) == (.DEPTH | .STENCIL) {
            new_layout = ifx  texture.flags & .READ_ONLY
                         then .VK_IMAGE_LAYOUT_DEPTH_STENCIL_READ_ONLY_OPTIMAL
                         else .VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;

            aspectMask = .VK_IMAGE_ASPECT_DEPTH_BIT | .VK_IMAGE_ASPECT_STENCIL_BIT;
        } else if format_flags & .DEPTH {
            new_layout = ifx  texture.flags & .READ_ONLY
                         then .VK_IMAGE_LAYOUT_DEPTH_READ_ONLY_OPTIMAL
                         else .VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL;

            aspectMask = .VK_IMAGE_ASPECT_DEPTH_BIT;
        } else {
            assert(format_flags & .STENCIL);

            new_layout = ifx  texture.flags & .READ_ONLY
                         then .VK_IMAGE_LAYOUT_STENCIL_READ_ONLY_OPTIMAL
                         else .VK_IMAGE_LAYOUT_STENCIL_ATTACHMENT_OPTIMAL;

            aspectMask = .VK_IMAGE_ASPECT_STENCIL_BIT;
        }

        {
            barriers_it.sType                           = .VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
            barriers_it.pNext                           = null;
            barriers_it.srcAccessMask                   = .VK_ACCESS_MEMORY_READ_BIT | .VK_ACCESS_MEMORY_WRITE_BIT;
            barriers_it.dstAccessMask                   = .VK_ACCESS_MEMORY_READ_BIT | .VK_ACCESS_MEMORY_WRITE_BIT;
            barriers_it.oldLayout                       = texture.current_layout;
            barriers_it.newLayout                       = new_layout;
            barriers_it.srcQueueFamilyIndex             = VK_QUEUE_FAMILY_IGNORED;
            barriers_it.dstQueueFamilyIndex             = VK_QUEUE_FAMILY_IGNORED;
            barriers_it.image                           = texture.image;
            barriers_it.subresourceRange.aspectMask     = aspectMask;
            barriers_it.subresourceRange.baseMipLevel   = 0;
            barriers_it.subresourceRange.levelCount     = 1;
            barriers_it.subresourceRange.baseArrayLayer = 0;
            barriers_it.subresourceRange.layerCount     = 1;

            texture.current_layout = new_layout;

            barriers_it += 1;
        }
    }

    barriers_count := cast(u32) (barriers_it - barriers);
    if barriers_count {
        vkCmdPipelineBarrier(command_buffer,
                             .VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
                             .VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
                             0,
                             0, null,
                             0, null,
                             barriers_count, barriers);
    }

    vkCmdBeginRendering(command_buffer, *rendering_info);
}

endVulkanRendering :: (command_buffer : VkCommandBuffer) #no_context {
    vkCmdEndRendering(command_buffer);
}

drawVulkanPrimitives :: inline (
    command_buffer : VkCommandBuffer,
    vertex_count   : u32,
    instance_count : u32,
    first_vertex   : u32,
    first_instance : u32
) #no_context {
    vkCmdDraw(command_buffer, vertex_count, instance_count, first_vertex, first_instance);
}

#scope_file

loadActionToVulkanLoadOp :: (action : TargetLoadAction) -> VkAttachmentLoadOp #no_context {
    if #complete action == {
        case .NONE;  return .VK_ATTACHMENT_LOAD_OP_DONT_CARE; // @TODO: VK_ATTACHMENT_LOAD_OP_NONE_EXT
        case .CLEAR; return .VK_ATTACHMENT_LOAD_OP_CLEAR;
        case .LOAD;  return .VK_ATTACHMENT_LOAD_OP_LOAD;
    }
}

storeActionToVulkanStoreOp :: (action : TargetStoreAction) -> VkAttachmentStoreOp #no_context {
    if #complete action == {
        case .NONE;  return .VK_ATTACHMENT_STORE_OP_DONT_CARE; // @TODO: VK_ATTACHMENT_STORE_OP_NONE
        case .STORE; return .VK_ATTACHMENT_STORE_OP_STORE;
    }
}
