const std = @import("std");
const platform = @import("../platform.zig");
const types = @import("../../../core/types.zig");

pub const TelegramAdapter = struct {
    bot_token: []const u8 = "",
    handler: ?platform.MessageHandler = null,
    last_update_id: i64 = 0,

    pub fn adapter(self: *TelegramAdapter) platform.PlatformAdapter {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = platform.PlatformAdapter.VTable{
        .platform = @ptrCast(&getPlatform),
        .connect = @ptrCast(&connectImpl),
        .send = @ptrCast(&sendImpl),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitImpl),
    };

    fn getPlatform(_: *TelegramAdapter) types.Platform {
        return .telegram;
    }

    fn connectImpl(self: *TelegramAdapter) !void {
        if (self.bot_token.len == 0) return error.MissingToken;
        // Would GET https://api.telegram.org/bot{token}/getUpdates with long polling
        self.last_update_id = 0;
    }

    fn sendImpl(self: *TelegramAdapter, allocator: std.mem.Allocator, target: []const u8, content: []const u8, _: ?[]const u8) anyerror!platform.SendResult {
        if (self.bot_token.len == 0) return error.MissingToken;
        // POST https://api.telegram.org/bot{token}/sendMessage
        // Body: {"chat_id": target, "text": content}
        _ = allocator;
        _ = target;
        _ = content;
        return .{ .message_id = "tg_msg_sent", .allocator = null };
    }

    fn setHandler(self: *TelegramAdapter, h: platform.MessageHandler) void {
        self.handler = h;
    }
    fn deinitImpl(_: *TelegramAdapter) void {}
};
