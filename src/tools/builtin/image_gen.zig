const std = @import("std");
const tools_interface = @import("../interface.zig");

pub const ImageGenTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "image_generate",
        .description = "Generate images from text prompts",
        .parameters_schema =
            \\{"type":"object","properties":{"prompt":{"type":"string","description":"Image generation prompt"},"size":{"type":"string","description":"Image size"}},"required":["prompt","size"]}
        ,
    };

    pub fn execute(self: *ImageGenTool, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        _ = self;
        const parsed = std.json.parseFromSlice(struct { prompt: []const u8 = "", size: []const u8 = "" }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();
        return std.fmt.allocPrint(ctx.allocator, "Image generation requires DALL-E/SD API. Prompt: {s}", .{parsed.value.prompt});
    }
};

test "ImageGenTool schema" {
    var tool = ImageGenTool{};
    const handler = tools_interface.makeToolHandler(ImageGenTool, &tool);
    try std.testing.expectEqualStrings("image_generate", handler.schema.name);
}
