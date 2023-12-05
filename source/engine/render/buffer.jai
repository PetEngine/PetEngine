Buffer :: struct {
    Usage :: enum u8 {
        NONE;
        UNIFORM;    // DirectX: CBV. Vulkan: Uniform buffer.
        READ_ONLY;  // DirectX: SRV. Vulkan: Read-only storage buffer.
        READ_WRITE; // DirectX: UAV. Vulkan: Read-write storage buffer.
    }

    Flags :: enum_flags u8 {
        RAW; // Raw or structured buffer
    }

    bytes           : u32;
    usage           : Usage;
    flags           : Flags;
    name            : string;
    current_owner   : QueueType;
    possible_owners : StaticArray(QueueType, #run Basic.enum_highest_value(QueueType) + 1);
}

createBuffer :: (
    device          : *Device,
    manager         : *ResourceManager,
    bytes           : u32,
    usage           : Buffer.Usage,
    flags           : Buffer.Flags     = 0,
    name            : string,
    $memory_kind    : ResourceManager.MemoryKind,
    possible_owners : ..QueueType      = .[ .GRAPHICS ]
) -> *Buffer #must {
    buffer := manager.pushPlatformBuffer(device, manager, memory_kind);

    buffer.bytes                 = bytes;
    buffer.usage                 = usage;
    buffer.flags                 = flags;
    buffer.name                  = name;
    buffer.current_owner         = possible_owners[0];
    buffer.possible_owners.count = possible_owners.count;
    memcpy(buffer.possible_owners.data.data, possible_owners.data, possible_owners.count * size_of(QueueType));

    manager.createPlatformBuffer(device, manager, buffer);

    return buffer;
}

#scope_file

#load "vulkan/buffer.jai";
