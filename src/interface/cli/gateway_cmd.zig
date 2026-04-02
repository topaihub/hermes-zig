const std = @import("std");

pub const GatewayCmd = struct {
    pub fn start(writer: anytype) !void {
        try writer.writeAll("Gateway starting...\n");
    }

    pub fn stop(writer: anytype) !void {
        try writer.writeAll("Gateway stopped.\n");
    }

    pub fn status(writer: anytype) !void {
        try writer.writeAll("Gateway: not running\n");
    }
};

test "struct init" {
    _ = GatewayCmd{};
}

test "status writes output" {
    var buf: [64]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try GatewayCmd.status(fbs.writer());
    try std.testing.expect(fbs.getWritten().len > 0);
}
