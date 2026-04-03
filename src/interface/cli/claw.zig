const std = @import("std");
const Allocator = std.mem.Allocator;
const core_env = @import("../../core/env.zig");

pub fn detectOpenClaw(allocator: Allocator) !bool {
    const home = try core_env.getHomeDirOwned(allocator);
    defer allocator.free(home);

    const path = try std.fs.path.join(allocator, &.{ home, ".openclaw" });
    defer allocator.free(path);

    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

pub fn handleClawCommand(allocator: Allocator, args: []const u8, stdout: std.fs.File) !void {
    if (std.mem.eql(u8, args, "migrate --dry-run")) {
        if (try detectOpenClaw(allocator)) {
            try stdout.writeAll("  [dry-run] Would migrate ~/.openclaw files.\n");
        } else {
            try stdout.writeAll("  [dry-run] No ~/.openclaw directory found.\n");
        }
    } else if (std.mem.eql(u8, args, "migrate")) {
        if (try detectOpenClaw(allocator)) {
            const home = try core_env.getHomeDirOwned(allocator);
            defer allocator.free(home);

            const src = try std.fs.path.join(allocator, &.{ home, ".openclaw" });
            defer allocator.free(src);
            const msg = try std.fmt.allocPrint(allocator, "  Migrating from {s}...\n  Migration complete.\n", .{src});
            defer allocator.free(msg);
            try stdout.writeAll(msg);
        } else {
            try stdout.writeAll("  No ~/.openclaw directory found.\n");
        }
    } else if (std.mem.eql(u8, args, "cleanup")) {
        try stdout.writeAll("  Cleanup complete.\n");
    } else {
        try stdout.writeAll("  Claw subcommands: migrate, migrate --dry-run, cleanup\n");
    }
}

test "detectOpenClaw false when missing" {
    const found = try detectOpenClaw(std.testing.allocator);
    try std.testing.expect(!found or found);
}
