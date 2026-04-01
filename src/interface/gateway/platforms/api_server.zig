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
        .connect = @ptrCast(&connectStub),
        .send = @ptrCast(&sendStub),
        .setMessageHandler = @ptrCast(&setHandler),
        .deinit = @ptrCast(&deinitStub),
    };

    fn getPlatform(_: *ApiServerAdapter) types.Platform { return .webhook; }
    fn connectStub(_: *ApiServerAdapter) !void {}
    fn sendStub(_: *ApiServerAdapter, _: std.mem.Allocator, _: []const u8, _: []const u8, _: ?[]const u8) !platform.SendResult { return .{}; }
    fn setHandler(self: *ApiServerAdapter, h: platform.MessageHandler) void { self.handler = h; }
    fn deinitStub(_: *ApiServerAdapter) void {}
};

test "ApiServerAdapter returns webhook platform" {
    var a = ApiServerAdapter{};
    const pa = a.adapter();
    try std.testing.expectEqual(types.Platform.webhook, pa.platform());
}
