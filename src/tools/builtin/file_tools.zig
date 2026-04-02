const std = @import("std");
const tools_interface = @import("../interface.zig");
const terminal = @import("../terminal/backend.zig");
const ToolResult = tools_interface.ToolResult;

pub const FileTools = struct {
    backend: *terminal.TerminalBackend,

    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "search_files",
        .description = "File operations: ls, find, grep, tree",
        .parameters_schema =
            \\{"type":"object","properties":{"operation":{"type":"string","enum":["ls","find","grep","tree"]},"path":{"type":"string"},"pattern":{"type":"string"}},"required":["operation","path"]}
        ,
    };

    pub fn execute(self: *FileTools, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        const op = tools_interface.getString(args, "operation") orelse return .{ .output = "missing operation", .is_error = true };
        const p = tools_interface.getString(args, "path") orelse return .{ .output = "missing path", .is_error = true };
        const pat = tools_interface.getString(args, "pattern") orelse "";

        const cmd = blk: {
            if (std.mem.eql(u8, op, "ls")) break :blk try std.fmt.allocPrint(allocator, "ls -la {s}", .{p});
            if (std.mem.eql(u8, op, "find")) break :blk try std.fmt.allocPrint(allocator, "find {s} -name '{s}'", .{ p, pat });
            if (std.mem.eql(u8, op, "grep")) break :blk try std.fmt.allocPrint(allocator, "grep -rn '{s}' {s}", .{ pat, p });
            if (std.mem.eql(u8, op, "tree")) break :blk try std.fmt.allocPrint(allocator, "find {s} -print | head -100", .{p});
            break :blk try std.fmt.allocPrint(allocator, "echo 'Unknown operation: {s}'", .{op});
        };
        defer allocator.free(cmd);

        var result = try self.backend.execute(allocator, cmd, ".", 15000);
        defer result.deinit();
        return .{ .output = try allocator.dupe(u8, if (result.isSuccess()) result.stdout else result.stderr) };
    }
};

test "FileTools schema" {
    var backend = terminal.TerminalBackend{ .local = .{} };
    var tool = FileTools{ .backend = &backend };
    const handler = tools_interface.makeToolHandler(FileTools, &tool);
    try std.testing.expectEqualStrings("search_files", handler.schema.name);
}
