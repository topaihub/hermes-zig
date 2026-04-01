const std = @import("std");
const tools_interface = @import("../interface.zig");

pub const VisionTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "vision",
        .description = "Analyze images using LLM vision capabilities",
        .parameters_schema =
            \\{"type":"object","properties":{"image_path":{"type":"string","description":"Path to the image file"},"prompt":{"type":"string","description":"Analysis prompt"}},"required":["image_path","prompt"]}
        ,
    };

    pub fn execute(self: *VisionTool, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        _ = self;
        const parsed = std.json.parseFromSlice(struct { image_path: []const u8 = "", prompt: []const u8 = "" }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();
        return std.fmt.allocPrint(ctx.allocator, "Vision analysis requires LLM vision API. Image: {s}", .{parsed.value.image_path});
    }
};

test "VisionTool schema" {
    var tool = VisionTool{};
    const handler = tools_interface.makeToolHandler(VisionTool, &tool);
    try std.testing.expectEqualStrings("vision", handler.schema.name);
}
