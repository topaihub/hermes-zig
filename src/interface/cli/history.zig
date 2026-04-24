const std = @import("std");

pub const History = struct {
    entries: std.ArrayList([]const u8),
    pos: usize = 0,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) History {
        return .{ .entries = std.ArrayList([]const u8).initCapacity(allocator, 0) catch .empty, .allocator = allocator };
    }

    pub fn deinit(self: *History) void {
        for (self.entries.items) |e| self.allocator.free(e);
        self.entries.deinit(self.allocator);
    }

    pub fn add(self: *History, line: []const u8) !void {
        const owned = try self.allocator.dupe(u8, line);
        try self.entries.append(self.allocator, owned);
        self.pos = self.entries.items.len;
    }

    /// Navigate up (older). Returns entry or null if at beginning.
    pub fn up(self: *History) ?[]const u8 {
        if (self.entries.items.len == 0) return null;
        if (self.pos > 0) self.pos -= 1;
        return self.entries.items[self.pos];
    }

    /// Navigate down (newer). Returns entry or null if past end.
    pub fn down(self: *History) ?[]const u8 {
        if (self.pos >= self.entries.items.len) return null;
        self.pos += 1;
        if (self.pos >= self.entries.items.len) return null;
        return self.entries.items[self.pos];
    }

    /// Save history to file.
    pub fn save(self: *const History, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        const writer = file.writer();
        for (self.entries.items) |entry| {
            try writer.writeAll(entry);
            try writer.writeByte('\n');
        }
    }

    /// Load history from file.
    pub fn load(self: *History, path: []const u8) !void {
        const file = std.fs.cwd().openFile(path, .{}) catch return;
        defer file.close();
        var buf_reader = std.io.bufferedReader(file.reader());
        var reader = buf_reader.reader();
        var line_buf: [4096]u8 = undefined;
        while (reader.readUntilDelimiter(&line_buf, '\n')) |line| {
            if (line.len > 0) try self.add(line);
        } else |_| {}
    }
};

test "history add and navigate" {
    var h = History.init(std.testing.allocator);
    defer h.deinit();

    try h.add("first");
    try h.add("second");
    try h.add("third");

    // Navigate up
    try std.testing.expectEqualStrings("third", h.up().?);
    try std.testing.expectEqualStrings("second", h.up().?);
    try std.testing.expectEqualStrings("first", h.up().?);
    // At beginning, stays at first
    try std.testing.expectEqualStrings("first", h.up().?);

    // Navigate down
    try std.testing.expectEqualStrings("second", h.down().?);
    try std.testing.expectEqualStrings("third", h.down().?);
    // Past end
    try std.testing.expectEqual(null, h.down());
}

test "empty history returns null" {
    var h = History.init(std.testing.allocator);
    defer h.deinit();
    try std.testing.expectEqual(null, h.up());
    try std.testing.expectEqual(null, h.down());
}
