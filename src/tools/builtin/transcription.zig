const std = @import("std");
const tools_interface = @import("../interface.zig");

pub const TranscriptionTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "transcription",
        .description = "Transcribe audio files to text",
        .parameters_schema =
            \\{"type":"object","properties":{"audio_path":{"type":"string","description":"Path to the audio file"}},"required":["audio_path"]}
        ,
    };

    pub fn execute(self: *TranscriptionTool, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        _ = self;
        const parsed = std.json.parseFromSlice(struct { audio_path: []const u8 = "" }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();
        return std.fmt.allocPrint(ctx.allocator, "Transcription requires Whisper API. Audio: {s}", .{parsed.value.audio_path});
    }
};

test "TranscriptionTool schema" {
    var tool = TranscriptionTool{};
    const handler = tools_interface.makeToolHandler(TranscriptionTool, &tool);
    try std.testing.expectEqualStrings("transcription", handler.schema.name);
}
