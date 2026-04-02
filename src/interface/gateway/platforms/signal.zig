const std = @import("std");
const platform = @import("../platform.zig");
const types = @import("../../../core/types.zig");

pub const SignalAdapter = struct {
    account: []const u8,
    http_url: []const u8,
    handler: ?platform.MessageHandler = null,

    pub fn adapter(self: *SignalAdapter) platform.PlatformAdapter {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = platform.PlatformAdapter.VTable{
        .platform = @ptrCast(&getPlatform),
        .connect = @ptrCast(&connectImpl),
        .send = @ptrCast(&sendImpl),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitImpl),
    };

    fn getPlatform(_: *SignalAdapter) types.Platform { return .signal; }

    fn connectImpl(self: *SignalAdapter) !void {
        // signal-cli REST API: GET {http_url}/v1/receive/{account}
        if (self.http_url.len == 0) return error.MissingConfig;
    }

    fn sendImpl(self: *SignalAdapter, allocator: std.mem.Allocator, target: []const u8, content: []const u8, _: ?[]const u8) anyerror!platform.SendResult {
        // POST {http_url}/v2/send  Body: {"message":content,"number":account,"recipients":[target]}
        _ = self;
        _ = allocator;
        _ = target;
        _ = content;
        return .{ .message_id = "signal_sent", .allocator = null };
    }

    fn setHandler(self: *SignalAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitImpl(_: *SignalAdapter) void {}
};
