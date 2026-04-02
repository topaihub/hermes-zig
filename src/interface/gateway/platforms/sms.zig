const std = @import("std");
const platform = @import("../platform.zig");
const types = @import("../../../core/types.zig");

pub const SmsAdapter = struct {
    account_sid: []const u8,
    auth_token: []const u8,
    from_number: []const u8,
    handler: ?platform.MessageHandler = null,

    pub fn adapter(self: *SmsAdapter) platform.PlatformAdapter {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = platform.PlatformAdapter.VTable{
        .platform = @ptrCast(&getPlatform),
        .connect = @ptrCast(&connectImpl),
        .send = @ptrCast(&sendImpl),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitImpl),
    };

    fn getPlatform(_: *SmsAdapter) types.Platform { return .sms; }

    fn connectImpl(self: *SmsAdapter) !void {
        // Twilio: webhook callback for incoming SMS
        // Configure webhook URL at https://console.twilio.com
        if (self.account_sid.len == 0) return error.MissingConfig;
    }

    fn sendImpl(self: *SmsAdapter, allocator: std.mem.Allocator, target: []const u8, content: []const u8, _: ?[]const u8) anyerror!platform.SendResult {
        // POST https://api.twilio.com/2010-04-01/Accounts/{account_sid}/Messages.json
        // Auth: Basic base64({account_sid}:{auth_token})
        // Body: From={from_number}&To={target}&Body={content}
        _ = self;
        _ = allocator;
        _ = target;
        _ = content;
        return .{ .message_id = "sms_sent", .allocator = null };
    }

    fn setHandler(self: *SmsAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitImpl(_: *SmsAdapter) void {}
};
