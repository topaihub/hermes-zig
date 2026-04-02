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
        const prompt = tools_interface.getString(args, "prompt") orelse return .{ .output = "missing prompt", .is_error = true };

        const data = std.fs.cwd().readFileAlloc(allocator, image_path, 10 * 1024 * 1024) catch |err| {
            return .{ .output = try std.fmt.allocPrint(allocator, "Failed to read image {s}: {s}", .{ image_path, @errorName(err) }), .is_error = true };
        };
        defer allocator.free(data);

        const b64_len = std.base64.standard.Encoder.calcSize(data.len);
        const b64 = try allocator.alloc(u8, b64_len);
        defer allocator.free(b64);
        _ = std.base64.standard.Encoder.encode(b64, data);

        // Detect mime type from extension
        const ext = std.fs.path.extension(image_path);
        const mime = if (std.mem.eql(u8, ext, ".png")) "image/png" else if (std.mem.eql(u8, ext, ".gif")) "image/gif" else if (std.mem.eql(u8, ext, ".webp")) "image/webp" else "image/jpeg";

        return .{ .output = try std.fmt.allocPrint(allocator, "data:{s};base64,<{d} bytes encoded>\nPrompt: {s}\nVision analysis requires LLM API integration.", .{ mime, b64.len, prompt }) };
    }
};

test "VisionTool schema" {
    var tool = VisionTool{};
    const handler = tools_interface.makeToolHandler(VisionTool, &tool);
    try std.testing.expectEqualStrings("vision_analyze", handler.schema.name);
}
