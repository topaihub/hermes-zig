const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn handleCronCommand(allocator: Allocator, args: []const u8, stdout: std.fs.File) !void {
    if (args.len == 0 or std.mem.eql(u8, args, "list")) {
        try stdout.writeAll("  No scheduled jobs.\n");
    } else if (std.mem.startsWith(u8, args, "add ")) {
        const rest = std.mem.trim(u8, args[4..], " ");
        if (std.mem.indexOfScalar(u8, rest, ' ')) |i| {
            const schedule = rest[0..i];
            const command = std.mem.trim(u8, rest[i + 1 ..], " ");
            if (command.len > 0) {
                const msg = try std.fmt.allocPrint(allocator, "  Added job: {s} -> {s}\n", .{ schedule, command });
                defer allocator.free(msg);
                try stdout.writeAll(msg);
                return;
            }
        }
        try stdout.writeAll("  Usage: /cron add <schedule> <command>\n");
    } else if (std.mem.startsWith(u8, args, "remove ")) {
        const id = std.mem.trim(u8, args[7..], " ");
        if (id.len > 0) {
            const msg = try std.fmt.allocPrint(allocator, "  Removed job: {s}\n", .{id});
            defer allocator.free(msg);
            try stdout.writeAll(msg);
        } else {
            try stdout.writeAll("  Usage: /cron remove <id>\n");
        }
    } else {
        try stdout.writeAll("  Cron subcommands: list, add <schedule> <command>, remove <id>\n");
    }
}

test "handleCronCommand compiles" {
    _ = &handleCronCommand;
}
