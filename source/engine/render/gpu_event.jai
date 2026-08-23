GPUEvent :: struct {
    handle : *void;
}

createGPUEvent :: (name : string) -> GPUEvent {
    event : GPUEvent;

    #if #complete GRAPHICS_API == {
        case .VULKAN;
            vulkan_device := cast(*VulkanDevice) context.pet.render.device;

            create_info : VkEventCreateInfo;
            debugCheckVK(vkCreateEvent(vulkan_device.device, *create_info, null, cast(*VkEvent) *event.handle));
            setVulkanObjectName(cast(VkEvent) event.handle, name);
    }

    return event;
}

createGPUEvent :: ($format : string, args : ..Any) -> GPUEvent {
    event : GPUEvent;

    #if #complete GRAPHICS_API == {
        case .VULKAN;
            vulkan_device := cast(*VulkanDevice) context.pet.render.device;

            create_info : VkEventCreateInfo;
            debugCheckVK(vkCreateEvent(vulkan_device.device, *create_info, null, cast(*VkEvent) *event.handle));
            setVulkanObjectName(cast(VkEvent) event.handle, format, ..args);
    }

    return event;
}

destroyGPUEvent :: (event : *GPUEvent) {
    #if #complete GRAPHICS_API == {
        case .VULKAN;
            vulkan_device := cast(*VulkanDevice) context.pet.render.device;
            vkDestroyEvent(vulkan_device.device, cast(VkEvent) event.handle, null);
    }
    event.* = .{};
}

isGPUEventSet :: (event : GPUEvent) -> bool {
    #if #complete GRAPHICS_API == {
        case .VULKAN;
            vulkan_device := cast(*VulkanDevice) context.pet.render.device;

            result := vkGetEventStatus(vulkan_device.device, cast(VkEvent) event.handle);
            assert(result == .VK_EVENT_SET || result == .VK_EVENT_RESET, "vkGetEventStatus returned %", result);

            return result == .VK_EVENT_SET;
    }
}

setGPUEvent :: (event : GPUEvent) {
    #if #complete GRAPHICS_API == {
        case .VULKAN;
            vulkan_device := cast(*VulkanDevice) context.pet.render.device;
            debugCheckVK(vkSetEvent(vulkan_device.device, cast(VkEvent) event.handle));
    }
}

resetGPUEvent :: (event : GPUEvent) {
    #if #complete GRAPHICS_API == {
        case .VULKAN;
            vulkan_device := cast(*VulkanDevice) context.pet.render.device;
            debugCheckVK(vkResetEvent(vulkan_device.device, cast(VkEvent) event.handle));
    }
}
