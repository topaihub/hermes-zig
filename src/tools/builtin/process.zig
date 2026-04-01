const std = @import("std");
const tools_interface = @import("../interface.zig");

pub const ProcessTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "process",
        .description = "Manage background processes and sessions",
        .parameters_schema =
            \\{"type":"object","properties":{"action":{"type":"string","enum":["list","poll","log","kill"],"description":"Process action"},"session_id":{"type":"string","description":"Session ID to act on"}},"required":["action"]}
        ,
    };

    pub fn execute(self: *ProcessTool, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        _ = self;
        const parsed = std.json.parseFromSlice(struct { action: []const u8 = "", session_id: []const u8 = "" }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();
        return std.fmt.allocPrint(ctx.allocator, "Process management stub: action={s} session_id={s}", .{ parsed.value.action, parsed.value.session_id });
    }
};

test "ProcessTool schema" {
    var tool = ProcessTool{};
    const handler = tools_interface.makeToolHandler(ProcessTool, &tool);
    try std.testing.expectEqualStrings("process", handler.schema.name);
}
