const sqlite = @import("sqlite.zig");

pub fn initSchema(db: sqlite.Database) !void {
    try db.exec("PRAGMA journal_mode=WAL");
    try db.exec(
        \\CREATE TABLE IF NOT EXISTS sessions (
        \\  id TEXT PRIMARY KEY,
        \\  source TEXT NOT NULL,
        \\  model TEXT NOT NULL,
        \\  created_at TEXT DEFAULT (datetime('now'))
        \\)
    );
    try db.exec(
        \\CREATE TABLE IF NOT EXISTS messages (
        \\  id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\  session_id TEXT NOT NULL REFERENCES sessions(id),
        \\  role TEXT NOT NULL,
        \\  content TEXT NOT NULL,
        \\  created_at TEXT DEFAULT (datetime('now'))
        \\)
    );
}

pub fn createSession(db: sqlite.Database, id: []const u8, source: []const u8, model: []const u8) !void {
    const stmt = try db.prepare("INSERT INTO sessions (id, source, model) VALUES (?1, ?2, ?3)");
    defer stmt.finalize();
    try stmt.bindText(1, id);
    try stmt.bindText(2, source);
    try stmt.bindText(3, model);
    _ = try stmt.step();
}

pub fn appendMessage(db: sqlite.Database, session_id: []const u8, role: []const u8, content: []const u8) !void {
    const stmt = try db.prepare("INSERT INTO messages (session_id, role, content) VALUES (?1, ?2, ?3)");
    defer stmt.finalize();
    try stmt.bindText(1, session_id);
    try stmt.bindText(2, role);
    try stmt.bindText(3, content);
    _ = try stmt.step();
}

pub fn appendToolMessage(db: sqlite.Database, session_id: []const u8, content: []const u8, tool_call_id: []const u8, tool_name: []const u8) !void {
    const stmt = try db.prepare("INSERT INTO messages (session_id, role, content) VALUES (?1, 'tool', ?2)");
    defer stmt.finalize();
    try stmt.bindText(1, session_id);
    
    // Format: tool_name(tool_call_id): content
    var buf: [4096]u8 = undefined;
    const formatted = try std.fmt.bufPrint(&buf, "{s}({s}): {s}", .{ tool_name, tool_call_id, content });
    try stmt.bindText(2, formatted);
    
    _ = try stmt.step();
}

pub fn getMessageCount(db: sqlite.Database, session_id: []const u8) !i64 {
    const stmt = try db.prepare("SELECT COUNT(*) FROM messages WHERE session_id = ?1");
    defer stmt.finalize();
    try stmt.bindText(1, session_id);
    if (try stmt.step()) return stmt.columnInt(0);
    return 0;
}

const std = @import("std");

test "schema and CRUD" {
    const db = try sqlite.Database.open(":memory:");
    defer db.close();
    try initSchema(db);
    try createSession(db, "s1", "cli", "gpt-4");
    try appendMessage(db, "s1", "user", "hello");
    try appendMessage(db, "s1", "assistant", "hi");
    try std.testing.expectEqual(@as(i64, 2), try getMessageCount(db, "s1"));
}

test "appendToolMessage" {
    const db = try sqlite.Database.open(":memory:");
    defer db.close();
    try initSchema(db);
    try createSession(db, "s2", "cli", "gpt-4");
    try appendMessage(db, "s2", "user", "search for cats");
    try appendToolMessage(db, "s2", "Found 10 results", "call_123", "web_search");
    try std.testing.expectEqual(@as(i64, 2), try getMessageCount(db, "s2"));
}
