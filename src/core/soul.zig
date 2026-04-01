const std = @import("std");

pub fn getHermesHome() []const u8 {
    return std.posix.getenv("HERMES_HOME") orelse "~/.hermes";
}

pub fn loadSoul(allocator: std.mem.Allocator, hermes_home: []const u8) !?[]u8 {
    const path = try std.fs.path.join(allocator, &.{ hermes_home, "SOUL.md" });
    defer allocator.free(path);
    return std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => null,
        else => err,
    };
}
