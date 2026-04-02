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
        .connect = @ptrCast(&connectImpl),
        .send = @ptrCast(&sendImpl),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitImpl),
    };

    fn getPlatform(_: *DiscordAdapter) types.Platform { return .discord; }

    fn connectImpl(self: *DiscordAdapter) !void {
        // Discord Gateway WSS: wss://gateway.discord.gg/?v=10&encoding=json
        // Auth: Bot token via Identify payload
        if (self.bot_token.len == 0) return error.MissingToken;
    }

    fn sendImpl(self: *DiscordAdapter, allocator: std.mem.Allocator, target: []const u8, content: []const u8, _: ?[]const u8) anyerror!platform.SendResult {
        // POST https://discord.com/api/v10/channels/{channel_id}/messages
        // Header: Authorization: Bot {token}
        _ = self;
        _ = allocator;
        _ = target;
        _ = content;
        return .{ .message_id = "dc_msg_sent", .allocator = null };
    }

    fn setHandler(self: *DiscordAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitImpl(_: *DiscordAdapter) void {}
};
