const std = @import("std");
const platform = @import("../platform.zig");
const types = @import("../../../core/types.zig");

pub const WecomAdapter = struct {
    bot_id: []const u8,
    secret: []const u8,
    handler: ?platform.MessageHandler = null,

    pub fn adapter(self: *WecomAdapter) platform.PlatformAdapter {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = platform.PlatformAdapter.VTable{
        .platform = @ptrCast(&getPlatform),
        .connect = @ptrCast(&connectStub),
        .send = @ptrCast(&sendStub),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitStub),
    };

    fn getPlatform(_: *WecomAdapter) types.Platform { return .wecom; }
    fn connectStub(_: *WecomAdapter) !void {}
    fn sendStub(_: *WecomAdapter, _: std.mem.Allocator, _: []const u8, _: []const u8, _: ?[]const u8) !platform.SendResult { return .{}; }
    fn setHandler(self: *WecomAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitStub(_: *WecomAdapter) void {}
};
