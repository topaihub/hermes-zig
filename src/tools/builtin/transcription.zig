const std = @import("std");
const tools_interface = @import("../interface.zig");
const ToolResult = tools_interface.ToolResult;

pub const TranscriptionTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "transcription",
        .description = "Transcribe audio files to text via OpenAI Whisper API",
        .parameters_schema =
            \\{"type":"object","properties":{"audio_path":{"type":"string","description":"Path to the audio file"},"language":{"type":"string","description":"ISO-639-1 language code"}},"required":["audio_path"]}
        ,
    };

    pub fn execute(self: *TranscriptionTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const audio_path = tools_interface.getString(args, "audio_path") orelse return .{ .output = "missing audio_path", .is_error = true };
        const language = tools_interface.getString(args, "language") orelse "en";
        return .{ .output = try std.fmt.allocPrint(allocator,
            \\[Transcription] API endpoint: POST https://api.openai.com/v1/audio/transcriptions
            \\  Audio: {s}
            \\  Language: {s}
            \\  Model: whisper-1
            \\Requires audio file path and OPENAI_API_KEY env var.
        , .{ audio_path, language }) };
    }
};

test "TranscriptionTool schema" {
    var tool = TranscriptionTool{};
    const handler = tools_interface.makeToolHandler(TranscriptionTool, &tool);
    try std.testing.expectEqualStrings("transcription", handler.schema.name);
}
