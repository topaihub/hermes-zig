const std = @import("std");
const tools_interface = @import("../interface.zig");
const ToolResult = tools_interface.ToolResult;

pub const CheckpointTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "checkpoint",
        .description = "Create, list, rollback, or diff checkpoints",
        .parameters_schema =
            \\{"type":"object","properties":{"action":{"type":"string","enum":["create","list","rollback","diff"],"description":"Checkpoint action"},"id":{"type":"string","description":"Checkpoint ID"}},"required":["action"]}
        ,
    };

    pub fn execute(self: *CheckpointTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const action = tools_interface.getString(args, "action") orelse return .{ .output = "missing action", .is_error = true };
        const id = tools_interface.getString(args, "id") orelse "";
        return .{ .output = try std.fmt.allocPrint(allocator, "Checkpoint stub: action={s} id={s}", .{ action, id }) };
    }
};

test "CheckpointTool schema" {
    var tool = CheckpointTool{};
    const handler = tools_interface.makeToolHandler(CheckpointTool, &tool);
    try std.testing.expectEqualStrings("checkpoint", handler.schema.name);
}
