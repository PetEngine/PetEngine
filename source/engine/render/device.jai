DeviceTypes :: enum u32 {
    INVALID;
    DISCRETE;
    INTEGRATED;
}

QueueTypes :: enum u32 {
    GRAPHICS;
    COMPUTE;
    COPY;

    MAX;
}

GraphicsAPI :: enum u8 {
    VULKAN;
};

PCIVendorID :: enum u32 {
    NVIDIA   :: 0x10DE;
    AMD      :: 0x1022;
    INTEL    :: 0x8086; // Very wow, actually
    QUALCOMM :: 0x17CB;
    ARM      :: 0x13B5;
}

Device :: struct {
    MAX_SWAPCHAIN_BUFFERS :: 3;

    type         : DeviceTypes;
    graphics_api : GraphicsAPI;
}

createDevice :: (graphics_api : GraphicsAPI, window : *Window) -> *Device #must {
    device : *Device;

    infoMessage("Using graphics API: %", graphics_api);

    if #complete graphics_api == {
        case .VULKAN;
            device = createVulkanDevice(window);
    };

    device.graphics_api = graphics_api;

    return device;
}

destroyDevice :: (device : *Device) {
    destroyVulkanDevice(cast(*VulkanDevice) device);
}
