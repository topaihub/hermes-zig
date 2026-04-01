const std = @import("std");
const platform = @import("../platform.zig");
const types = @import("../../../core/types.zig");

pub const TelegramAdapter = struct {
    handler: ?platform.MessageHandler = null,

    pub fn adapter(self: *TelegramAdapter) platform.PlatformAdapter {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = platform.PlatformAdapter.VTable{
        .platform = @ptrCast(&getPlatform),
        .connect = @ptrCast(&connectStub),
        .send = @ptrCast(&sendStub),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitStub),
    };

    fn getPlatform(_: *TelegramAdapter) types.Platform {
        return .telegram;
    }
    fn connectStub(_: *TelegramAdapter) !void {}
    fn sendStub(_: *TelegramAdapter, _: std.mem.Allocator, _: []const u8, _: []const u8, _: ?[]const u8) !platform.SendResult {
        return .{};
    }
    fn setHandler(self: *TelegramAdapter, h: platform.MessageHandler) void {
        self.handler = h;
    }
    fn deinitStub(_: *TelegramAdapter) void {}
};
