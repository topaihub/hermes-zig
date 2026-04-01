const std = @import("std");

pub const MaskedKey = struct {
    provider: []const u8,
    masked: []const u8,
};

pub const AuthManager = struct {
    pub fn addKey(provider: []const u8, key: []const u8) !void {
        _ = provider;
        _ = key;
    }

    pub fn removeKey(provider: []const u8) !void {
        _ = provider;
    }

    pub fn listKeys() ![]MaskedKey {
        return &.{};
    }

    /// Make a test API call to verify the key works.
    pub fn testKey(provider: []const u8, key: []const u8) !bool {
        _ = provider;
        _ = key;
        return false; // stub
    }
};

test "AuthManager listKeys returns empty" {
    const keys = try AuthManager.listKeys();
    try std.testing.expectEqual(@as(usize, 0), keys.len);
}

test "AuthManager testKey stub returns false" {
    const ok = try AuthManager.testKey("openai", "sk-test");
    try std.testing.expectEqual(false, ok);
}
