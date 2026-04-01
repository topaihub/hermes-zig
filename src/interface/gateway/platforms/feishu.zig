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
        .connect = @ptrCast(&connectStub),
        .send = @ptrCast(&sendStub),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitStub),
    };

    fn getPlatform(_: *FeishuAdapter) types.Platform { return .feishu; }
    fn connectStub(_: *FeishuAdapter) !void {}
    fn sendStub(_: *FeishuAdapter, _: std.mem.Allocator, _: []const u8, _: []const u8, _: ?[]const u8) !platform.SendResult { return .{}; }
    fn setHandler(self: *FeishuAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitStub(_: *FeishuAdapter) void {}
};
