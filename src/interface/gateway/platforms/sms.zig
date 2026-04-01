const std = @import("std");
const platform = @import("../platform.zig");
const types = @import("../../../core/types.zig");

pub const SmsAdapter = struct {
    account_sid: []const u8,
    auth_token: []const u8,
    from_number: []const u8,
    handler: ?platform.MessageHandler = null,

    pub fn adapter(self: *SmsAdapter) platform.PlatformAdapter {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = platform.PlatformAdapter.VTable{
        .platform = @ptrCast(&getPlatform),
        .connect = @ptrCast(&connectStub),
        .send = @ptrCast(&sendStub),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitStub),
    };

    fn getPlatform(_: *SmsAdapter) types.Platform { return .sms; }
    fn connectStub(_: *SmsAdapter) !void {}
    fn sendStub(_: *SmsAdapter, _: std.mem.Allocator, _: []const u8, _: []const u8, _: ?[]const u8) !platform.SendResult { return .{}; }
    fn setHandler(self: *SmsAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitStub(_: *SmsAdapter) void {}
};
