Device :: struct {
    Type :: enum u8 {
        INVALID;
        DISCRETE;
        INTEGRATED;
    }

    MAX_SWAPCHAIN_BUFFERS : u8  : 8;
    MAX_COMMAND_BUFFERS   : s32 : 16;
    MAX_FRAME_BUFFERING   : u8  : #run Basic.enum_highest_value(FrameBuffering);

    vendor_id    : PCIVendorID;
    type         : Type;
    graphics_api : GraphicsAPI;

    swapchain_buffers_count : u8;
    back_buffer_index       : u8;

    frame_buffering : FrameBuffering;
    frame_index     : u8;
}

GraphicsAPI :: enum u8 {
    VULKAN;
}

QueueType :: enum u8 {
    GRAPHICS;
    ASYNC_COMPUTE;
    ASYNC_TRANSFER;
}

PCIVendorID :: enum u32 #specified {
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

FrameBuffering :: enum u8 #specified {
    NONE   :: 1;
    DOUBLE :: 2;
    TRIPLE :: 3;
}

createDevice :: (graphics_api : GraphicsAPI, window : *Window, frame_buffering : FrameBuffering) -> *Device #must {
    device : *Device;

    infoMessage("Using graphics API: %", graphics_api);

    if #complete graphics_api == {
        case .VULKAN;
            device = createVulkanDevice(window, frame_buffering);
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
    assert(swapchain_buffer_index < device.swapchain_buffers_count);

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

#load "vulkan/loader.jai";
#load "vulkan/device.jai";
