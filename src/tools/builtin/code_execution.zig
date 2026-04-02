const std = @import("std");
const tools_interface = @import("../interface.zig");
const tools_terminal = @import("../terminal/backend.zig");
const ToolResult = tools_interface.ToolResult;

pub const CodeExecutionTool = struct {
    backend: *tools_terminal.TerminalBackend,

    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "execute_code",
        .description = "Execute code via terminal backend",
        .parameters_schema =
            \\{"type":"object","properties":{"language":{"type":"string","description":"python or javascript"},"code":{"type":"string","description":"Code to execute"}},"required":["language","code"]}
        ,
    };

    pub fn execute(self: *CodeExecutionTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        const language = tools_interface.getString(args, "language") orelse return .{ .output = "missing language", .is_error = true };
        const code = tools_interface.getString(args, "code") orelse return .{ .output = "missing code", .is_error = true };

        const interpreter: []const u8 = if (std.mem.eql(u8, language, "python"))
            "python3"
        else if (std.mem.eql(u8, language, "javascript"))
            "node"
        else
            return .{ .output = try std.fmt.allocPrint(allocator, "Unsupported language: {s}", .{language}) };

        const flag: []const u8 = if (std.mem.eql(u8, interpreter, "python3")) "-c" else "-e";
        const cmd = try std.fmt.allocPrint(allocator, "{s} {s} '{s}'", .{ interpreter, flag, code });
        defer allocator.free(cmd);

        var result = try self.backend.execute(allocator, cmd, ".", 30000);
        defer result.deinit();

        return .{ .output = try allocator.dupe(u8, if (result.isSuccess()) result.stdout else result.stderr) };
    }
};

test "CodeExecutionTool schema" {
    var backend = tools_terminal.TerminalBackend{ .local = .{} };
    var tool = CodeExecutionTool{ .backend = &backend };
    const handler = tools_interface.makeToolHandler(CodeExecutionTool, &tool);
    try std.testing.expectEqualStrings("execute_code", handler.schema.name);
}
