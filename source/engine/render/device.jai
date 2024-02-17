// @TODO: Vtable for platform functions

Device :: struct {
    Type :: enum u8 {
        INVALID;
        DISCRETE;
        INTEGRATED;
    }

    MAX_SWAPCHAIN_BUFFERS : u8  : 8;
    MAX_COMMAND_BUFFERS   : s32 : 16;
    MAX_FRAME_BUFFERING   : u8  : #run Basic.enum_highest_value(FrameBuffering);

    QUEUE_TYPES_COUNT :: #run Basic.enum_highest_value(QueueType) + 1;

    vendor_id    : PCIVendorID;
    type         : Type;
    graphics_api : GraphicsAPI;

    swapchain_buffers_count : u8;
    back_buffer_index       : u8;

    render_resolution : struct {
        width  : u16;
        height : u16;
    };

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

RenderResolution :: enum u8 {
    P_NATIVE;
    P_1280_X_720;
    P_1920_X_1080;
    P_2560_X_1440;
    P_3840_X_2160;
    P_4096_X_2160;
    P_5120_X_2880;
    P_7680_X_4320;
}

createDevice :: (
    graphics_api      : GraphicsAPI,
    window            : *Window,
    frame_buffering   : FrameBuffering   = .DOUBLE,
    render_resolution : RenderResolution = .P_NATIVE
) -> *Device #must {
    device : *Device;

    infoMessage("Using graphics API: %", graphics_api);

    if #complete graphics_api == {
        case .VULKAN;
            device = createVulkanDevice(window, frame_buffering);
    }

    device.graphics_api = graphics_api;

    if #complete render_resolution == {
        case .P_NATIVE;      device.render_resolution = .{ window.surface.width, window.surface.height };
        case .P_1280_X_720;  device.render_resolution = .{ 1280,  720 };
        case .P_1920_X_1080; device.render_resolution = .{ 1920, 1080 };
        case .P_2560_X_1440; device.render_resolution = .{ 2560, 1440 };
        case .P_3840_X_2160; device.render_resolution = .{ 3840, 2160 };
        case .P_4096_X_2160; device.render_resolution = .{ 4096, 2160 };
        case .P_5120_X_2880; device.render_resolution = .{ 5120, 2880 };
        case .P_7680_X_4320; device.render_resolution = .{ 7680, 4320 };
    }

    infoMessage("Render resolution: % (% x %)", render_resolution, device.render_resolution.width, device.render_resolution.height);

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
