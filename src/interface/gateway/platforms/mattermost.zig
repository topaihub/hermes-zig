const std = @import("std");
const platform = @import("../platform.zig");
const types = @import("../../../core/types.zig");

pub const MattermostAdapter = struct {
    server_url: []const u8,
    bot_token: []const u8,
    handler: ?platform.MessageHandler = null,

    pub fn adapter(self: *MattermostAdapter) platform.PlatformAdapter {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = platform.PlatformAdapter.VTable{
        .platform = @ptrCast(&getPlatform),
        .connect = @ptrCast(&connectImpl),
        .send = @ptrCast(&sendImpl),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitImpl),
    };

    fn getPlatform(_: *MattermostAdapter) types.Platform { return .mattermost; }

    fn connectImpl(self: *MattermostAdapter) !void {
        // Mattermost WebSocket: wss://{server_url}/api/v4/websocket
        // Auth: Authorization: Bearer {bot_token}
        if (self.server_url.len == 0) return error.MissingConfig;
    }

    fn sendImpl(self: *MattermostAdapter, allocator: std.mem.Allocator, target: []const u8, content: []const u8, _: ?[]const u8) anyerror!platform.SendResult {
        // POST {server_url}/api/v4/posts
        // Header: Authorization: Bearer {bot_token}
        // Body: {"channel_id":target,"message":content}
        _ = self;
        _ = allocator;
        _ = target;
        _ = content;
        return .{ .message_id = "mm_sent", .allocator = null };
    }

    fn setHandler(self: *MattermostAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitImpl(_: *MattermostAdapter) void {}
};
