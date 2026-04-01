const std = @import("std");
const platform = @import("../platform.zig");
const types = @import("../../../core/types.zig");

pub const WhatsAppAdapter = struct {
    phone_number_id: []const u8,
    access_token: []const u8,
    handler: ?platform.MessageHandler = null,

    pub fn adapter(self: *WhatsAppAdapter) platform.PlatformAdapter {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = platform.PlatformAdapter.VTable{
        .platform = @ptrCast(&getPlatform),
        .connect = @ptrCast(&connectStub),
        .send = @ptrCast(&sendStub),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitStub),
    };

    fn getPlatform(_: *WhatsAppAdapter) types.Platform { return .whatsapp; }
    fn connectStub(_: *WhatsAppAdapter) !void {}
    fn sendStub(_: *WhatsAppAdapter, _: std.mem.Allocator, _: []const u8, _: []const u8, _: ?[]const u8) !platform.SendResult { return .{}; }
    fn setHandler(self: *WhatsAppAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitStub(_: *WhatsAppAdapter) void {}
};
