const std = @import("std");
const c = @cImport(@cInclude("sqlite3.h"));

/// SQLITE_TRANSIENT tells SQLite to make its own copy of the data.
/// Defined manually to avoid @cImport pointer cast issues on some platforms.
const SQLITE_TRANSIENT: c.sqlite3_destructor_type = @ptrFromInt(@as(usize, @bitCast(@as(isize, -1))));

pub const Error = error{SqliteError};

pub const Statement = struct {
    stmt: *c.sqlite3_stmt,

    pub fn bindText(self: Statement, col: c_int, text: []const u8) Error!void {
        if (c.sqlite3_bind_text(self.stmt, col, text.ptr, @intCast(text.len), SQLITE_TRANSIENT) != c.SQLITE_OK)
            return error.SqliteError;
    }

    pub fn bindInt(self: Statement, col: c_int, val: i64) Error!void {
        if (c.sqlite3_bind_int64(self.stmt, col, val) != c.SQLITE_OK)
            return error.SqliteError;
    }

    pub fn bindFloat(self: Statement, col: c_int, val: f64) Error!void {
        if (c.sqlite3_bind_double(self.stmt, col, val) != c.SQLITE_OK)
            return error.SqliteError;
    }

    pub fn step(self: Statement) Error!bool {
        const rc = c.sqlite3_step(self.stmt);
        if (rc == c.SQLITE_ROW) return true;
        if (rc == c.SQLITE_DONE) return false;
        return error.SqliteError;
    }

    pub fn columnText(self: Statement, col: c_int) ?[]const u8 {
        const ptr = c.sqlite3_column_text(self.stmt, col);
        if (ptr == null) return null;
        const len: usize = @intCast(c.sqlite3_column_bytes(self.stmt, col));
        return ptr[0..len];
    }

    pub fn columnInt(self: Statement, col: c_int) i64 {
        return c.sqlite3_column_int64(self.stmt, col);
    }

    pub fn reset(self: Statement) Error!void {
        if (c.sqlite3_reset(self.stmt) != c.SQLITE_OK)
            return error.SqliteError;
    }

    pub fn finalize(self: Statement) void {
        _ = c.sqlite3_finalize(self.stmt);
    }
};

pub const Database = struct {
    db: *c.sqlite3,

    pub fn open(path: [*:0]const u8) Error!Database {
        var db: ?*c.sqlite3 = null;
        if (c.sqlite3_open(path, &db) != c.SQLITE_OK) return error.SqliteError;
        return .{ .db = db.? };
    }

    pub fn exec(self: Database, sql: [*:0]const u8) Error!void {
        if (c.sqlite3_exec(self.db, sql, null, null, null) != c.SQLITE_OK)
            return error.SqliteError;
    }

    pub fn prepare(self: Database, sql: [*:0]const u8) Error!Statement {
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.db, sql, -1, &stmt, null) != c.SQLITE_OK)
            return error.SqliteError;
        return .{ .stmt = stmt.? };
    }

    pub fn close(self: Database) void {
        _ = c.sqlite3_close(self.db);
    }
};

test "open and close in-memory database" {
    const db = try Database.open(":memory:");
    defer db.close();
    try db.exec("SELECT 1");
}
