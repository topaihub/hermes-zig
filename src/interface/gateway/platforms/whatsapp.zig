const std = @import("std");
const platform = @import("../platform.zig");
const types = @import("../../../core/types.zig");

pub const WhatsAppAdapter = struct {
    phone_number_id: []const u8,
    access_token: []const u8,
    handler: ?platform.MessageHandler = null,

    pub fn adapter(self: *WhatsAppAdapter) platform.PlatformAdapter {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = platform.PlatformAdapter.VTable{
        .platform = @ptrCast(&getPlatform),
        .connect = @ptrCast(&connectImpl),
        .send = @ptrCast(&sendImpl),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitImpl),
    };

    fn getPlatform(_: *WhatsAppAdapter) types.Platform { return .whatsapp; }

    fn connectImpl(self: *WhatsAppAdapter) !void {
        // WhatsApp Cloud API: webhook verification via GET with hub.verify_token
        // Receive messages via POST webhook at configured endpoint
        if (self.access_token.len == 0) return error.MissingToken;
    }

    fn sendImpl(self: *WhatsAppAdapter, allocator: std.mem.Allocator, target: []const u8, content: []const u8, _: ?[]const u8) anyerror!platform.SendResult {
        // POST https://graph.facebook.com/v18.0/{phone_number_id}/messages
        // Header: Authorization: Bearer {access_token}
        // Body: {"messaging_product":"whatsapp","to":target,"type":"text","text":{"body":content}}
        _ = self;
        _ = allocator;
        _ = target;
        _ = content;
        return .{ .message_id = "wa_msg_sent", .allocator = null };
    }

    fn setHandler(self: *WhatsAppAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitImpl(_: *WhatsAppAdapter) void {}
};
