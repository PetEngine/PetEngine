Device :: struct {
    Type :: enum u16 {
        INVALID;
        DISCRETE;
        INTEGRATED;
    }

    MAX_SWAPCHAIN_BUFFERS : u32 : 3;
    MAX_COMMAND_BUFFERS   : s32 : 16;

    vendor_id               : PCIVendorID;
    type                    : Type;
    graphics_api            : GraphicsAPI;
    swapchain_buffers_count : u32;
    back_buffer_index       : u32;
}

GraphicsAPI :: enum u32 {
    VULKAN;
}

// @TODO: Rename to DEFAULT, ASYNC_COMPUTE, ASYNC_COPY and, probably, PRESENT.
QueueType :: enum u16 {
    GRAPHICS;
    COMPUTE;
    COPY;
}

PCIVendorID :: enum u32 {
    NVIDIA   :: 0x10DE;
    AMD      :: 0x1022;
    INTEL    :: 0x8086; // Very wow, actually
    QUALCOMM :: 0x17CB;
    ARM      :: 0x13B5;

    // Vulkan specific vendor IDs
    VK_VENDOR_ID_VIV      :: 0x10001;
    VK_VENDOR_ID_VSI      :: 0x10002;
    VK_VENDOR_ID_KAZAN    :: 0x10003;
    VK_VENDOR_ID_CODEPLAY :: 0x10004;
    VK_VENDOR_ID_MESA     :: 0x10005;
    VK_VENDOR_ID_POCL     :: 0x10006;
    VK_VENDOR_ID_MOBILEYE :: 0x10007;
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

beginFrame :: (device : *Device) {
    if #complete device.graphics_api == {
        case .VULKAN;
            beginVulkanFrame(cast(*VulkanDevice) device);
    }
}

endFrame :: (device : *Device) {
    if #complete device.graphics_api == {
        case .VULKAN;
            endVulkanFrame(cast(*VulkanDevice) device);
    }
}

recreateSwapchain :: (device : *Device, window : *Window) {
    if #complete device.graphics_api == {
        case .VULKAN;
            recreateVulkanSwapchain(cast(*VulkanDevice) device, window);
    }
}

waitDeviceIdle :: (device : *Device) {
    if #complete device.graphics_api == {
        case .VULKAN;
            waitVulkanDeviceIdle(cast(*VulkanDevice) device);
    }
}

getSwapchainTexture :: (device : *Device, swapchain_buffer_index : u32) -> *Texture {
    texture : *Texture;

    if #complete device.graphics_api == {
        case .VULKAN;
            texture = getVulkanSwapchainTexture(cast(*VulkanDevice) device, swapchain_buffer_index);
    }

    return texture;
}

getBackBuffer :: (device : *Device) -> *Texture {
    return inline getSwapchainTexture(device, device.back_buffer_index);
}



#scope_file

#load "../platform/vulkan/loader.jai";
#load "../platform/vulkan/device.jai";
