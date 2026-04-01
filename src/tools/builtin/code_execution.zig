const std = @import("std");
const tools_interface = @import("../interface.zig");
const tools_terminal = @import("../terminal/backend.zig");

pub const CodeExecutionTool = struct {
    backend: *tools_terminal.TerminalBackend,

    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "code_execution",
        .description = "Execute code via terminal backend",
        .parameters_schema =
            \\{"type":"object","properties":{"language":{"type":"string","description":"python or javascript"},"code":{"type":"string","description":"Code to execute"}},"required":["language","code"]}
        ,
    };

    pub fn execute(self: *CodeExecutionTool, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        const Args = struct { language: []const u8, code: []const u8 };
        const parsed = std.json.parseFromSlice(Args, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();

        const interpreter: []const u8 = if (std.mem.eql(u8, parsed.value.language, "python"))
            "python3"
        else if (std.mem.eql(u8, parsed.value.language, "javascript"))
            "node"
        else
            return std.fmt.allocPrint(ctx.allocator, "Unsupported language: {s}", .{parsed.value.language});

        const flag: []const u8 = if (std.mem.eql(u8, interpreter, "python3")) "-c" else "-e";
        const cmd = try std.fmt.allocPrint(ctx.allocator, "{s} {s} '{s}'", .{ interpreter, flag, parsed.value.code });
        defer ctx.allocator.free(cmd);

        var result = try self.backend.execute(ctx.allocator, cmd, ctx.working_dir, 30000);
        defer result.deinit();

        if (result.isSuccess()) return ctx.allocator.dupe(u8, result.stdout);
        return ctx.allocator.dupe(u8, result.stderr);
    }
};

test "CodeExecutionTool schema" {
    var backend = tools_terminal.TerminalBackend{ .local = .{} };
    var tool = CodeExecutionTool{ .backend = &backend };
    const handler = tools_interface.makeToolHandler(CodeExecutionTool, &tool);
    try std.testing.expectEqualStrings("code_execution", handler.schema.name);
}
