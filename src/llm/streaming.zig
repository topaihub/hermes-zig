const std = @import("std");

/// Parse a single SSE line. Returns the data payload, or null for non-data/done lines.
pub fn parseSseLine(line: []const u8) ?[]const u8 {
    const trimmed = std.mem.trimEnd(u8, line, "\r\n");
    if (!std.mem.startsWith(u8, trimmed, "data: ")) return null;
    const payload = trimmed["data: ".len..];
    if (std.mem.eql(u8, payload, "[DONE]")) return null;
    return payload;
}

pub const SseParser = struct {
    buffer: std.ArrayList(u8) = .empty,
    alloc: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) SseParser {
        return .{ .alloc = allocator };
    }

    pub fn deinit(self: *SseParser) void {
        self.buffer.deinit(self.alloc);
    }

    /// Feed raw bytes, returns a list of complete data payloads.
    pub fn feed(self: *SseParser, bytes: []const u8, allocator: std.mem.Allocator) ![][]const u8 {
        try self.buffer.appendSlice(self.alloc, bytes);
        var results: std.ArrayList([]const u8) = .empty;

        while (true) {
            const buf = self.buffer.items;
            const nl = std.mem.indexOf(u8, buf, "\n") orelse break;
            const line = buf[0..nl];
            if (parseSseLine(line)) |payload| {
                try results.append(allocator, try allocator.dupe(u8, payload));
            }
            // Remove consumed line including newline
            const rest = buf[nl + 1 ..];
            std.mem.copyForwards(u8, self.buffer.items[0..rest.len], rest);
            self.buffer.shrinkRetainingCapacity(rest.len);
        }

        return results.toOwnedSlice(allocator);
    }
};

test "parseSseLine extracts data" {
    try std.testing.expectEqualStrings("{\"a\":1}", parseSseLine("data: {\"a\":1}").?);
    try std.testing.expectEqual(null, parseSseLine("data: [DONE]"));
    try std.testing.expectEqual(null, parseSseLine(": comment"));
    try std.testing.expectEqual(null, parseSseLine(""));
    try std.testing.expectEqualStrings("{\"b\":2}", parseSseLine("data: {\"b\":2}\r\n").?);
}

test "SseParser feeds partial lines" {
    var parser = SseParser.init(std.testing.allocator);
    defer parser.deinit();

    const r1 = try parser.feed("data: hel", std.testing.allocator);
    defer std.testing.allocator.free(r1);
    try std.testing.expectEqual(@as(usize, 0), r1.len);

    const r2 = try parser.feed("lo\ndata: [DONE]\n", std.testing.allocator);
    defer {
        for (r2) |s| std.testing.allocator.free(s);
        std.testing.allocator.free(r2);
    }
    try std.testing.expectEqual(@as(usize, 1), r2.len);
    try std.testing.expectEqualStrings("hello", r2[0]);
}
