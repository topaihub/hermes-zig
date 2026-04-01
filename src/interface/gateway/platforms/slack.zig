const std = @import("std");
const platform = @import("../platform.zig");
const types = @import("../../../core/types.zig");

pub const SlackAdapter = struct {
    bot_token: []const u8,
    signing_secret: []const u8,
    handler: ?platform.MessageHandler = null,

    pub fn adapter(self: *SlackAdapter) platform.PlatformAdapter {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = platform.PlatformAdapter.VTable{
        .platform = @ptrCast(&getPlatform),
        .connect = @ptrCast(&connectStub),
        .send = @ptrCast(&sendStub),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitStub),
    };

    fn getPlatform(_: *SlackAdapter) types.Platform { return .slack; }
    fn connectStub(_: *SlackAdapter) !void {}
    fn sendStub(_: *SlackAdapter, _: std.mem.Allocator, _: []const u8, _: []const u8, _: ?[]const u8) !platform.SendResult { return .{}; }
    fn setHandler(self: *SlackAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitStub(_: *SlackAdapter) void {}
};
