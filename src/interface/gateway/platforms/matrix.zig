const std = @import("std");
const platform = @import("../platform.zig");
const types = @import("../../../core/types.zig");

pub const MatrixAdapter = struct {
    homeserver: []const u8,
    access_token: []const u8,
    handler: ?platform.MessageHandler = null,

    pub fn adapter(self: *MatrixAdapter) platform.PlatformAdapter {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = platform.PlatformAdapter.VTable{
        .platform = @ptrCast(&getPlatform),
        .connect = @ptrCast(&connectStub),
        .send = @ptrCast(&sendStub),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitStub),
    };

    fn getPlatform(_: *MatrixAdapter) types.Platform { return .matrix; }
    fn connectStub(_: *MatrixAdapter) !void {}
    fn sendStub(_: *MatrixAdapter, _: std.mem.Allocator, _: []const u8, _: []const u8, _: ?[]const u8) !platform.SendResult { return .{}; }
    fn setHandler(self: *MatrixAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitStub(_: *MatrixAdapter) void {}
};
