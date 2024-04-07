Buffer :: struct {
    Usage :: enum u8 {
        NONE;
        UNIFORM;    // DirectX: CBV. Vulkan: Uniform buffer.
        READ_ONLY;  // DirectX: SRV. Vulkan: Read-only storage buffer.
        READ_WRITE; // DirectX: UAV. Vulkan: Read-write storage buffer.
    }

    size            : u32;
    usage           : Usage;
    name            : string;
    mapped_memory   : *void;
    current_owner   : QueueType;
    possible_owners : StaticArray(QueueType, Device.QUEUE_TYPES_COUNT);
}

createBuffer :: (
    device          : *Device,
    manager         : *ResourceManager,
    size            : u32,
    lifetime        : ResourceManager.Lifetime,
    pool            : ResourceManager.Pool,
    usage           : Buffer.Usage,
    name            : string,
    possible_owners : ..QueueType = .[ .GRAPHICS ]
) -> *Buffer #must {
    assert(name.count <= ResourceManager.MAX_RESOURCE_NAME_LENGTH,
           "Max buffer name length (%) > ResourceManager.MAX_RESOURCE_NAME_LENGTH (%)",
           name.count, ResourceManager.MAX_RESOURCE_NAME_LENGTH);

    assert(pool != .UPLOAD || usage == .NONE || usage == .UNIFORM, "Only NONE and UNIFORM usages are allowed on UPLOAD pool");
    assert(pool != .READ_BACK || usage == .NONE, "Only NONE usage is allowed on READ_BACK pool");
    assert(usage != .UNIFORM || pool == .UPLOAD, "Uniform buffers could be created only on UPLOAD pool");

    buffer := manager.pushPlatformBuffer(device, manager, lifetime, pool);

    buffer.size                  = size;
    buffer.usage                 = usage;
    buffer.current_owner         = possible_owners[0];
    buffer.possible_owners.count = possible_owners.count;
    memcpy(buffer.possible_owners.data.data, possible_owners.data, possible_owners.count * size_of(QueueType));

    manager.createPlatformBuffer(device, manager, buffer, lifetime, pool, name);

    return buffer;
}

#scope_file

#load "vulkan/buffer.jai";
