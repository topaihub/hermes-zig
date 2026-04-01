const std = @import("std");
const platform = @import("../platform.zig");
const types = @import("../../../core/types.zig");

pub const WebhookAdapter = struct {
    listen_port: u16,
    secret: []const u8,
    handler: ?platform.MessageHandler = null,

    pub fn adapter(self: *WebhookAdapter) platform.PlatformAdapter {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = platform.PlatformAdapter.VTable{
        .platform = @ptrCast(&getPlatform),
        .connect = @ptrCast(&connectStub),
        .send = @ptrCast(&sendStub),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitStub),
    };

    fn getPlatform(_: *WebhookAdapter) types.Platform { return .webhook; }
    fn connectStub(_: *WebhookAdapter) !void {}
    fn sendStub(_: *WebhookAdapter, _: std.mem.Allocator, _: []const u8, _: []const u8, _: ?[]const u8) !platform.SendResult { return .{}; }
    fn setHandler(self: *WebhookAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitStub(_: *WebhookAdapter) void {}
};
