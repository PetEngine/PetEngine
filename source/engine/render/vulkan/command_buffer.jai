pushVulkanCommandBuffer :: (frame_index : u32, queue_type : QueueType) -> VkCommandBuffer #must {
    device := cast(*VulkanDevice) context.pet.render.device;

    frame_data := *device.frame_data[frame_index];

    command_buffers_used := *frame_data.command_buffers_used[queue_type];
    assert(command_buffers_used.* < Device.MAX_COMMAND_BUFFERS, "Command buffers overflow");

    command_buffer := frame_data.command_buffers[cast(s32) queue_type * Device.MAX_COMMAND_BUFFERS + command_buffers_used.*];

    command_buffers_used.* += 1;

    return command_buffer;
}

rebindVulkanDescriptorBuffers :: (command_buffer : VkCommandBuffer) {
    device          := cast(*VulkanDevice)         context.pet.render.device;
    binding_manager := cast(*VulkanBindingManager) context.pet.render.binding_manager;

    if device.descriptor_buffers_supported {
        binding_infos : [BindingManager.MAX_DESCRIPTOR_SETS] VkDescriptorBufferBindingInfoEXT;
        for * binding_infos { it.usage = binding_manager.descriptor_set_layouts[it_index].usage; }

        binding_infos[DescriptorSet.PER_FRAME].address  = cast(VkDeviceAddress) binding_manager.per_frame_bindings[device.frame_index].descriptor_buffer.device_address;
        binding_infos[DescriptorSet.PER_SCENE].address  = cast(VkDeviceAddress) binding_manager.per_scene_bindings.descriptor_buffer.device_address;
        binding_infos[DescriptorSet.PERSISTENT].address = cast(VkDeviceAddress) binding_manager.persistent_bindings.descriptor_buffer.device_address;

        device.loader.extensions.device.optional.vkCmdBindDescriptorBuffersEXT(command_buffer, binding_infos.count, binding_infos.data);
    }
}

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
    vkCmdSetViewport(command_buffer, 0, 1, *(VkViewport.{
        x        = viewport.x,
        y        = cast(f32) render_target_height - viewport.y,
        width    = viewport.width,
        height   = -viewport.height,
        minDepth = viewport.min_depth,
        maxDepth = viewport.max_depth,
    }));
}

setVulkanScissorRect :: inline (command_buffer : VkCommandBuffer, scissor_rect : *ScissorRect) #no_context {
    vkCmdSetScissor(command_buffer, 0, 1, *(VkRect2D.{
        offset = .{ scissor_rect.x,     scissor_rect.y      },
        extent = .{ scissor_rect.width, scissor_rect.height },
    }));
}

setVulkanShader :: (command_buffer : *CommandBuffer, bind_point : ShaderBindPoint) {
    #assert command_buffer.usage == .GRAPHICS || command_buffer.usage == .ASYNC_COMPUTE
            "Only graphics and compute command buffers can set shaders";

    shader := cast(*VulkanShader) command_buffer.shaders[bind_point];
    if !shader.pipeline return;

    device := cast(*VulkanDevice) context.pet.render.device;

    vk_command_buffer : VkCommandBuffer = command_buffer.handles[device.frame_index];
    vk_bind_point     := shaderBindPointToVulkanPipelineBindPoint(bind_point);

    // Bind pipeline

    vkCmdBindPipeline(vk_command_buffer, vk_bind_point, shader.pipeline);

    // Update descriptor buffer offsets
    if device.descriptor_buffers_supported {
        buffer_indices : [BindingManager.MAX_DESCRIPTOR_SETS] u32 = ---;
        for type_info(DescriptorSet).values { buffer_indices[it_index] = cast(u32) it; }

        buffer_offsets : [BindingManager.MAX_DESCRIPTOR_SETS] VkDeviceSize;

        device.loader.extensions.device.optional.vkCmdSetDescriptorBufferOffsetsEXT(vk_command_buffer,
                                                                                    vk_bind_point,
                                                                                    shader.pipeline_layout,
                                                                                    0,
                                                                                    BindingManager.MAX_DESCRIPTOR_SETS,
                                                                                    buffer_indices.data,
                                                                                    buffer_offsets.data);
    } else {
        binding_manager := cast(*VulkanBindingManager) context.pet.render.binding_manager;

        descriptor_sets : [BindingManager.MAX_DESCRIPTOR_SETS] VkDescriptorSet = ---;
        descriptor_sets[DescriptorSet.PER_FRAME]  = binding_manager.per_frame_bindings[device.frame_index].descriptor_set;
        descriptor_sets[DescriptorSet.PER_SCENE]  = binding_manager.per_scene_bindings.descriptor_set;
        descriptor_sets[DescriptorSet.PERSISTENT] = binding_manager.persistent_bindings.descriptor_set;

        vkCmdBindDescriptorSets(vk_command_buffer,
                                vk_bind_point,
                                shader.pipeline_layout,
                                0,
                                descriptor_sets.count,
                                descriptor_sets.data,
                                0,
                                null);
    }
}

beginVulkanRendering :: (command_buffer : VkCommandBuffer, color_targets : [] ColorTargetDesc, depth_target : *DepthTargetDesc) {
    barriers    := pushToArena(*context.pet.arenas.per_frame, VkImageMemoryBarrier, color_targets.count + cast,no_check(s64) (depth_target != null));
    barriers_it := barriers;

    color_attachments    := pushToArena(*context.pet.arenas.per_frame, VkRenderingAttachmentInfo, color_targets.count);
    color_attachments_it := color_attachments;

    for color_targets {
        view    := cast(*VulkanTextureView) it.view;
        texture := cast(*VulkanTexture) view.texture;

        if texture.current_layout != .VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL {
            barriers_it.srcAccessMask                   = .VK_ACCESS_MEMORY_READ_BIT | .VK_ACCESS_MEMORY_WRITE_BIT;
            barriers_it.dstAccessMask                   = .VK_ACCESS_MEMORY_READ_BIT | .VK_ACCESS_MEMORY_WRITE_BIT;
            barriers_it.oldLayout                       = texture.current_layout;
            barriers_it.newLayout                       = .VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
            barriers_it.srcQueueFamilyIndex             = VK_QUEUE_FAMILY_IGNORED;
            barriers_it.dstQueueFamilyIndex             = VK_QUEUE_FAMILY_IGNORED;
            barriers_it.image                           = texture.image;
            barriers_it.subresourceRange.aspectMask     = .VK_IMAGE_ASPECT_COLOR_BIT;
            barriers_it.subresourceRange.baseMipLevel   = view.first_mip;
            barriers_it.subresourceRange.levelCount     = view.mips_count;
            barriers_it.subresourceRange.baseArrayLayer = view.first_layer;
            barriers_it.subresourceRange.layerCount     = max(view.layers_count, 1);

            texture.current_layout = .VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

            barriers_it += 1;
        }

        color_attachments_it.imageView                 = view.view;
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
        rendering_extent.width  = color_targets[0].view.texture.width;
        rendering_extent.height = color_targets[0].view.texture.height;
    } else {
        rendering_extent.width  = depth_target.view.texture.width;
        rendering_extent.height = depth_target.view.texture.height;
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
    };

    depth_attachment   : VkRenderingAttachmentInfo;
    stencil_attachment : VkRenderingAttachmentInfo;

    if depth_target {
        view    := cast(*VulkanTextureView) depth_target.view;
        texture := cast(*VulkanTexture) view.texture;

        format_flags := textureFormatFlags(view.format);

        new_layout : VkImageLayout      = ---;
        aspectMask : VkImageAspectFlags = ---;

        if format_flags & (.DEPTH | .STENCIL) == (.DEPTH | .STENCIL) {
            new_layout = ifx  view.usage == .DEPTH_READ_ONLY
                         then .VK_IMAGE_LAYOUT_DEPTH_STENCIL_READ_ONLY_OPTIMAL
                         else .VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;

            aspectMask = .VK_IMAGE_ASPECT_DEPTH_BIT | .VK_IMAGE_ASPECT_STENCIL_BIT;
        } else if format_flags & .DEPTH {
            new_layout = ifx  view.usage == .DEPTH_READ_ONLY
                         then .VK_IMAGE_LAYOUT_DEPTH_READ_ONLY_OPTIMAL
                         else .VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL;

            aspectMask = .VK_IMAGE_ASPECT_DEPTH_BIT;
        } else {
            assert(format_flags & .STENCIL);

            new_layout = ifx  view.usage == .DEPTH_READ_ONLY
                         then .VK_IMAGE_LAYOUT_STENCIL_READ_ONLY_OPTIMAL
                         else .VK_IMAGE_LAYOUT_STENCIL_ATTACHMENT_OPTIMAL;

            aspectMask = .VK_IMAGE_ASPECT_STENCIL_BIT;
        }

        if texture.current_layout != new_layout {
            barriers_it.srcAccessMask                   = .VK_ACCESS_MEMORY_READ_BIT | .VK_ACCESS_MEMORY_WRITE_BIT;
            barriers_it.dstAccessMask                   = .VK_ACCESS_MEMORY_READ_BIT | .VK_ACCESS_MEMORY_WRITE_BIT;
            barriers_it.oldLayout                       = texture.current_layout;
            barriers_it.newLayout                       = new_layout;
            barriers_it.srcQueueFamilyIndex             = VK_QUEUE_FAMILY_IGNORED;
            barriers_it.dstQueueFamilyIndex             = VK_QUEUE_FAMILY_IGNORED;
            barriers_it.image                           = texture.image;
            barriers_it.subresourceRange.aspectMask     = aspectMask;
            barriers_it.subresourceRange.baseMipLevel   = view.first_mip;
            barriers_it.subresourceRange.levelCount     = view.mips_count;
            barriers_it.subresourceRange.baseArrayLayer = view.first_layer;
            barriers_it.subresourceRange.layerCount     = max(view.layers_count, 1);

            texture.current_layout = new_layout;

            barriers_it += 1;
        }

        if format_flags & .DEPTH {
            depth_attachment.imageView                     = view.view;
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
            stencil_attachment.imageView                       = view.view;
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

drawVulkanPrimitives :: inline (
    command_buffer  : VkCommandBuffer,
    shader          : *VulkanShader,
    vertices_count  : u32,
    instances_count : u32,
    first_vertex    : u32,
    first_instance  : u32
) #no_context {
    if !shader.pipeline return;

    vkCmdDraw(command_buffer, vertices_count, instances_count, first_vertex, first_instance);
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

copyVulkanBuffer :: inline (
    command_buffer : VkCommandBuffer,
    dest_buffer    : *VulkanBuffer,
    source_buffer  : *VulkanBuffer,
    dest_offset    : u32,
    source_offset  : u32,
    bytes          : u32
) #no_context {
    region := VkBufferCopy2.{
        srcOffset = cast(VkDeviceSize) source_offset,
        dstOffset = cast(VkDeviceSize) dest_offset,
        size      = cast(VkDeviceSize) bytes
    };

    info := VkCopyBufferInfo2.{
        srcBuffer   = source_buffer.buffer,
        dstBuffer   = dest_buffer.buffer,
        regionCount = 1,
        pRegions    = *region
    };

    vkCmdCopyBuffer2(command_buffer, *info);
}

copyVulkanBufferRegions :: (
    command_buffer : VkCommandBuffer,
    dest_buffer    : *VulkanBuffer,
    source_buffer  : *VulkanBuffer,
    regions        : [] CopyRegion
) {
    vk_regions : [] VkBufferCopy2 = ---;
    vk_regions.count = regions.count;
    vk_regions.data  = pushToArena(*context.pet.arenas.per_frame, VkBufferCopy2, regions.count);

    regions_it := regions.data;
    for * vk_regions {
        it.srcOffset = cast(VkDeviceSize) regions_it.source_offset;
        it.dstOffset = cast(VkDeviceSize) regions_it.dest_offset;
        it.size      = cast(VkDeviceSize) regions_it.bytes;

        regions_it += 1;
    }

    info := VkCopyBufferInfo2.{
        srcBuffer   = source_buffer.buffer,
        dstBuffer   = dest_buffer.buffer,
        regionCount = cast(u32) vk_regions.count,
        pRegions    = vk_regions.data
    };

    vkCmdCopyBuffer2(command_buffer, *info);
}

copyVulkanBufferToTexture :: (
    command_buffer : VkCommandBuffer,
    texture        : *VulkanTexture,
    buffer         : *VulkanBuffer,
    regions        : [] BufferToTextureCopyRegion
) {
    changeVulkanTextureLayout(command_buffer, texture, .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL);

    vk_regions : [] VkBufferImageCopy2 = ---;
    vk_regions.count = regions.count;
    vk_regions.data  = pushToArena(*context.pet.arenas.per_frame, VkBufferImageCopy2, regions.count);

    vk_aspect_flags := getVulkanImageAspectFlags(texture.format);

    regions_it := regions.data;
    for * vk_regions {
        it.bufferOffset = cast(VkDeviceSize) regions_it.buffer_offset;

        it.imageSubresource.aspectMask     = vk_aspect_flags;
        it.imageSubresource.mipLevel       = regions_it.texture_mip;
        it.imageSubresource.baseArrayLayer = regions_it.texture_array_layer * 6 + regions_it.texture_face;
        it.imageSubresource.layerCount     = 1;

        it.imageExtent.width  = max(texture.width  >> regions_it.texture_mip, 1);
        it.imageExtent.height = max(texture.height >> regions_it.texture_mip, 1);
        it.imageExtent.depth  = ifx  texture.dimension == ._3D
                                then max(texture.depth >> regions_it.texture_mip, 1)
                                else 1;

        regions_it += 1;
    }

    info := VkCopyBufferToImageInfo2.{
        srcBuffer      = buffer.buffer,
        dstImage       = texture.image,
        dstImageLayout = .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        regionCount    = cast(u32) vk_regions.count,
        pRegions       = vk_regions.data
    };

    vkCmdCopyBufferToImage2(command_buffer, *info);
}

#scope_file

// @Speed: Figure out something more optimal with access masks and pipeline stages.
changeVulkanTextureLayout :: (command_buffer : VkCommandBuffer, texture : *VulkanTexture, new_layout : VkImageLayout) {
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

loadActionToVulkanLoadOp :: inline (action : TargetLoadAction) -> VkAttachmentLoadOp #no_context {
    if #complete action == {
        case .NONE;  return .VK_ATTACHMENT_LOAD_OP_DONT_CARE;
        case .CLEAR; return .VK_ATTACHMENT_LOAD_OP_CLEAR;
        case .LOAD;  return .VK_ATTACHMENT_LOAD_OP_LOAD;
    }
}

storeActionToVulkanStoreOp :: inline (action : TargetStoreAction) -> VkAttachmentStoreOp #no_context {
    if #complete action == {
        case .NONE;  return .VK_ATTACHMENT_STORE_OP_DONT_CARE;
        case .STORE; return .VK_ATTACHMENT_STORE_OP_STORE;
    }
}

shaderBindPointToVulkanPipelineBindPoint :: inline (bind_point : ShaderBindPoint) -> VkPipelineBindPoint #no_context {
    if #complete bind_point == {
        case .GRAPHICS_OR_MESH; return .VK_PIPELINE_BIND_POINT_GRAPHICS;
        case .COMPUTE;          return .VK_PIPELINE_BIND_POINT_COMPUTE;
        case .RAY_TRACING;      return .VK_PIPELINE_BIND_POINT_RAY_TRACING_KHR;
    }
}
