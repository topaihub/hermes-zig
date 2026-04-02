const std = @import("std");

pub const AuditEntry = struct {
    timestamp: i64,
    tool_name: []const u8,
    approved: bool,
};

pub const AuditTrail = struct {
    entries: std.ArrayListUnmanaged(AuditEntry) = .empty,

    pub fn log(self: *AuditTrail, allocator: std.mem.Allocator, entry: AuditEntry) !void {
        try self.entries.append(allocator, entry);
    }

    pub fn recent(self: *const AuditTrail, limit: usize) []const AuditEntry {
        const items = self.entries.items;
        if (items.len <= limit) return items;
        return items[items.len - limit ..];
    }

    pub fn deinit(self: *AuditTrail, allocator: std.mem.Allocator) void {
        self.entries.deinit(allocator);
    }
};

test "AuditTrail log and recent" {
    const allocator = std.testing.allocator;
    var trail = AuditTrail{};
    defer trail.deinit(allocator);

    try trail.log(allocator, .{ .timestamp = 1, .tool_name = "shell", .approved = true });
    try trail.log(allocator, .{ .timestamp = 2, .tool_name = "read", .approved = false });

    try std.testing.expectEqual(@as(usize, 2), trail.entries.items.len);
    const last = trail.recent(1);
    try std.testing.expectEqual(@as(usize, 1), last.len);
    try std.testing.expectEqualStrings("read", last[0].tool_name);
}
