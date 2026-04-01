const std = @import("std");
const ansi = @import("tui.zig").ansi;

/// Incrementally renders text deltas to the terminal.
pub const StreamDisplay = struct {
    writer: std.io.AnyWriter,

    pub fn init(writer: std.io.AnyWriter) StreamDisplay {
        return .{ .writer = writer };
    }

    pub fn writeDelta(self: *StreamDisplay, delta: []const u8) !void {
        try self.writer.writeAll(delta);
    }

    pub fn finish(self: *StreamDisplay) !void {
        try self.writer.writeAll("\n");
    }
};

pub fn renderToolCall(writer: anytype, name: []const u8, args: []const u8) !void {
    try writer.print("{s}{s}⚡ {s}{s}({s})\n", .{ ansi.dim, ansi.yellow, name, ansi.reset, args });
}

pub fn renderToolResult(writer: anytype, result: []const u8) !void {
    try writer.print("{s}  → {s}{s}\n", .{ ansi.dim, result, ansi.reset });
}

const spinner_frames = [_][]const u8{ "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" };

pub fn renderSpinner(writer: anytype, frame: usize) !void {
    try ansi.clearLine(writer);
    try writer.print("{s}{s} thinking...{s}", .{ ansi.cyan, spinner_frames[frame % spinner_frames.len], ansi.reset });
}

test "StreamDisplay writes delta" {
    var buf: [128]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    var display = StreamDisplay.init(fbs.writer().any());
    try display.writeDelta("hello ");
    try display.writeDelta("world");
    try display.finish();
    try std.testing.expectEqualStrings("hello world\n", fbs.getWritten());
}

test "renderToolCall formats correctly" {
    var buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try renderToolCall(fbs.writer(), "bash", "ls -la");
    const out = fbs.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, out, "bash") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "ls -la") != null);
}
