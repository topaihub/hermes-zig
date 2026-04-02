const std = @import("std");
const platform = @import("../platform.zig");
const types = @import("../../../core/types.zig");

pub const ApiServerAdapter = struct {
    listen_port: u16 = 8080,
    handler: ?platform.MessageHandler = null,

    pub fn adapter(self: *ApiServerAdapter) platform.PlatformAdapter {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = platform.PlatformAdapter.VTable{
        .platform = @ptrCast(&getPlatform),
        .connect = @ptrCast(&connectImpl),
        .send = @ptrCast(&sendImpl),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitImpl),
    };

    fn getPlatform(_: *ApiServerAdapter) types.Platform { return .webhook; }

    fn connectImpl(self: *ApiServerAdapter) !void {
        // Start HTTP server on 0.0.0.0:{listen_port}
        // Endpoints: POST /v1/chat, GET /v1/health, POST /v1/chat/stream (SSE)
        if (self.listen_port == 0) return error.InvalidPort;
    }

    fn sendImpl(_: *ApiServerAdapter, allocator: std.mem.Allocator, _: []const u8, _: []const u8, _: ?[]const u8) anyerror!platform.SendResult {
        // Response written to pending HTTP response for the request
        _ = allocator;
        return .{ .message_id = "api_response", .allocator = null };
    }

    fn setHandler(self: *ApiServerAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitImpl(_: *ApiServerAdapter) void {}
};

test "ApiServerAdapter returns webhook platform" {
    var a = ApiServerAdapter{};
    const pa = a.adapter();
    try std.testing.expectEqual(types.Platform.webhook, pa.platform());
}
