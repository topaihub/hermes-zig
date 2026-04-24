const std = @import("std");

pub const CredentialPool = struct {
    keys: []const []const u8,
    index: usize = 0,
    cooldowns: std.StringHashMap(i64),

    pub fn init(allocator: std.mem.Allocator, keys: []const []const u8) CredentialPool {
        return .{
            .keys = keys,
            .cooldowns = std.StringHashMap(i64).init(allocator),
        };
    }

    pub fn deinit(self: *CredentialPool) void {
        self.cooldowns.deinit();
    }

    pub fn getNext(self: *CredentialPool) ?[]const u8 {
        if (self.keys.len == 0) return null;
        const time_utils = @import("../core/time_utils.zig");
        const now = time_utils.getCurrentTimestamp();
        var attempts: usize = 0;
        while (attempts < self.keys.len) : (attempts += 1) {
            const key = self.keys[self.index];
            self.index = (self.index + 1) % self.keys.len;
            if (self.cooldowns.get(key)) |until| {
                if (now < until) continue;
            }
            return key;
        }
        return null; // all keys on cooldown
    }

    pub fn cooldown(self: *CredentialPool, key: []const u8, seconds: i64) !void {
        const time_utils = @import("../core/time_utils.zig");
        try self.cooldowns.put(key, time_utils.getCurrentTimestamp() + seconds);
    }

    pub fn reset(self: *CredentialPool, key: []const u8) void {
        _ = self.cooldowns.remove(key);
    }
};

test "CredentialPool round-robin rotation" {
    const keys = &[_][]const u8{ "key-a", "key-b", "key-c" };
    var pool = CredentialPool.init(std.testing.allocator, keys);
    defer pool.deinit();

    try std.testing.expectEqualStrings("key-a", pool.getNext().?);
    try std.testing.expectEqualStrings("key-b", pool.getNext().?);
    try std.testing.expectEqualStrings("key-c", pool.getNext().?);
    try std.testing.expectEqualStrings("key-a", pool.getNext().?);
}

test "CredentialPool cooldown skips key" {
    const keys = &[_][]const u8{ "key-a", "key-b" };
    var pool = CredentialPool.init(std.testing.allocator, keys);
    defer pool.deinit();

    try pool.cooldown("key-a", 9999);
    try std.testing.expectEqualStrings("key-b", pool.getNext().?);
    try std.testing.expectEqualStrings("key-b", pool.getNext().?);

    pool.reset("key-a");
    // After reset, index is at 0 again from wrapping, key-a is available
    try std.testing.expectEqualStrings("key-a", pool.getNext().?);
}

test "CredentialPool empty returns null" {
    var pool = CredentialPool.init(std.testing.allocator, &.{});
    defer pool.deinit();
    try std.testing.expectEqual(null, pool.getNext());
}
