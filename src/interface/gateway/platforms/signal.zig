const std = @import("std");
const platform = @import("../platform.zig");
const types = @import("../../../core/types.zig");

pub const SignalAdapter = struct {
    account: []const u8,
    http_url: []const u8,
    handler: ?platform.MessageHandler = null,

    pub fn adapter(self: *SignalAdapter) platform.PlatformAdapter {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = platform.PlatformAdapter.VTable{
        .platform = @ptrCast(&getPlatform),
        .connect = @ptrCast(&connectStub),
        .send = @ptrCast(&sendStub),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitStub),
    };

    fn getPlatform(_: *SignalAdapter) types.Platform { return .signal; }
    fn connectStub(_: *SignalAdapter) !void {}
    fn sendStub(_: *SignalAdapter, _: std.mem.Allocator, _: []const u8, _: []const u8, _: ?[]const u8) !platform.SendResult { return .{}; }
    fn setHandler(self: *SignalAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitStub(_: *SignalAdapter) void {}
};
