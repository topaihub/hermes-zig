const std = @import("std");
const posix = std.posix;

/// ANSI escape helpers
pub const ansi = struct {
    pub const reset = "\x1b[0m";
    pub const bold = "\x1b[1m";
    pub const dim = "\x1b[2m";
    pub const red = "\x1b[31m";
    pub const green = "\x1b[32m";
    pub const yellow = "\x1b[33m";
    pub const blue = "\x1b[34m";
    pub const cyan = "\x1b[36m";

    pub fn clearLine(writer: anytype) !void {
        try writer.writeAll("\x1b[2K\r");
    }

    pub fn moveCursor(writer: anytype, row: u16, col: u16) !void {
        try writer.print("\x1b[{d};{d}H", .{ row, col });
    }

    pub fn color(writer: anytype, code: []const u8, text: []const u8) !void {
        try writer.print("{s}{s}{s}", .{ code, text, reset });
    }
};

/// Raw terminal mode — disables canonical mode and echo.
pub const RawMode = struct {
    original: posix.termios,
    fd: posix.fd_t,

    pub fn enable(fd: posix.fd_t) !RawMode {
        const original = try posix.tcgetattr(fd);
        var raw = original;
        raw.lflag = raw.lflag.fromInt(raw.lflag.toInt() & ~@as(u32, posix.tc_lflag.ICANON | posix.tc_lflag.ECHO));
        raw.cc[@intFromEnum(posix.V.MIN)] = 0;
        raw.cc[@intFromEnum(posix.V.TIME)] = 1;
        try posix.tcsetattr(fd, .FLUSH, raw);
        return .{ .original = original, .fd = fd };
    }

    pub fn disable(self: RawMode) void {
        posix.tcsetattr(self.fd, .FLUSH, self.original) catch {};
    }
};

/// Reads bytes from stdin with a timeout via raw mode settings.
pub const InputReader = struct {
    fd: posix.fd_t,

    pub fn init() InputReader {
        return .{ .fd = std.io.getStdIn().handle };
    }

    /// Read available bytes. Returns slice of buf actually read, or empty on timeout.
    pub fn read(self: InputReader, buf: []u8) ![]u8 {
        const n = posix.read(self.fd, buf) catch |err| switch (err) {
            error.WouldBlock => return buf[0..0],
            else => return err,
        };
        return buf[0..n];
    }
};

/// Render the prompt to the given writer.
pub fn renderPrompt(writer: anytype) !void {
    try writer.print("{s}{s}hermes> {s}", .{ ansi.bold, ansi.cyan, ansi.reset });
}

test "ansi.clearLine writes escape sequence" {
    var buf: [32]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try ansi.clearLine(fbs.writer());
    try std.testing.expectEqualStrings("\x1b[2K\r", fbs.getWritten());
}

test "renderPrompt contains hermes>" {
    var buf: [64]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try renderPrompt(fbs.writer());
    try std.testing.expect(std.mem.indexOf(u8, fbs.getWritten(), "hermes> ") != null);
}
