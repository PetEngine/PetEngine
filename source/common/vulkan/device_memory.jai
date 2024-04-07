#scope_export

// Provided by VK_VERSION_1_0
VkDeviceMemory :: *VkDeviceMemory_T; VkDeviceMemory_T :: struct {}

// Provided by VK_VERSION_1_0
VK_MAX_MEMORY_TYPES : u32 : 32;

// Provided by VK_VERSION_1_0
VK_MAX_MEMORY_HEAPS : u32 : 16;

// Provided by VK_VERSION_1_0
VkMemoryPropertyFlags :: enum_flags VkFlags #specified {
    VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT        :: 0x00000001;
    VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT        :: 0x00000002;
    VK_MEMORY_PROPERTY_HOST_COHERENT_BIT       :: 0x00000004;
    VK_MEMORY_PROPERTY_HOST_CACHED_BIT         :: 0x00000008;
    VK_MEMORY_PROPERTY_LAZILY_ALLOCATED_BIT    :: 0x00000010;
    // Provided by VK_VERSION_1_1
    VK_MEMORY_PROPERTY_PROTECTED_BIT           :: 0x00000020;
    // Provided by VK_AMD_device_coherent_memory
    VK_MEMORY_PROPERTY_DEVICE_COHERENT_BIT_AMD :: 0x00000040;
    // Provided by VK_AMD_device_coherent_memory
    VK_MEMORY_PROPERTY_DEVICE_UNCACHED_BIT_AMD :: 0x00000080;
    // Provided by VK_NV_external_memory_rdma
    VK_MEMORY_PROPERTY_RDMA_CAPABLE_BIT_NV     :: 0x00000100;
}

// Provided by VK_VERSION_1_0
VkMemoryHeapFlags :: enum_flags VkFlags #specified {
    VK_MEMORY_HEAP_DEVICE_LOCAL_BIT       :: 0x00000001;
    // Provided by VK_VERSION_1_1
    VK_MEMORY_HEAP_MULTI_INSTANCE_BIT     :: 0x00000002;
    // Provided by VK_KHR_device_group_creation
    VK_MEMORY_HEAP_MULTI_INSTANCE_BIT_KHR :: VK_MEMORY_HEAP_MULTI_INSTANCE_BIT;
}

// Provided by VK_VERSION_1_0
VkMemoryMapFlags :: enum_flags VkFlags #specified {
    // Provided by VK_EXT_map_memory_placed
    VK_MEMORY_MAP_PLACED_BIT_EXT :: 0x00000001;
}

// Provided by VK_VERSION_1_1
VkMemoryAllocateFlags :: enum_flags VkFlags #specified {
    VK_MEMORY_ALLOCATE_DEVICE_MASK_BIT                       :: 0x00000001;
    // Provided by VK_VERSION_1_2
    VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT                    :: 0x00000002;
    // Provided by VK_VERSION_1_2
    VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT     :: 0x00000004;
    // Provided by VK_KHR_device_group
    VK_MEMORY_ALLOCATE_DEVICE_MASK_BIT_KHR                   :: VK_MEMORY_ALLOCATE_DEVICE_MASK_BIT;
    // Provided by VK_KHR_buffer_device_address
    VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT_KHR                :: VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT;
    // Provided by VK_KHR_buffer_device_address
    VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT_KHR :: VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT;
}

// Provided by VK_VERSION_1_0
VkMemoryType :: struct {
    propertyFlags : VkMemoryPropertyFlags;
    heapIndex     : u32;
}

// Provided by VK_VERSION_1_0
VkMemoryHeap :: struct {
    size  : VkDeviceSize;
    flags : VkMemoryHeapFlags;
}

// Provided by VK_VERSION_1_0
VkPhysicalDeviceMemoryProperties :: struct {
    memoryTypeCount : u32;
    memoryTypes     : [VK_MAX_MEMORY_TYPES] VkMemoryType;
    memoryHeapCount : u32;
    memoryHeaps     : [VK_MAX_MEMORY_HEAPS] VkMemoryHeap;
}

// Provided by VK_VERSION_1_1
VkPhysicalDeviceMemoryProperties2 :: struct {
    sType            : VkStructureType = .VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MEMORY_PROPERTIES_2;
    pNext            : *void;
    memoryProperties : VkPhysicalDeviceMemoryProperties;
}

// Provided by VK_VERSION_1_0
VkMemoryAllocateInfo :: struct {
    sType           : VkStructureType = .VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    pNext           : *void;
    allocationSize  : VkDeviceSize;
    memoryTypeIndex : u32;
}

// Provided by VK_VERSION_1_1
VkMemoryAllocateFlagsInfo :: struct {
    sType      : VkStructureType = .VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_FLAGS_INFO;
    pNext      : *void;
    flags      : VkMemoryAllocateFlags;
    deviceMask : u32;
}

// Provided by VK_VERSION_1_1
vkGetPhysicalDeviceMemoryProperties2 :: (
    physicalDevice    : VkPhysicalDevice,
    pMemoryProperties : *VkPhysicalDeviceMemoryProperties2
) #foreign vulkan;

// Provided by VK_VERSION_1_0
vkAllocateMemory :: (
    device        : VkDevice,
    pAllocateInfo : *VkMemoryAllocateInfo,
    pAllocator    : *VkAllocationCallbacks,
    pMemory       : *VkDeviceMemory
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkFreeMemory :: (
    device     : VkDevice,
    memory     : VkDeviceMemory,
    pAllocator : *VkAllocationCallbacks
) #foreign vulkan;

// Provided by VK_VERSION_1_0
vkMapMemory :: (
    device : VkDevice,
    memory : VkDeviceMemory,
    offset : VkDeviceSize,
    size   : VkDeviceSize,
    flags  : VkMemoryMapFlags,
    ppData : **void
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkUnmapMemory :: (
    device : VkDevice,
    memory : VkDeviceMemory
) #foreign vulkan;
