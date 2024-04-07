pushVulkanCommandBuffer :: (device : *VulkanDevice, frame_index : u32, queue_type : QueueType) -> VkCommandBuffer #must {
    frame_data := *device.frame_data[frame_index];

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
        srcAccessMask       = .VK_ACCESS_MEMORY_READ_BIT | .VK_ACCESS_MEMORY_WRITE_BIT,
        dstAccessMask       = .VK_ACCESS_MEMORY_READ_BIT | .VK_ACCESS_MEMORY_WRITE_BIT,
        oldLayout           = texture.current_layout,
        newLayout           = new_layout,
        srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
        dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
        image               = texture.image,
        subresourceRange    = .{
            aspectMask     = getVulkanImageAspectFlags(texture.format),
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
clearVulkanTexture :: (command_buffer : VkCommandBuffer, texture : *VulkanTexture) {
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
            float32_ = texture.clear_value.color_f32.e
        };

        vkCmdClearColorImage(command_buffer, texture.image, texture.current_layout, *vk_clear_value, 1, *range);
    } else if format_flags & (.DEPTH | .STENCIL) {
        if format_flags & .DEPTH   then range.aspectMask |= .VK_IMAGE_ASPECT_DEPTH_BIT;
        if format_flags & .STENCIL then range.aspectMask |= .VK_IMAGE_ASPECT_STENCIL_BIT;

        vk_clear_value := VkClearDepthStencilValue.{
            depth   = texture.clear_value.depth,
            stencil = texture.clear_value.stencil
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

setVulkanShader :: (
    command_buffer : *CommandBuffer,
    shader_manager : *VulkanShaderManager,
    shader         : *VulkanShader,
    frame_index    : u8
) #no_context {
    if !shader.pipeline return;

    if #complete shader.kind == {
        case .UNKNOWN;
            // @TODO: Print some meaningful message why it's illegal
        case .GRAPHICS; #through;
        case .MESH;
            vkCmdBindPipeline(command_buffer.handles[frame_index], .VK_PIPELINE_BIND_POINT_GRAPHICS, shader.pipeline);
        case .COMPUTE;
            vkCmdBindPipeline(command_buffer.handles[frame_index], .VK_PIPELINE_BIND_POINT_COMPUTE, shader.pipeline);
        case .RAY_TRACING;
            vkCmdBindPipeline(command_buffer.handles[frame_index], .VK_PIPELINE_BIND_POINT_RAY_TRACING_KHR, shader.pipeline);
    }

    bindings := *shader_manager.per_frame_bindings[frame_index];
    lock(*bindings.mutex);

    old_offset := cast(s64) bindings.descriptor_buffer_offset;
    for shader.descriptor_set_layout_infos {
        command_buffer.descriptor_buffer_set_offsets[it_index] = cast(s64) bindings.descriptor_buffer_offset;
        bindings.descriptor_buffer_offset += it.size;
    }
    new_offset := cast(s64) bindings.descriptor_buffer_offset;

    unlock(*bindings.mutex);

    // Zero out old descriptors
    memset(bindings.descriptor_buffer.mapped_memory + old_offset, 0, new_offset);
}

// @TODO: #MSAA.
//     - Mip selection
//     - #Limits. maxColorAttachments, maxFramebufferWidth, maxFramebufferHeight
beginVulkanRendering :: (command_buffer : VkCommandBuffer, color_targets : [] ColorTargetDesc, depth_target : *DepthTargetDesc) {
    barriers    := pushToArena(*context.pet.per_frame_arena, VkImageMemoryBarrier, color_targets.count + cast,no_check(s64) (depth_target != null));
    barriers_it := barriers;

    color_attachments    := pushToArena(*context.pet.per_frame_arena, VkRenderingAttachmentInfo, color_targets.count);
    color_attachments_it := color_attachments;

    for color_targets {
        texture := cast(*VulkanTexture) it.texture;

        if texture.current_layout != .VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL {
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

        color_attachments_it.imageView                 = texture.view;
        color_attachments_it.imageLayout               = texture.current_layout;
        color_attachments_it.resolveMode               = .VK_RESOLVE_MODE_NONE;
        color_attachments_it.resolveImageView          = VK_NULL_HANDLE;
        color_attachments_it.resolveImageLayout        = .VK_IMAGE_LAYOUT_UNDEFINED;
        color_attachments_it.loadOp                    = loadActionToVulkanLoadOp(it.load_action);
        color_attachments_it.storeOp                   = storeActionToVulkanStoreOp(it.store_action);
        color_attachments_it.clearValue.color.float32_ = texture.clear_value.color_f32.e;

        color_attachments_it += 1;
    }

    rendering_extent : VkExtent2D = ---;
    if color_targets.count > 0 {
        rendering_extent.width  = color_targets[0].texture.width;
        rendering_extent.height = color_targets[0].texture.height;
    } else {
        rendering_extent.width  = depth_target.texture.width;
        rendering_extent.height = depth_target.texture.height;
    }

    rendering_info := VkRenderingInfo.{
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

        new_layout : VkImageLayout      = ---;
        aspectMask : VkImageAspectFlags = ---;

        if format_flags & (.DEPTH | .STENCIL) == (.DEPTH | .STENCIL) {
            new_layout = ifx  texture.usage & .READ_ONLY
                         then .VK_IMAGE_LAYOUT_DEPTH_STENCIL_READ_ONLY_OPTIMAL
                         else .VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;

            aspectMask = .VK_IMAGE_ASPECT_DEPTH_BIT | .VK_IMAGE_ASPECT_STENCIL_BIT;
        } else if format_flags & .DEPTH {
            new_layout = ifx  texture.usage & .READ_ONLY
                         then .VK_IMAGE_LAYOUT_DEPTH_READ_ONLY_OPTIMAL
                         else .VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL;

            aspectMask = .VK_IMAGE_ASPECT_DEPTH_BIT;
        } else {
            assert(format_flags & .STENCIL);

            new_layout = ifx  texture.usage & .READ_ONLY
                         then .VK_IMAGE_LAYOUT_STENCIL_READ_ONLY_OPTIMAL
                         else .VK_IMAGE_LAYOUT_STENCIL_ATTACHMENT_OPTIMAL;

            aspectMask = .VK_IMAGE_ASPECT_STENCIL_BIT;
        }

        {
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

        if format_flags & .DEPTH {
            depth_attachment.imageView                     = texture.view;
            depth_attachment.imageLayout                   = texture.current_layout;
            depth_attachment.resolveMode                   = .VK_RESOLVE_MODE_NONE;
            depth_attachment.resolveImageView              = VK_NULL_HANDLE;
            depth_attachment.resolveImageLayout            = .VK_IMAGE_LAYOUT_UNDEFINED;
            depth_attachment.loadOp                        = loadActionToVulkanLoadOp(depth_target.depth_load_action);
            depth_attachment.storeOp                       = storeActionToVulkanStoreOp(depth_target.depth_store_action);
            depth_attachment.clearValue.depthStencil.depth = texture.clear_value.depth;

            rendering_info.pDepthAttachment = *depth_attachment;
        }

        if format_flags & .STENCIL {
            stencil_attachment.imageView                       = texture.view;
            stencil_attachment.imageLayout                     = texture.current_layout;
            stencil_attachment.resolveMode                     = .VK_RESOLVE_MODE_NONE;
            stencil_attachment.resolveImageView                = VK_NULL_HANDLE;
            stencil_attachment.resolveImageLayout              = .VK_IMAGE_LAYOUT_UNDEFINED;
            stencil_attachment.loadOp                          = loadActionToVulkanLoadOp(depth_target.stencil_load_action);
            stencil_attachment.storeOp                         = storeActionToVulkanStoreOp(depth_target.stencil_store_action);
            stencil_attachment.clearValue.depthStencil.stencil = texture.clear_value.stencil;

            rendering_info.pStencilAttachment = *stencil_attachment;
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

endVulkanRendering :: inline (command_buffer : VkCommandBuffer) #no_context {
    vkCmdEndRendering(command_buffer);
}

commitVulkanBindings :: (device : *VulkanDevice, command_buffer : *CommandBuffer, shader : *VulkanShader) #no_context {
    if !shader.pipeline return;

    bind_point : VkPipelineBindPoint;
    if #complete shader.kind == {
        case .UNKNOWN;
            // @TODO: Print some meaningful message why it's illegal
        case .GRAPHICS; #through;
        case .MESH;
            bind_point = .VK_PIPELINE_BIND_POINT_GRAPHICS;

        case .COMPUTE;
            bind_point = .VK_PIPELINE_BIND_POINT_COMPUTE;

        case .RAY_TRACING;
            bind_point = .VK_PIPELINE_BIND_POINT_RAY_TRACING_KHR;
    }

    for shader.descriptor_set_layouts {
        if !it continue;

        buffer_index := cast(u32) it_index;
        offset       := cast(VkDeviceSize) command_buffer.descriptor_buffer_set_offsets[it_index];

        device.loader.extensions.device.required.vkCmdSetDescriptorBufferOffsetsEXT(command_buffer.handles[device.frame_index],
                                                                                    bind_point,
                                                                                    shader.pipeline_layout,
                                                                                    cast(u32) it_index,
                                                                                    1,
                                                                                    *buffer_index,
                                                                                    *offset);
    }
}

drawVulkanPrimitives :: inline (
    command_buffer : VkCommandBuffer,
    shader         : *VulkanShader,
    vertex_count   : u32,
    instance_count : u32,
    first_vertex   : u32,
    first_instance : u32
) #no_context {
    if !shader.pipeline return;

    vkCmdDraw(command_buffer, vertex_count, instance_count, first_vertex, first_instance);
}

setVulkanPushConstants :: (command_buffer : VkCommandBuffer, shader : *VulkanShader, handle : PushConstantsHandle, data : *$T) {
    if !shader.pipeline return;

    if handle.index == PushConstantsHandle.INVALID_INDEX {
        warningMessage("Invalid push consatnts binding for shader \"%\"", shader.name);
        return;
    }

    push_constants := *shader.binding_table.push_constants[handle.index];

    assert(size_of(T) == push_constants.bytes,
           "The size of push constants data (%) should be equal to the size of push constants block in \"%\" shader (%)",
           size_of(T),
           shader.name,
           push_constants.bytes);

    vkCmdPushConstants(command_buffer,
                       shader.pipeline_layout,
                       shaderStageFlagsToVulkanStageFlags(push_constants.stage_flags),
                       push_constants.offset,
                       push_constants.bytes,
                       data);
}

bindVulkanBuffer :: (
    device         : *VulkanDevice,
    command_buffer : *CommandBuffer,
    shader_manager : *VulkanShaderManager,
    shader         : *VulkanShader,
    handle         : BindingHandle,
    buffer         : *VulkanBuffer
) {
    if !shader.pipeline return;

    if handle.set == BindingHandle.INVALID_SET || handle.binding == BindingHandle.INVALID_BINDING {
        warningMessage("Invalid set and/or binding for shader \"%\", buffer \"%\"", shader.name, buffer.name);
        return;
    }

    descriptor_range := shader.binding_table.bindings[handle.set][handle.binding];

    descriptor_info := VkDescriptorGetInfoEXT.{
        type = descriptorTypeToVulkanDescriptorType(descriptor_range.descriptor_type),
    };

    if descriptor_range.descriptor_type == .UNKNOWN {
        warningMessage("There is no any binding in descriptor set %, binding %", handle.set, handle.binding);
        return;
    }

    descriptor_address_info := VkDescriptorAddressInfoEXT.{
        address = cast(VkDeviceAddress) buffer.device_address,
        range   = cast(VkDeviceSize) buffer.size,
        format  = .VK_FORMAT_UNDEFINED
    };

    // All types of buffers have the same descriptor data type, so whatever since data is union
    descriptor_info.data.pUniformBuffer = *descriptor_address_info;

    // @TODO: #RobustAccess.
    descriptor_size : u64;
    if buffer.usage == {
        case .UNIFORM;    descriptor_size = device.descriptor_buffer_properties.uniformBufferDescriptorSize;
        case .READ_ONLY;  #through;
        case .READ_WRITE; descriptor_size = device.descriptor_buffer_properties.storageBufferDescriptorSize;
        case;
            warningMessage("You cannot bind a buffer with % usage", buffer.usage);
    }

    descriptor_memory := shader_manager.per_frame_bindings[device.frame_index].descriptor_buffer.mapped_memory
                       + command_buffer.descriptor_buffer_set_offsets[handle.set]
                       + cast(s64) shader.descriptor_set_layout_infos[handle.set].binding_offsets[handle.binding];

    device.loader.extensions.device.required.vkGetDescriptorEXT(device.device, *descriptor_info, descriptor_size, descriptor_memory);
}

copyVulkanBuffer :: inline (
    command_buffer : VkCommandBuffer,
    dest_buffer    : *VulkanBuffer,
    source_buffer  : *VulkanBuffer,
    dest_offset    : u32,
    source_offset  : u32,
    bytes          : u32
) #no_context {
    region := VkBufferCopy2.{
        srcOffset = source_offset,
        dstOffset = dest_offset,
        size      = bytes
    };

    info := VkCopyBufferInfo2.{
        srcBuffer   = source_buffer.buffer,
        dstBuffer   = dest_buffer.buffer,
        regionCount = 1,
        pRegions    = *region
    };

    vkCmdCopyBuffer2(command_buffer, *info);
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
