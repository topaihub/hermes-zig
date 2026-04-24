const std = @import("std");
const interface = @import("../llm/interface.zig");

pub const CliStreamCallback = struct {
    stdout: std.Io.File,

    pub fn init() CliStreamCallback {
        return .{ .stdout = std.Io.File.stdout() };
    }

    pub fn asStreamCallback(self: *CliStreamCallback) interface.StreamCallback {
        return .{
            .ctx = @ptrCast(self),
            .on_delta = &onDelta,
        };
    }

    fn onDelta(ctx: *anyopaque, content: []const u8, done: bool) void {
        const self: *CliStreamCallback = @ptrCast(@alignCast(ctx));
        self.stdout.writeAll(content) catch {};
        if (done) self.stdout.writeAll("\n") catch {};
    }
};

test "CliStreamCallback initializes" {
    var cb = CliStreamCallback.init();
    const sc = cb.asStreamCallback();
    try std.testing.expect(sc.ctx != undefined);
    try std.testing.expect(sc.on_delta != undefined);
}
