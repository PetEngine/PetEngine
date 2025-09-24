Device :: struct {
    Type :: enum u8 {
        UNKNOWN;
        DISCRETE;
        INTEGRATED;
        VIRTUAL;
        CPU;
    }

    WindowData :: struct {
        swapchain_buffers_count : u8;
        back_buffer_index       : u8;
        swapchain_is_outdated   : bool;
    }

    MAX_SWAPCHAIN_BUFFERS : u8  : 8;
    MAX_COMMAND_BUFFERS   : s32 : 16;
    MAX_FRAME_BUFFERING   : u8  : #run Basic.enum_highest_value(FrameBuffering);

    QUEUE_TYPES_COUNT :: #run Basic.enum_highest_value(QueueType) + 1;

    vendor_id    : PCIVendorID;
    type         : Type;
    graphics_api : GraphicsAPI;

    window_data : [WindowManager.MAX_WINDOWS] WindowData;

    back_buffer_format : Texture.Format;
    render_resolution : Resolution;

    frame_buffering : FrameBuffering;
    frame_index     : u8;

    //
    // VTable
    //

    destroyPlatformDevice : ();

    initPlatformWindowData : (window : *Window);

    beginPlatformFrame : ();
    endPlatformFrame   : ();

    waitPlatformDeviceIdle : ();

    getPlatformSwapchainTexture     : (window : *Window, swapchain_buffer_index : u32) -> *Texture;
    getPlatformSwapchainTextureView : (window : *Window, swapchain_buffer_index : u32, usage : Texture.Usage) -> *TextureView;
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
    VK_VENDOR_ID_KHRONOS  :: 0x10000;
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

ScalingMode :: enum u8 {
    NONE;
    ASPECT_RATIO;
    STRETCH;
}

createDevice :: (graphics_api : GraphicsAPI) {
    assert(!context.pet.render.device);

    infoMessage("Using graphics API: %", graphics_api);

    frame_buffering := readSetting("render.frame_buffering");

    if #complete graphics_api == {
        case .VULKAN;
            createVulkanDevice(frame_buffering);
    }

    device := context.pet.render.device;

    device.graphics_api      = graphics_api;
    device.render_resolution = readSetting("render.resolution");

    infoMessage("Render resolution: % x %", device.render_resolution.width, device.render_resolution.height);
}

destroyDevice :: inline () {
    context.pet.render.device.destroyPlatformDevice();
}

initWindowData :: (window : *Window) {
    assert(window.id != Window.INVALID_ID);

    // Reset window data before potential reuse
    context.pet.render.device.window_data[window.id] = .{};

    context.pet.render.device.initPlatformWindowData(window);
}

scheduleSwapChainReset :: (window : *Window) {
    assert(window.id != Window.INVALID_ID);
    context.pet.render.device.window_data[window.id].swapchain_is_outdated = true;
}

beginFrame :: inline () {
    context.pet.render.device.beginPlatformFrame();
}

endFrame :: inline () {
    context.pet.render.device.endPlatformFrame();
}

waitDeviceIdle :: inline () {
    context.pet.render.device.waitPlatformDeviceIdle();
}

getSwapchainTexture :: inline (window : *Window, swapchain_buffer_index : u32) -> *Texture {
    assert(swapchain_buffer_index < context.pet.render.device.window_data[window.id].swapchain_buffers_count);
    return context.pet.render.device.getPlatformSwapchainTexture(window, swapchain_buffer_index);
}

getSwapchainTextureView :: inline (window : *Window, swapchain_buffer_index : u32, usage : Texture.Usage) -> *TextureView {
    assert(swapchain_buffer_index < context.pet.render.device.window_data[window.id].swapchain_buffers_count);
    return context.pet.render.device.getPlatformSwapchainTextureView(window, swapchain_buffer_index, usage);
}

getBackBuffer :: inline (window : *Window) -> *Texture {
    return getSwapchainTexture(window, context.pet.render.device.window_data[window.id].back_buffer_index);
}

getBackBufferView :: inline (window : *Window, usage : Texture.Usage) -> *TextureView {
    return getSwapchainTextureView(window, context.pet.render.device.window_data[window.id].back_buffer_index, usage);
}

#scope_file

#load "vulkan/loader.jai";
#load "vulkan/device.jai";
