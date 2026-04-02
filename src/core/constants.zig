const std = @import("std");

pub fn getHermesHome(allocator: std.mem.Allocator) ![]u8 {
    if (std.posix.getenv("HERMES_HOME")) |home| {
        return try allocator.dupe(u8, home);
    }
    const home_dir = std.posix.getenv("HOME") orelse "/tmp";
    return try std.fs.path.join(allocator, &.{ home_dir, ".hermes" });
}

test "getHermesHome returns non-empty path" {
    const path = try getHermesHome(std.testing.allocator);
    defer std.testing.allocator.free(path);
    try std.testing.expect(path.len > 0);
}
