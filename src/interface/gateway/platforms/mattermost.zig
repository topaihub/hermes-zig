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
        .connect = @ptrCast(&connectStub),
        .send = @ptrCast(&sendStub),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitStub),
    };

    fn getPlatform(_: *MattermostAdapter) types.Platform { return .mattermost; }
    fn connectStub(_: *MattermostAdapter) !void {}
    fn sendStub(_: *MattermostAdapter, _: std.mem.Allocator, _: []const u8, _: []const u8, _: ?[]const u8) !platform.SendResult { return .{}; }
    fn setHandler(self: *MattermostAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitStub(_: *MattermostAdapter) void {}
};
