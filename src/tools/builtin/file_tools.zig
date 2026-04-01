const std = @import("std");
const tools_interface = @import("../interface.zig");
const terminal = @import("../terminal/backend.zig");

pub const FileTools = struct {
    backend: *terminal.TerminalBackend,

    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "file_tools",
        .description = "File operations: ls, find, grep, tree",
        .parameters_schema =
            \\{"type":"object","properties":{"operation":{"type":"string","enum":["ls","find","grep","tree"]},"path":{"type":"string"},"pattern":{"type":"string"}},"required":["operation","path"]}
        ,
    };

    pub fn execute(self: *FileTools, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        const Args = struct { operation: []const u8, path: []const u8, pattern: ?[]const u8 = null };
        const parsed = std.json.parseFromSlice(Args, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();

        const cmd = blk: {
            const op = parsed.value.operation;
            const p = parsed.value.path;
            const pat = parsed.value.pattern orelse "";
            if (std.mem.eql(u8, op, "ls")) break :blk try std.fmt.allocPrint(ctx.allocator, "ls -la {s}", .{p});
            if (std.mem.eql(u8, op, "find")) break :blk try std.fmt.allocPrint(ctx.allocator, "find {s} -name '{s}'", .{ p, pat });
            if (std.mem.eql(u8, op, "grep")) break :blk try std.fmt.allocPrint(ctx.allocator, "grep -rn '{s}' {s}", .{ pat, p });
            if (std.mem.eql(u8, op, "tree")) break :blk try std.fmt.allocPrint(ctx.allocator, "find {s} -print | head -100", .{p});
            break :blk try std.fmt.allocPrint(ctx.allocator, "echo 'Unknown operation: {s}'", .{op});
        };
        defer ctx.allocator.free(cmd);

        var result = try self.backend.execute(ctx.allocator, cmd, ctx.working_dir, 15000);
        defer result.deinit();
        return ctx.allocator.dupe(u8, if (result.isSuccess()) result.stdout else result.stderr);
    }
};

test "FileTools schema" {
    var backend = terminal.TerminalBackend{ .local = .{} };
    var tool = FileTools{ .backend = &backend };
    const handler = tools_interface.makeToolHandler(FileTools, &tool);
    try std.testing.expectEqualStrings("file_tools", handler.schema.name);
}
