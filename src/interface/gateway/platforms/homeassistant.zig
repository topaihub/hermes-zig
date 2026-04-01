const std = @import("std");
const platform = @import("../platform.zig");
const types = @import("../../../core/types.zig");

pub const HomeAssistantAdapter = struct {
    ha_url: []const u8,
    token: []const u8,
    handler: ?platform.MessageHandler = null,

    pub fn adapter(self: *HomeAssistantAdapter) platform.PlatformAdapter {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = platform.PlatformAdapter.VTable{
        .platform = @ptrCast(&getPlatform),
        .connect = @ptrCast(&connectStub),
        .send = @ptrCast(&sendStub),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitStub),
    };

    fn getPlatform(_: *HomeAssistantAdapter) types.Platform { return .homeassistant; }
    fn connectStub(_: *HomeAssistantAdapter) !void {}
    fn sendStub(_: *HomeAssistantAdapter, _: std.mem.Allocator, _: []const u8, _: []const u8, _: ?[]const u8) !platform.SendResult { return .{}; }
    fn setHandler(self: *HomeAssistantAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitStub(_: *HomeAssistantAdapter) void {}
};
