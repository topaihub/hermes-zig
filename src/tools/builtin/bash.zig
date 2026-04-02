const std = @import("std");
const tools_interface = @import("../interface.zig");
const terminal = @import("../terminal/backend.zig");
const ToolResult = tools_interface.ToolResult;

pub const BashTool = struct {
    backend: *terminal.TerminalBackend,

    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "terminal",
        .description = "Execute a shell command",
        .parameters_schema =
            \\{"type":"object","properties":{"command":{"type":"string","description":"Shell command to execute"}},"required":["command"]}
        ,
    };

    pub fn execute(self: *BashTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        const command = tools_interface.getString(args, "command") orelse return .{ .output = "missing command", .is_error = true };

        var result = try self.backend.execute(allocator, command, ".", 30000);
        defer result.deinit();

        return .{ .output = try allocator.dupe(u8, if (result.isSuccess()) result.stdout else result.stderr) };
    }
};

test "BashTool schema" {
    var backend = terminal.TerminalBackend{ .local = .{} };
    var tool = BashTool{ .backend = &backend };
    const handler = tools_interface.makeToolHandler(BashTool, &tool);
    try std.testing.expectEqualStrings("terminal", handler.schema.name);
}

test "BashTool execute echo" {
    var backend = terminal.TerminalBackend{ .local = .{} };
    var tool = BashTool{ .backend = &backend };
    const handler = tools_interface.makeToolHandler(BashTool, &tool);

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, "{\"command\":\"echo test\"}", .{});
    defer parsed.deinit();
    const result = try handler.execute(std.testing.allocator, parsed.value.object);
    defer std.testing.allocator.free(result.output);
    try std.testing.expect(std.mem.indexOf(u8, result.output, "test") != null);
}
