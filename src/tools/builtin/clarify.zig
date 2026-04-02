const std = @import("std");
const tools_interface = @import("../interface.zig");
const ToolResult = tools_interface.ToolResult;

pub const ClarifyTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "clarify",
        .description = "Ask the user a clarifying question",
        .parameters_schema =
            \\{"type":"object","properties":{"question":{"type":"string","description":"Question to ask the user"}},"required":["question"]}
        ,
    };

    pub fn execute(self: *ClarifyTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const question = tools_interface.getString(args, "question") orelse return .{ .output = "missing question", .is_error = true };
        return .{ .output = try std.fmt.allocPrint(allocator, "[CLARIFY] {s}", .{question}) };
    }
};

test "ClarifyTool schema" {
    var tool = ClarifyTool{};
    const handler = tools_interface.makeToolHandler(ClarifyTool, &tool);
    try std.testing.expectEqualStrings("clarify", handler.schema.name);
}
