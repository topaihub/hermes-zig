const std = @import("std");
const tools_interface = @import("../interface.zig");
const ToolResult = tools_interface.ToolResult;

pub const VisionTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "vision_analyze",
        .description = "Analyze images using LLM vision capabilities",
        .parameters_schema =
            \\{"type":"object","properties":{"image_path":{"type":"string","description":"Path to the image file"},"prompt":{"type":"string","description":"Analysis prompt"}},"required":["image_path","prompt"]}
        ,
    };

    pub fn execute(self: *VisionTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const image_path = tools_interface.getString(args, "image_path") orelse return .{ .output = "missing image_path", .is_error = true };
        return .{ .output = try std.fmt.allocPrint(allocator, "Vision analysis requires LLM vision API. Image: {s}", .{image_path}) };
    }
};

test "VisionTool schema" {
    var tool = VisionTool{};
    const handler = tools_interface.makeToolHandler(VisionTool, &tool);
    try std.testing.expectEqualStrings("vision_analyze", handler.schema.name);
}
