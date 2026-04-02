const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn handleUninstall(allocator: Allocator, stdout: std.fs.File) !void {
    _ = allocator;
    try stdout.writeAll("  ⚠ This will remove ~/.hermes/ and all data.\n");
    try stdout.writeAll("  To confirm, re-run with --yes flag.\n");
}

test "handleUninstall compiles" {
    _ = &handleUninstall;
}
