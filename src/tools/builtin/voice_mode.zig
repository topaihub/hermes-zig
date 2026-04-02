const std = @import("std");
const tools_interface = @import("../interface.zig");
const ToolResult = tools_interface.ToolResult;

pub const VoiceModeTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "voice_mode",
        .description = "Start or stop voice interaction mode",
        .parameters_schema =
            \\{"type":"object","properties":{"action":{"type":"string","enum":["start","stop"],"description":"Voice mode action"}},"required":["action"]}
        ,
    };

    pub fn execute(self: *VoiceModeTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const action = tools_interface.getString(args, "action") orelse return .{ .output = "missing action", .is_error = true };
        return .{ .output = try std.fmt.allocPrint(allocator, "Voice mode requires audio I/O. Action: {s}", .{action}) };
    }
};

test "VoiceModeTool schema" {
    var tool = VoiceModeTool{};
    const handler = tools_interface.makeToolHandler(VoiceModeTool, &tool);
    try std.testing.expectEqualStrings("voice_mode", handler.schema.name);
}
