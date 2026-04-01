const std = @import("std");
const platform = @import("../platform.zig");
const types = @import("../../../core/types.zig");

pub const EmailAdapter = struct {
    imap_host: []const u8,
    smtp_host: []const u8,
    username: []const u8,
    handler: ?platform.MessageHandler = null,

    pub fn adapter(self: *EmailAdapter) platform.PlatformAdapter {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = platform.PlatformAdapter.VTable{
        .platform = @ptrCast(&getPlatform),
        .connect = @ptrCast(&connectStub),
        .send = @ptrCast(&sendStub),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitStub),
    };

    fn getPlatform(_: *EmailAdapter) types.Platform { return .email; }
    fn connectStub(_: *EmailAdapter) !void {}
    fn sendStub(_: *EmailAdapter, _: std.mem.Allocator, _: []const u8, _: []const u8, _: ?[]const u8) !platform.SendResult { return .{}; }
    fn setHandler(self: *EmailAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitStub(_: *EmailAdapter) void {}
};
