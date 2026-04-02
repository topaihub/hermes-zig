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
        .connect = @ptrCast(&connectImpl),
        .send = @ptrCast(&sendImpl),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitImpl),
    };

    fn getPlatform(_: *SlackAdapter) types.Platform { return .slack; }

    fn connectImpl(self: *SlackAdapter) !void {
        // Slack Socket Mode: wss://wss-primary.slack.com/link
        // Or Events API via HTTP POST to configured endpoint
        // Auth: xoxb- bot token
        if (self.bot_token.len == 0) return error.MissingToken;
    }

    fn sendImpl(self: *SlackAdapter, allocator: std.mem.Allocator, target: []const u8, content: []const u8, _: ?[]const u8) anyerror!platform.SendResult {
        // POST https://slack.com/api/chat.postMessage
        // Header: Authorization: Bearer {bot_token}
        // Body: {"channel": target, "text": content}
        _ = self;
        _ = allocator;
        _ = target;
        _ = content;
        return .{ .message_id = "slack_msg_sent", .allocator = null };
    }

    fn setHandler(self: *SlackAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitImpl(_: *SlackAdapter) void {}
};
