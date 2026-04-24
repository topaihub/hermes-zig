const std = @import("std");

const braille_frames = [_][]const u8{ "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" };

pub const Spinner = struct {
    frame: usize = 0,

    pub fn next(self: *Spinner) []const u8 {
        const f = braille_frames[self.frame % braille_frames.len];
        self.frame +%= 1;
        return f;
    }
};

pub fn formatToolCall(allocator: std.mem.Allocator, name: []const u8, keys: []const []const u8, vals: []const []const u8) ![]u8 {
    var buf = std.ArrayList(u8){};
    defer buf.deinit(allocator);
    const w = buf.writer(allocator);
    try w.print("⚡ {s}(", .{name});
    for (keys, 0..) |k, i| {
        if (i > 0) try w.writeAll(", ");
        try w.print("{s}={s}", .{ k, vals[i] });
    }
    try w.writeAll(")");
    return try buf.toOwnedSlice(allocator);
}

pub fn formatToolResult(allocator: std.mem.Allocator, result: []const u8, is_error: bool) ![]u8 {
    const prefix: []const u8 = if (is_error) "[error] " else "";
    const max = 500;
    const truncated = if (result.len > max) result[0..max] else result;
    return std.fmt.allocPrint(allocator, "{s}{s}", .{ prefix, truncated });
}

pub fn formatStreamDelta(stdout: std.Io.File, delta: []const u8) !void {
    try stdout.writeAll(delta);
}

test "formatToolCall format" {
    const allocator = std.testing.allocator;
    const result = try formatToolCall(allocator, "bash", &.{"cmd"}, &.{"ls"});
    defer allocator.free(result);
    try std.testing.expectEqualStrings("⚡ bash(cmd=ls)", result);
}
