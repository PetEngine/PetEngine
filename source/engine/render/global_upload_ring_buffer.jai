GlobalUploadRingBuffer :: struct {
    command_buffer : CommandBuffer(.GRAPHICS);
    done_events    : [Device.MAX_FRAME_BUFFERING] GPUEvent;

    // @TODO: Make it MPSC lock-free
    buffer                : *Buffer;
    read_offset           : u64;
    write_offset          : u64;
    write_offset_on_reset : [Device.MAX_FRAME_BUFFERING] u64;
}

createGlobalUploadRingBuffer :: () {
    assertThreadKind(.MAIN);
    assert(!resourceMemoryCommitted(.PERSISTENT));

    gurb := pushToArena(*context.pet.arenas.persistent, GlobalUploadRingBuffer);
    context.pet.render.global_upload_ring_buffer = gurb;

    QUEUE_TYPE :: GlobalUploadRingBuffer.command_buffer.usage;
    gurb.command_buffer = createCommandBuffer(QUEUE_TYPE);

    for * gurb.done_events {
        it.* = createGPUEvent("GlobalUploadRingBuffer done #%", it_index);
    }

    buffer_capacity := readSetting("global_upload_ring_buffer.capacity");
    assert(isPowerOfTwo(buffer_capacity));

    gurb.buffer = createBuffer(buffer_capacity, .PERSISTENT, .UPLOAD, .NONE, "Global", QUEUE_TYPE);
}

destroyGlobalUploadRingBuffer :: () {
    assertThreadKind(.MAIN);

    for * context.pet.render.global_upload_ring_buffer.done_events {
        destroyGPUEvent(it);
    }
}

resetGlobalUploadRingBuffer :: () {
    assertThreadKind(.MAIN);

    gurb   := context.pet.render.global_upload_ring_buffer;
    device := context.pet.render.device;

    resetCommandBuffer(*gurb.command_buffer);
    resetGPUEvent(gurb.command_buffer, gurb.done_events[device.frame_index]);

    gurb.read_offset = gurb.write_offset_on_reset[device.frame_index];
    gurb.write_offset_on_reset[device.frame_index] = gurb.write_offset;
}

submitGlobalUploadRingBuffer :: () {
    assertThreadKind(.MAIN);
    assert(resourceMemoryCommitted(.PERSISTENT));

    gurb := context.pet.render.global_upload_ring_buffer;

    setGPUEvent(gurb.command_buffer, gurb.done_events[context.pet.render.device.frame_index]);
    submitCommandBuffer(*gurb.command_buffer);
}

acquireGlobalUploadRingBufferMemory :: (data_size : u64, alignment : u64 = 1, $may_cycle := true) -> (offset : u32) {
    assertThreadKind(.MAIN);
    gurb := context.pet.render.global_upload_ring_buffer;

    aligned_write_offset := gurb.write_offset;
    buffer_size_mask     : u64 = gurb.buffer.size - 1;

    #if !may_cycle {
        bytes_until_end := gurb.buffer.size - (gurb.write_offset & buffer_size_mask);
        if bytes_until_end < data_size {
            aligned_write_offset = alignUpWithPowerOfTwo(aligned_write_offset, gurb.buffer.size);
        }
    }

    aligned_write_offset = alignUpWithPowerOfTwo(aligned_write_offset, alignment);

    clamped_aligned_write_offset := cast(u32, aligned_write_offset & buffer_size_mask);
    assertAligned(clamped_aligned_write_offset, alignment);

    new_write_offset := aligned_write_offset + data_size;

    assert(new_write_offset - gurb.read_offset <= gurb.buffer.size, #string END
Global upload ring buffer overflow:
    Buffer size:                  % (% MB)
    Read offset:                  %
    Write offset:                 %
    Aligned write offset:         %
    Clamped aligned write offset: %
    Alignment:                    %
    New write offset:             %
    May cycle:                    %
END,
           gurb.buffer.size, bytesToMegaBytes(gurb.buffer.size),
           gurb.read_offset,
           gurb.write_offset,
           aligned_write_offset,
           clamped_aligned_write_offset,
           alignment,
           new_write_offset,
           may_cycle);

    gurb.write_offset = new_write_offset;

    return clamped_aligned_write_offset;
}
