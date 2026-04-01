const std = @import("std");
const tools_interface = @import("../interface.zig");

pub const CheckpointTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "checkpoint",
        .description = "Create, list, rollback, or diff checkpoints",
        .parameters_schema =
            \\{"type":"object","properties":{"action":{"type":"string","enum":["create","list","rollback","diff"],"description":"Checkpoint action"},"id":{"type":"string","description":"Checkpoint ID"}},"required":["action"]}
        ,
    };

    pub fn execute(self: *CheckpointTool, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        _ = self;
        const parsed = std.json.parseFromSlice(struct { action: []const u8 = "", id: []const u8 = "" }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();
        return std.fmt.allocPrint(ctx.allocator, "Checkpoint stub: action={s} id={s}", .{ parsed.value.action, parsed.value.id });
    }
};

test "CheckpointTool schema" {
    var tool = CheckpointTool{};
    const handler = tools_interface.makeToolHandler(CheckpointTool, &tool);
    try std.testing.expectEqualStrings("checkpoint", handler.schema.name);
}
