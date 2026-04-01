const std = @import("std");

pub const StatusBar = struct {
    model: []const u8 = "",
    token_count: u32 = 0,
    session_id: []const u8 = "",

    pub fn render(self: *const StatusBar, writer: anytype) !void {
        try writer.print(" [{s}] tokens:{d} session:{s}", .{
            if (self.model.len > 0) self.model else "none",
            self.token_count,
            if (self.session_id.len > 0) self.session_id else "-",
        });
    }
};

test "StatusBar render" {
    var buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const bar = StatusBar{ .model = "gpt-4", .token_count = 150, .session_id = "s1" };
    try bar.render(fbs.writer());
    const output = fbs.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, output, "gpt-4") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "150") != null);
}

test "StatusBar render defaults" {
    var buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const bar = StatusBar{};
    try bar.render(fbs.writer());
    const output = fbs.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, output, "none") != null);
}
