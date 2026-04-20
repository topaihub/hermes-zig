const std = @import("std");

pub const SessionState = struct {
    id: []const u8,
    cwd: []const u8,
    created_at: i64,
};

pub const SessionManager = struct {
    sessions: std.StringHashMap(SessionState),

    pub fn init(allocator: std.mem.Allocator) SessionManager {
        return .{ .sessions = std.StringHashMap(SessionState).init(allocator) };
    }

    pub fn deinit(self: *SessionManager) void {
        self.sessions.deinit();
    }

    pub fn createSession(self: *SessionManager, allocator: std.mem.Allocator, cwd: []const u8) !SessionState {
        var id_buf: [16]u8 = undefined;
        std.crypto.random.bytes(&id_buf);
        const hex = std.fmt.bytesToHex(id_buf, .lower);
        const id = try allocator.dupe(u8, &hex);
        const cwd_owned = try allocator.dupe(u8, cwd);
        const state = SessionState{ .id = id, .cwd = cwd_owned, .created_at = std.time.timestamp() };
        try self.sessions.put(id, state);
        return state;
    }

    pub fn getSession(self: *SessionManager, id: []const u8) ?SessionState {
        return self.sessions.get(id);
    }

    pub fn deleteSession(self: *SessionManager, id: []const u8) void {
        _ = self.sessions.remove(id);
    }
};

test "session lifecycle" {
    const allocator = std.testing.allocator;
    var mgr = SessionManager.init(allocator);
    defer mgr.deinit();

    const session = try mgr.createSession(allocator, "/tmp");
    defer allocator.free(session.id);
    defer allocator.free(session.cwd);

    try std.testing.expectEqualStrings("/tmp", session.cwd);
    try std.testing.expect(session.id.len == 32);
    try std.testing.expect(session.created_at > 0);

    const found = mgr.getSession(session.id);
    try std.testing.expect(found != null);

    mgr.deleteSession(session.id);
    try std.testing.expect(mgr.getSession(session.id) == null);
}
