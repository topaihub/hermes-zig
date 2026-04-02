const std = @import("std");
const tools_interface = @import("../interface.zig");
const ToolResult = tools_interface.ToolResult;

pub const ImageGenTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "image_generate",
        .description = "Generate images from text prompts",
        .parameters_schema =
            \\{"type":"object","properties":{"prompt":{"type":"string","description":"Image generation prompt"},"size":{"type":"string","description":"Image size"}},"required":["prompt","size"]}
        ,
    };

    pub fn execute(self: *ImageGenTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const prompt = tools_interface.getString(args, "prompt") orelse return .{ .output = "missing prompt", .is_error = true };
        return .{ .output = try std.fmt.allocPrint(allocator, "Image generation requires DALL-E/SD API. Prompt: {s}", .{prompt}) };
    }
};

test "ImageGenTool schema" {
    var tool = ImageGenTool{};
    const handler = tools_interface.makeToolHandler(ImageGenTool, &tool);
    try std.testing.expectEqualStrings("image_generate", handler.schema.name);
}
