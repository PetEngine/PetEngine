Buffer :: struct {
    Usage :: enum u8 {
        NONE;
        UNIFORM;    // DirectX: CBV. Vulkan: Uniform buffer.
        READ_ONLY;  // DirectX: SRV. Vulkan: Read-only storage buffer.
        READ_WRITE; // DirectX: UAV. Vulkan: Read-write storage buffer.
    }

    size            : u32;
    usage           : Usage;
    lifetime        : ResourceManager.Lifetime;
    name            : string;
    mapped_memory   : *void;
    device_address  : u64;
    current_owner   : QueueType;
    possible_owners : StaticArray(QueueType, Device.QUEUE_TYPES_COUNT);
}

createBuffer :: (
    size            : u32,
    lifetime        : ResourceManager.Lifetime,
    pool            : ResourceManager.Pool,
    usage           : Buffer.Usage,
    name            : string,
    possible_owners : ..QueueType = .[ .GRAPHICS ]
) -> *Buffer {
    assert(!resourceMemoryCommitted(lifetime), "You cannot create %1 buffer after %1 memory is committed", lifetime);

    assert(name.count <= ResourceManager.MAX_RESOURCE_NAME_LENGTH,
           "Max buffer name length (%) > ResourceManager.MAX_RESOURCE_NAME_LENGTH (%)",
           name.count, ResourceManager.MAX_RESOURCE_NAME_LENGTH);

    assert(pool != .UPLOAD || usage == .NONE || usage == .UNIFORM, "Only NONE and UNIFORM usages are allowed on UPLOAD pool");
    assert(pool != .READ_BACK || usage == .NONE, "Only NONE usage is allowed on READ_BACK pool");
    assert(usage != .UNIFORM || pool == .UPLOAD, "Uniform buffers could be created only on UPLOAD pool");

    manager := context.pet.render.resource_manager;

    // We can bind only uniform buffers, so we don't really care about storage buffer offset alignemt
    if usage == .UNIFORM && size > context.pet.render.binding_manager.uniform_buffer_offset_alignment {
        size = alignUpWithPowerOfTwo(size, context.pet.render.binding_manager.uniform_buffer_offset_alignment);
    }

    buffer := manager.pushPlatformBuffer(lifetime, pool);

    buffer.size                  = size;
    buffer.usage                 = usage;
    buffer.lifetime              = lifetime;
    buffer.current_owner         = possible_owners[0];
    buffer.possible_owners.count = possible_owners.count;
    memcpy(buffer.possible_owners.data.data, possible_owners.data, possible_owners.count * size_of(QueueType));

    manager.createPlatformBuffer(buffer, pool, name);

    return buffer;
}
