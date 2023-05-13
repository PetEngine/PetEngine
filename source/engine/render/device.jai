QueueType :: enum u8 {
    GRAPHICS;
    COMPUTE;
    COPY;
}

GraphicsAPI :: enum u8 {
    VULKAN;
}

PCIVendorID :: enum u32 {
    NVIDIA   :: 0x10DE;
    AMD      :: 0x1022;
    INTEL    :: 0x8086; // Very wow, actually
    QUALCOMM :: 0x17CB;
    ARM      :: 0x13B5;
}

Device :: struct {
    Type :: enum u32 {
        INVALID;
        DISCRETE;
        INTEGRATED;
    }

    type                    : Type;
    graphics_api            : GraphicsAPI;
    swapchain_buffers_count : u32;
    backbuffer_index        : u32;
}

createDevice :: (graphics_api : GraphicsAPI, window : *Window) -> *Device #must {
    device : *Device;

    infoMessage("Using graphics API: %", graphics_api);

    if #complete graphics_api == {
        case .VULKAN;
            device = createVulkanDevice(window);
    }

    device.graphics_api = graphics_api;

    return device;
}

destroyDevice :: (device : *Device) {
    if #complete device.graphics_api == {
        case .VULKAN;
            destroyVulkanDevice(cast(*VulkanDevice) device);
    }
}

#scope_file

#load "../platform/vulkan/loader.jai";
#load "../platform/vulkan/device.jai";
