const std = @import("std");
const tools_interface = @import("../interface.zig");
const terminal = @import("../terminal/backend.zig");

pub const BashTool = struct {
    backend: *terminal.TerminalBackend,

    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "bash",
        .description = "Execute a shell command",
        .parameters_schema =
            \\{"type":"object","properties":{"command":{"type":"string","description":"Shell command to execute"}},"required":["command"]}
        ,
    };

    pub fn execute(self: *BashTool, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        const parsed = std.json.parseFromSlice(struct { command: []const u8 }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();

        var result = try self.backend.execute(ctx.allocator, parsed.value.command, ctx.working_dir, 30000);
        defer result.deinit();

        if (result.isSuccess()) {
            return ctx.allocator.dupe(u8, result.stdout);
        }
        return ctx.allocator.dupe(u8, result.stderr);
    }
};

test "BashTool schema" {
    var backend = terminal.TerminalBackend{ .local = .{} };
    var tool = BashTool{ .backend = &backend };
    const handler = tools_interface.makeToolHandler(BashTool, &tool);
    try std.testing.expectEqualStrings("bash", handler.schema.name);
}

test "BashTool execute echo" {
    var backend = terminal.TerminalBackend{ .local = .{} };
    var tool = BashTool{ .backend = &backend };
    const handler = tools_interface.makeToolHandler(BashTool, &tool);
    const ctx = tools_interface.ToolContext{
        .session_source = .{ .platform = .cli, .chat_id = "test" },
        .allocator = std.testing.allocator,
    };
    const result = try handler.execute("{\"command\":\"echo test\"}", &ctx);
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "test") != null);
}
