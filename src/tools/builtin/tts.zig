const std = @import("std");
const tools_interface = @import("../interface.zig");
const ToolResult = tools_interface.ToolResult;

pub const TtsTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "text_to_speech",
        .description = "Convert text to speech audio via OpenAI TTS API",
        .parameters_schema =
            \\{"type":"object","properties":{"text":{"type":"string","description":"Text to convert to speech"},"voice":{"type":"string","description":"Voice: alloy, echo, fable, onyx, nova, shimmer"}},"required":["text"]}
        ,
    };

    pub fn execute(self: *TtsTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const text = tools_interface.getString(args, "text") orelse return .{ .output = "missing text", .is_error = true };
        const voice = tools_interface.getString(args, "voice") orelse "alloy";
        return .{ .output = try std.fmt.allocPrint(allocator,
            \\[TTS] API endpoint: POST https://api.openai.com/v1/audio/speech
            \\  Text: {s}
            \\  Voice: {s}
            \\  Model: tts-1
            \\Requires text and OPENAI_API_KEY env var.
        , .{ text, voice }) };
    }
};

test "TtsTool schema" {
    var tool = TtsTool{};
    const handler = tools_interface.makeToolHandler(TtsTool, &tool);
    try std.testing.expectEqualStrings("text_to_speech", handler.schema.name);
}
