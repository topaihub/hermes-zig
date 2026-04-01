const std = @import("std");
const sqlite = @import("sqlite.zig");

pub fn initFts(db: sqlite.Database) !void {
    try db.exec("CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(session_id, role, content)");
}

pub const SearchResult = struct {
    session_id: []const u8,
    role: []const u8,
    content: []const u8,
};

pub fn searchMessages(db: sqlite.Database, allocator: std.mem.Allocator, query: []const u8) ![]SearchResult {
    const stmt = try db.prepare("SELECT session_id, role, content FROM messages_fts WHERE messages_fts MATCH ?1");
    defer stmt.finalize();
    try stmt.bindText(1, query);

    var results: std.ArrayList(SearchResult) = .{};
    errdefer {
        for (results.items) |r| {
            allocator.free(r.session_id);
            allocator.free(r.role);
            allocator.free(r.content);
        }
        results.deinit(allocator);
    }

    while (try stmt.step()) {
        try results.append(allocator, .{
            .session_id = try allocator.dupe(u8, stmt.columnText(0) orelse ""),
            .role = try allocator.dupe(u8, stmt.columnText(1) orelse ""),
            .content = try allocator.dupe(u8, stmt.columnText(2) orelse ""),
        });
    }
    return results.toOwnedSlice(allocator);
}

pub fn freeResults(allocator: std.mem.Allocator, results: []SearchResult) void {
    for (results) |r| {
        allocator.free(r.session_id);
        allocator.free(r.role);
        allocator.free(r.content);
    }
    allocator.free(results);
}

test "FTS5 search" {
    const db = try sqlite.Database.open(":memory:");
    defer db.close();
    try initFts(db);

    try db.exec("INSERT INTO messages_fts (session_id, role, content) VALUES ('s1', 'user', 'hello world')");
    try db.exec("INSERT INTO messages_fts (session_id, role, content) VALUES ('s1', 'assistant', 'goodbye')");

    const results = try searchMessages(db, std.testing.allocator, "hello");
    defer freeResults(std.testing.allocator, results);
    try std.testing.expectEqual(@as(usize, 1), results.len);
    try std.testing.expectEqualStrings("hello world", results[0].content);
}
