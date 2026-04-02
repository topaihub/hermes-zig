const std = @import("std");
const tools_interface = @import("../interface.zig");
const ToolResult = tools_interface.ToolResult;

pub const TtsTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "text_to_speech",
        .description = "Convert text to speech audio",
        .parameters_schema =
            \\{"type":"object","properties":{"text":{"type":"string","description":"Text to convert to speech"},"voice":{"type":"string","description":"Voice to use"}},"required":["text","voice"]}
        ,
    };

    pub fn execute(self: *TtsTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const text = tools_interface.getString(args, "text") orelse return .{ .output = "missing text", .is_error = true };
        const voice = tools_interface.getString(args, "voice") orelse "default";
        return .{ .output = try std.fmt.allocPrint(allocator, "[text_to_speech] Args: text={s}, voice={s}. Requires TTS_API configuration.", .{ text, voice }) };
    }
};

test "TtsTool schema" {
    var tool = TtsTool{};
    const handler = tools_interface.makeToolHandler(TtsTool, &tool);
    try std.testing.expectEqualStrings("text_to_speech", handler.schema.name);
}
