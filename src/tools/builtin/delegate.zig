const std = @import("std");
const tools_interface = @import("../interface.zig");
const ToolResult = tools_interface.ToolResult;

pub const DelegateTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "delegate_task",
        .description = "Delegate a task to a subagent",
        .parameters_schema =
            \\{"type":"object","properties":{"task":{"type":"string","description":"Task description for the subagent"}},"required":["task"]}
        ,
    };

    pub fn execute(self: *DelegateTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const task = tools_interface.getString(args, "task") orelse return .{ .output = "missing task", .is_error = true };
        return .{ .output = try std.fmt.allocPrint(allocator, "Delegation: would spawn subagent for task: {s}", .{task}) };
    }
};

test "DelegateTool schema" {
    var tool = DelegateTool{};
    const handler = tools_interface.makeToolHandler(DelegateTool, &tool);
    try std.testing.expectEqualStrings("delegate_task", handler.schema.name);
}
