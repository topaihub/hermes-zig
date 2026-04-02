const std = @import("std");
const platform = @import("../platform.zig");
const types = @import("../../../core/types.zig");

pub const HomeAssistantAdapter = struct {
    ha_url: []const u8,
    token: []const u8,
    handler: ?platform.MessageHandler = null,

    pub fn adapter(self: *HomeAssistantAdapter) platform.PlatformAdapter {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = platform.PlatformAdapter.VTable{
        .platform = @ptrCast(&getPlatform),
        .connect = @ptrCast(&connectImpl),
        .send = @ptrCast(&sendImpl),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitImpl),
    };

    fn getPlatform(_: *HomeAssistantAdapter) types.Platform { return .homeassistant; }

    fn connectImpl(self: *HomeAssistantAdapter) !void {
        // Home Assistant WebSocket API: ws://{ha_url}/api/websocket
        // Auth message: {"type":"auth","access_token":token}
        if (self.ha_url.len == 0) return error.MissingConfig;
    }

    fn sendImpl(self: *HomeAssistantAdapter, allocator: std.mem.Allocator, target: []const u8, content: []const u8, _: ?[]const u8) anyerror!platform.SendResult {
        // POST {ha_url}/api/services/notify/{target}
        // Header: Authorization: Bearer {token}
        // Body: {"message":content}
        _ = self;
        _ = allocator;
        _ = target;
        _ = content;
        return .{ .message_id = "ha_sent", .allocator = null };
    }

    fn setHandler(self: *HomeAssistantAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitImpl(_: *HomeAssistantAdapter) void {}
};
