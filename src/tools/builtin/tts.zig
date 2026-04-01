const std = @import("std");
const tools_interface = @import("../interface.zig");

pub const TtsTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "tts",
        .description = "Convert text to speech audio",
        .parameters_schema =
            \\{"type":"object","properties":{"text":{"type":"string","description":"Text to convert to speech"},"voice":{"type":"string","description":"Voice to use"}},"required":["text","voice"]}
        ,
    };

    pub fn execute(self: *TtsTool, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        _ = self;
        const parsed = std.json.parseFromSlice(struct { text: []const u8 = "", voice: []const u8 = "" }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();
        return std.fmt.allocPrint(ctx.allocator, "TTS requires speech synthesis API. Text length: {d}", .{parsed.value.text.len});
    }
};

test "TtsTool schema" {
    var tool = TtsTool{};
    const handler = tools_interface.makeToolHandler(TtsTool, &tool);
    try std.testing.expectEqualStrings("tts", handler.schema.name);
}
