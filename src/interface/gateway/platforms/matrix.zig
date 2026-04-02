const std = @import("std");
const platform = @import("../platform.zig");
const types = @import("../../../core/types.zig");

pub const MatrixAdapter = struct {
    homeserver: []const u8,
    access_token: []const u8,
    handler: ?platform.MessageHandler = null,

    pub fn adapter(self: *MatrixAdapter) platform.PlatformAdapter {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = platform.PlatformAdapter.VTable{
        .platform = @ptrCast(&getPlatform),
        .connect = @ptrCast(&connectImpl),
        .send = @ptrCast(&sendImpl),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitImpl),
    };

    fn getPlatform(_: *MatrixAdapter) types.Platform { return .matrix; }

    fn connectImpl(self: *MatrixAdapter) !void {
        // Matrix Client-Server API: GET {homeserver}/_matrix/client/v3/sync (long poll)
        // Auth: Authorization: Bearer {access_token}
        if (self.homeserver.len == 0) return error.MissingConfig;
    }

    fn sendImpl(self: *MatrixAdapter, allocator: std.mem.Allocator, target: []const u8, content: []const u8, _: ?[]const u8) anyerror!platform.SendResult {
        // PUT {homeserver}/_matrix/client/v3/rooms/{roomId}/send/m.room.message/{txnId}
        // Body: {"msgtype":"m.text","body":content}
        _ = self;
        _ = allocator;
        _ = target;
        _ = content;
        return .{ .message_id = "matrix_sent", .allocator = null };
    }

    fn setHandler(self: *MatrixAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitImpl(_: *MatrixAdapter) void {}
};
