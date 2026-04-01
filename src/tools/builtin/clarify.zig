const std = @import("std");
const tools_interface = @import("../interface.zig");

pub const ClarifyTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "clarify",
        .description = "Ask the user a clarifying question",
        .parameters_schema =
            \\{"type":"object","properties":{"question":{"type":"string","description":"Question to ask the user"}},"required":["question"]}
        ,
    };

    pub fn execute(self: *ClarifyTool, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        _ = self;
        const parsed = std.json.parseFromSlice(struct { question: []const u8 }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();
        return std.fmt.allocPrint(ctx.allocator, "[CLARIFY] {s}", .{parsed.value.question});
    }
};

test "ClarifyTool schema" {
    var tool = ClarifyTool{};
    const handler = tools_interface.makeToolHandler(ClarifyTool, &tool);
    try std.testing.expectEqualStrings("clarify", handler.schema.name);
}
