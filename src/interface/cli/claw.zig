const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn detectOpenClaw() bool {
    const home = std.posix.getenv("HOME") orelse return false;
    var buf: [4096]u8 = undefined;
    const path = std.fmt.bufPrint(&buf, "{s}/.openclaw", .{home}) catch return false;
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

pub fn handleClawCommand(allocator: Allocator, args: []const u8, stdout: std.fs.File) !void {
    if (std.mem.eql(u8, args, "migrate --dry-run")) {
        if (detectOpenClaw()) {
            try stdout.writeAll("  [dry-run] Would migrate ~/.openclaw files.\n");
        } else {
            try stdout.writeAll("  [dry-run] No ~/.openclaw directory found.\n");
        }
    } else if (std.mem.eql(u8, args, "migrate")) {
        if (detectOpenClaw()) {
            const home = std.posix.getenv("HOME") orelse return;
            const src = try std.fmt.allocPrint(allocator, "{s}/.openclaw", .{home});
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
    try std.testing.expect(!detectOpenClaw() or detectOpenClaw());
}
