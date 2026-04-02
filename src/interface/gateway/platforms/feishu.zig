const std = @import("std");
const platform = @import("../platform.zig");
const types = @import("../../../core/types.zig");

pub const FeishuAdapter = struct {
    app_id: []const u8,
    app_secret: []const u8,
    handler: ?platform.MessageHandler = null,

    pub fn adapter(self: *FeishuAdapter) platform.PlatformAdapter {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = platform.PlatformAdapter.VTable{
        .platform = @ptrCast(&getPlatform),
        .connect = @ptrCast(&connectImpl),
        .send = @ptrCast(&sendImpl),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitImpl),
    };

    fn getPlatform(_: *FeishuAdapter) types.Platform { return .feishu; }

    fn connectImpl(self: *FeishuAdapter) !void {
        // Feishu/Lark: POST https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal
        // Event subscription via webhook callback
        if (self.app_id.len == 0) return error.MissingConfig;
    }

    fn sendImpl(self: *FeishuAdapter, allocator: std.mem.Allocator, target: []const u8, content: []const u8, _: ?[]const u8) anyerror!platform.SendResult {
        // POST https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=chat_id
        // Body: {"receive_id":target,"msg_type":"text","content":"{\"text\":\"content\"}"}
        _ = self;
        _ = allocator;
        _ = target;
        _ = content;
        return .{ .message_id = "feishu_sent", .allocator = null };
    }

    fn setHandler(self: *FeishuAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitImpl(_: *FeishuAdapter) void {}
};
