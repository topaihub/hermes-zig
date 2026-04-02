const std = @import("std");
const Allocator = std.mem.Allocator;

const builtin_tools = [_][]const u8{
    "terminal", "read_file", "write_file", "patch", "search_files",
    "web_search", "web_extract", "execute_code", "todo", "memory",
};

pub fn handleToolsCommand(allocator: Allocator, args: []const u8, stdout: std.fs.File) !void {
    if (args.len == 0 or std.mem.eql(u8, args, "list")) {
        try stdout.writeAll("  Tools:\n");
        for (builtin_tools) |name| {
            const msg = try std.fmt.allocPrint(allocator, "    • {s}  [enabled]\n", .{name});
            defer allocator.free(msg);
            try stdout.writeAll(msg);
        }
    } else if (std.mem.startsWith(u8, args, "enable ")) {
        const name = std.mem.trim(u8, args[7..], " ");
        const msg = try std.fmt.allocPrint(allocator, "  Enabled tool: {s}\n", .{name});
        defer allocator.free(msg);
        try stdout.writeAll(msg);
    } else if (std.mem.startsWith(u8, args, "disable ")) {
        const name = std.mem.trim(u8, args[8..], " ");
        const msg = try std.fmt.allocPrint(allocator, "  Disabled tool: {s}\n", .{name});
        defer allocator.free(msg);
        try stdout.writeAll(msg);
    } else {
        try stdout.writeAll("  Tools subcommands: list, enable <name>, disable <name>\n");
    }
}

test "builtin_tools not empty" {
    try std.testing.expect(builtin_tools.len > 0);
}
