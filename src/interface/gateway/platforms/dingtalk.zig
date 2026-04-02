const std = @import("std");
const platform = @import("../platform.zig");
const types = @import("../../../core/types.zig");

pub const DingtalkAdapter = struct {
    client_id: []const u8,
    client_secret: []const u8,
    handler: ?platform.MessageHandler = null,

    pub fn adapter(self: *DingtalkAdapter) platform.PlatformAdapter {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = platform.PlatformAdapter.VTable{
        .platform = @ptrCast(&getPlatform),
        .connect = @ptrCast(&connectImpl),
        .send = @ptrCast(&sendImpl),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitImpl),
    };

    fn getPlatform(_: *DingtalkAdapter) types.Platform { return .dingtalk; }

    fn connectImpl(self: *DingtalkAdapter) !void {
        // DingTalk: POST https://api.dingtalk.com/v1.0/oauth2/accessToken
        // Stream mode or HTTP callback for events
        if (self.client_id.len == 0) return error.MissingConfig;
    }

    fn sendImpl(self: *DingtalkAdapter, allocator: std.mem.Allocator, target: []const u8, content: []const u8, _: ?[]const u8) anyerror!platform.SendResult {
        // POST https://api.dingtalk.com/v1.0/robot/oToMessages/batchSend
        // Body: {"robotCode":client_id,"userIds":[target],"msgKey":"sampleText","msgParam":"{\"content\":\"...\"}"}
        _ = self;
        _ = allocator;
        _ = target;
        _ = content;
        return .{ .message_id = "dingtalk_sent", .allocator = null };
    }

    fn setHandler(self: *DingtalkAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitImpl(_: *DingtalkAdapter) void {}
};
