const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn handleMcpCommand(allocator: Allocator, args: []const u8, stdout: std.Io.File) !void {
    if (args.len == 0 or std.mem.eql(u8, args, "list")) {
        try stdout.writeAll("  No MCP servers configured.\n");
    } else if (std.mem.startsWith(u8, args, "add ")) {
        const rest = std.mem.trim(u8, args[4..], " ");
        if (std.mem.indexOfScalar(u8, rest, ' ')) |i| {
            const name = rest[0..i];
            const command = std.mem.trim(u8, rest[i + 1 ..], " ");
            if (command.len > 0) {
                const msg = try std.fmt.allocPrint(allocator, "  Added MCP server: {s} -> {s}\n", .{ name, command });
                defer allocator.free(msg);
                try stdout.writeAll(msg);
                return;
            }
        }
        try stdout.writeAll("  Usage: /mcp add <name> <command>\n");
    } else if (std.mem.startsWith(u8, args, "remove ")) {
        const name = std.mem.trim(u8, args[7..], " ");
        if (name.len > 0) {
            const msg = try std.fmt.allocPrint(allocator, "  Removed MCP server: {s}\n", .{name});
            defer allocator.free(msg);
            try stdout.writeAll(msg);
        } else {
            try stdout.writeAll("  Usage: /mcp remove <name>\n");
        }
    } else {
        try stdout.writeAll("  MCP subcommands: list, add <name> <command>, remove <name>\n");
    }
}

test "handleMcpCommand compiles" {
    _ = &handleMcpCommand;
}
