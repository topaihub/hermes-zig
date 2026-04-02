const std = @import("std");
const tools_interface = @import("../interface.zig");
const ToolResult = tools_interface.ToolResult;

pub const TranscriptionTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "transcription",
        .description = "Transcribe audio files to text",
        .parameters_schema =
            \\{"type":"object","properties":{"audio_path":{"type":"string","description":"Path to the audio file"}},"required":["audio_path"]}
        ,
    };

    pub fn execute(self: *TranscriptionTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const audio_path = tools_interface.getString(args, "audio_path") orelse return .{ .output = "missing audio_path", .is_error = true };
        return .{ .output = try std.fmt.allocPrint(allocator, "Transcription requires Whisper API. Audio: {s}", .{audio_path}) };
    }
};

test "TranscriptionTool schema" {
    var tool = TranscriptionTool{};
    const handler = tools_interface.makeToolHandler(TranscriptionTool, &tool);
    try std.testing.expectEqualStrings("transcription", handler.schema.name);
}
