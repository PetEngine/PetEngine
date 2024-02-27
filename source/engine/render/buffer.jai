Buffer :: struct {
    Usage :: enum u8 {
        NONE;
        UNIFORM;    // DirectX: CBV. Vulkan: Uniform buffer.
        READ_ONLY;  // DirectX: SRV. Vulkan: Read-only storage buffer.
        READ_WRITE; // DirectX: UAV. Vulkan: Read-write storage buffer.
    }

    Flags :: enum_flags u8 {
        RAW;    // Raw or structured buffer
        MAPPED;
    }

    bytes           : u32;
    usage           : Usage;
    flags           : Flags;
    name            : string;
    mapped_memory   : *void;
    current_owner   : QueueType;
    possible_owners : StaticArray(QueueType, Device.QUEUE_TYPES_COUNT);
}

createBuffer :: (
    device          : *Device,
    manager         : *ResourceManager,
    bytes           : u32,
    lifetime        : ResourceManager.Lifetime,
    pool            : ResourceManager.Pool,
    usage           : Buffer.Usage,
    name            : string,
    flags           : Buffer.Flags = 0,
    possible_owners : ..QueueType  = .[ .GRAPHICS ]
) -> *Buffer #must {
    assert(name.count <= ResourceManager.MAX_RESOURCE_NAME_LENGTH,
           "Max buffer name length (%) > ResourceManager.MAX_RESOURCE_NAME_LENGTH (%)",
           name.count, ResourceManager.MAX_RESOURCE_NAME_LENGTH);
    assert(pool == .DEFAULT || usage == .NONE,
           "Only NONE usage is allowed with non-DEFAULT pools");
    assert(!(pool == .DEFAULT && (flags & .MAPPED)),
           "Buffers in DEFAULT pool cannot be mapped");

    buffer := manager.pushPlatformBuffer(device, manager, lifetime, pool);

    buffer.bytes                 = bytes;
    buffer.usage                 = usage;
    buffer.flags                 = flags;
    buffer.current_owner         = possible_owners[0];
    buffer.possible_owners.count = possible_owners.count;
    memcpy(buffer.possible_owners.data.data, possible_owners.data, possible_owners.count * size_of(QueueType));

    manager.createPlatformBuffer(device, manager, buffer, lifetime, pool, name);

    return buffer;
}

#scope_file

#load "vulkan/buffer.jai";
