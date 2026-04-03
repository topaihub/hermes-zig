const std = @import("std");
const env = @import("env.zig");

pub fn getHermesHome(allocator: std.mem.Allocator) ![]u8 {
    if (try env.getEnvVarOwned(allocator, "HERMES_HOME")) |home| {
        return home;
    }
    const home_dir = try env.getHomeDirOwned(allocator);
    defer allocator.free(home_dir);
    return try std.fs.path.join(allocator, &.{ home_dir, ".hermes" });
}

test "getHermesHome returns non-empty path" {
    const path = try getHermesHome(std.testing.allocator);
    defer std.testing.allocator.free(path);
    try std.testing.expect(path.len > 0);
}
