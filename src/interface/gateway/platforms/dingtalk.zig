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
        .connect = @ptrCast(&connectStub),
        .send = @ptrCast(&sendStub),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitStub),
    };

    fn getPlatform(_: *DingtalkAdapter) types.Platform { return .dingtalk; }
    fn connectStub(_: *DingtalkAdapter) !void {}
    fn sendStub(_: *DingtalkAdapter, _: std.mem.Allocator, _: []const u8, _: []const u8, _: ?[]const u8) !platform.SendResult { return .{}; }
    fn setHandler(self: *DingtalkAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitStub(_: *DingtalkAdapter) void {}
};
