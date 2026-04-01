const std = @import("std");
const tools_interface = @import("../interface.zig");

pub const VoiceModeTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "voice_mode",
        .description = "Start or stop voice interaction mode",
        .parameters_schema =
            \\{"type":"object","properties":{"action":{"type":"string","enum":["start","stop"],"description":"Voice mode action"}},"required":["action"]}
        ,
    };

    pub fn execute(self: *VoiceModeTool, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        _ = self;
        const parsed = std.json.parseFromSlice(struct { action: []const u8 = "" }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();
        return std.fmt.allocPrint(ctx.allocator, "Voice mode requires audio I/O. Action: {s}", .{parsed.value.action});
    }
};

test "VoiceModeTool schema" {
    var tool = VoiceModeTool{};
    const handler = tools_interface.makeToolHandler(VoiceModeTool, &tool);
    try std.testing.expectEqualStrings("voice_mode", handler.schema.name);
}
