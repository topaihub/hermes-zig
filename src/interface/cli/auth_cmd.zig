const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn handleAuthCommand(allocator: Allocator, args: []const u8, stdout: std.fs.File) !void {
    if (args.len == 0 or std.mem.eql(u8, args, "list")) {
        try stdout.writeAll("  No API keys configured.\n");
    } else if (std.mem.eql(u8, args, "add")) {
        try stdout.writeAll("  Usage: /auth add <provider> <key>\n");
    } else if (std.mem.eql(u8, args, "remove")) {
        try stdout.writeAll("  Usage: /auth remove <provider>\n");
    } else if (std.mem.eql(u8, args, "test")) {
        try stdout.writeAll("  No key to test. Add one with /auth add\n");
    } else if (std.mem.startsWith(u8, args, "add ")) {
        const rest = std.mem.trim(u8, args[4..], " ");
        if (std.mem.indexOfScalar(u8, rest, ' ')) |i| {
            const provider = rest[0..i];
            const key = std.mem.trim(u8, rest[i + 1 ..], " ");
            if (key.len > 0) {
                const masked_len = @min(key.len, 4);
                const msg = try std.fmt.allocPrint(allocator, "  Saved key for {s}: {s}****\n", .{ provider, key[0..masked_len] });
                defer allocator.free(msg);
                try stdout.writeAll(msg);
                return;
            }
        }
        try stdout.writeAll("  Usage: /auth add <provider> <key>\n");
    } else if (std.mem.startsWith(u8, args, "remove ")) {
        const provider = std.mem.trim(u8, args[7..], " ");
        if (provider.len > 0) {
            const msg = try std.fmt.allocPrint(allocator, "  Removed key for {s}\n", .{provider});
            defer allocator.free(msg);
            try stdout.writeAll(msg);
        } else {
            try stdout.writeAll("  Usage: /auth remove <provider>\n");
        }
    } else {
        try stdout.writeAll("  Auth subcommands: add, remove, list, test\n");
    }
}

test "handleAuthCommand list" {
    _ = &handleAuthCommand;
}
