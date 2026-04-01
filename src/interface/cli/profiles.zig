const std = @import("std");

pub const ProfileManager = struct {
    pub fn create(name: []const u8) !void {
        _ = name;
    }

    pub fn switchTo(name: []const u8) !void {
        _ = name;
    }

    pub fn list() ![][]const u8 {
        return &.{};
    }

    pub fn delete(name: []const u8) !void {
        _ = name;
    }
};

test "ProfileManager list returns empty" {
    const profiles = try ProfileManager.list();
    try std.testing.expectEqual(@as(usize, 0), profiles.len);
}
