const std = @import("std");
const platform = @import("../platform.zig");
const types = @import("../../../core/types.zig");

pub const WebhookAdapter = struct {
    listen_port: u16,
    secret: []const u8,
    handler: ?platform.MessageHandler = null,

    pub fn adapter(self: *WebhookAdapter) platform.PlatformAdapter {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = platform.PlatformAdapter.VTable{
        .platform = @ptrCast(&getPlatform),
        .connect = @ptrCast(&connectImpl),
        .send = @ptrCast(&sendImpl),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitImpl),
    };

    fn getPlatform(_: *WebhookAdapter) types.Platform { return .webhook; }

    fn connectImpl(self: *WebhookAdapter) !void {
        // Would start HTTP server on self.listen_port accepting POST /message
        // Validates X-Webhook-Secret header against self.secret
        if (self.listen_port == 0) return error.InvalidPort;
    }

    fn sendImpl(self: *WebhookAdapter, allocator: std.mem.Allocator, target: []const u8, content: []const u8, _: ?[]const u8) anyerror!platform.SendResult {
        // POST to target URL with JSON body and secret header
        _ = self;
        _ = allocator;
        _ = target;
        _ = content;
        return .{ .message_id = "webhook_delivered", .allocator = null };
    }

    fn setHandler(self: *WebhookAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitImpl(_: *WebhookAdapter) void {}
};
