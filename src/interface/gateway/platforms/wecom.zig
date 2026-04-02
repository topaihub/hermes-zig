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
        .connect = @ptrCast(&connectImpl),
        .send = @ptrCast(&sendImpl),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitImpl),
    };

    fn getPlatform(_: *WecomAdapter) types.Platform { return .wecom; }

    fn connectImpl(self: *WecomAdapter) !void {
        // WeCom: GET https://qyapi.weixin.qq.com/cgi-bin/gettoken?corpid={id}&corpsecret={secret}
        // Callback URL verification for events
        if (self.bot_id.len == 0) return error.MissingConfig;
    }

    fn sendImpl(self: *WecomAdapter, allocator: std.mem.Allocator, target: []const u8, content: []const u8, _: ?[]const u8) anyerror!platform.SendResult {
        // POST https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token={token}
        // Body: {"touser":target,"msgtype":"text","agentid":bot_id,"text":{"content":content}}
        _ = self;
        _ = allocator;
        _ = target;
        _ = content;
        return .{ .message_id = "wecom_sent", .allocator = null };
    }

    fn setHandler(self: *WecomAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitImpl(_: *WecomAdapter) void {}
};
