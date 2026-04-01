const std = @import("std");
const tools_interface = @import("../interface.zig");

pub const DelegateTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "delegate",
        .description = "Delegate a task to a subagent",
        .parameters_schema =
            \\{"type":"object","properties":{"task":{"type":"string","description":"Task description for the subagent"}},"required":["task"]}
        ,
    };

    pub fn execute(self: *DelegateTool, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        _ = self;
        const parsed = std.json.parseFromSlice(struct { task: []const u8 }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();
        return std.fmt.allocPrint(ctx.allocator, "[DELEGATE stub] Task queued: {s}", .{parsed.value.task});
    }
};

test "DelegateTool schema" {
    var tool = DelegateTool{};
    const handler = tools_interface.makeToolHandler(DelegateTool, &tool);
    try std.testing.expectEqualStrings("delegate", handler.schema.name);
}
