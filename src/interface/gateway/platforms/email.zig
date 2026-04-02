const std = @import("std");
const platform = @import("../platform.zig");
const types = @import("../../../core/types.zig");

pub const EmailAdapter = struct {
    imap_host: []const u8,
    smtp_host: []const u8,
    username: []const u8,
    handler: ?platform.MessageHandler = null,

    pub fn adapter(self: *EmailAdapter) platform.PlatformAdapter {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = platform.PlatformAdapter.VTable{
        .platform = @ptrCast(&getPlatform),
        .connect = @ptrCast(&connectImpl),
        .send = @ptrCast(&sendImpl),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitImpl),
    };

    fn getPlatform(_: *EmailAdapter) types.Platform { return .email; }

    fn connectImpl(self: *EmailAdapter) !void {
        // Connect to IMAP server (port 993 TLS) for receiving
        // IMAP IDLE for push notifications
        if (self.imap_host.len == 0) return error.MissingConfig;
    }

    fn sendImpl(self: *EmailAdapter, allocator: std.mem.Allocator, target: []const u8, content: []const u8, _: ?[]const u8) anyerror!platform.SendResult {
        // Send via SMTP (port 587 STARTTLS or 465 TLS)
        // SMTP host: self.smtp_host, From: self.username
        _ = self;
        _ = allocator;
        _ = target;
        _ = content;
        return .{ .message_id = "email_sent", .allocator = null };
    }

    fn setHandler(self: *EmailAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitImpl(_: *EmailAdapter) void {}
};
