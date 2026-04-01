const std = @import("std");
const platform = @import("../platform.zig");
const types = @import("../../../core/types.zig");

pub const DiscordAdapter = struct {
    bot_token: []const u8,
    guild_id: []const u8,
    handler: ?platform.MessageHandler = null,

    pub fn adapter(self: *DiscordAdapter) platform.PlatformAdapter {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = platform.PlatformAdapter.VTable{
        .platform = @ptrCast(&getPlatform),
        .connect = @ptrCast(&connectStub),
        .send = @ptrCast(&sendStub),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitStub),
    };

    fn getPlatform(_: *DiscordAdapter) types.Platform { return .discord; }
    fn connectStub(_: *DiscordAdapter) !void {}
    fn sendStub(_: *DiscordAdapter, _: std.mem.Allocator, _: []const u8, _: []const u8, _: ?[]const u8) !platform.SendResult { return .{}; }
    fn setHandler(self: *DiscordAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitStub(_: *DiscordAdapter) void {}
};
