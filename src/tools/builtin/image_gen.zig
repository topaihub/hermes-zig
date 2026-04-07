const std = @import("std");
const tools_interface = @import("../interface.zig");
const ToolResult = tools_interface.ToolResult;

pub const ImageGenTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "image_generate",
        .description = "Generate images from text prompts via OpenAI DALL-E API",
        .parameters_schema =
            \\{"type":"object","properties":{"prompt":{"type":"string","description":"Image generation prompt"},"size":{"type":"string","description":"Image size (1024x1024, 1792x1024, 1024x1792)"}},"required":["prompt"]}
        ,
    };

    pub fn execute(self: *ImageGenTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const prompt = tools_interface.getString(args, "prompt") orelse return .{ .output = "missing prompt", .is_error = true };
        const size = tools_interface.getString(args, "size") orelse "1024x1024";

        const api_key = std.process.getEnvVarOwned(allocator, "OPENAI_API_KEY") catch {
            return .{ .output = try std.fmt.allocPrint(allocator,
                \\[ImageGen] API endpoint: POST https://api.openai.com/v1/images/generations
                \\  Prompt: {s}
                \\  Size: {s}
                \\  Model: dall-e-3
                \\Error: OPENAI_API_KEY not set. Set env var to enable image generation.
            , .{ prompt, size }) };
        };
        defer allocator.free(api_key);

        const body = try std.fmt.allocPrint(allocator, "{{\"model\":\"dall-e-3\",\"prompt\":\"{s}\",\"size\":\"{s}\",\"n\":1}}", .{ prompt, size });
        defer allocator.free(body);

        var client: std.http.Client = .{ .allocator = allocator };
        defer client.deinit();

        var response_writer: std.Io.Writer.Allocating = .init(allocator);
        defer response_writer.deinit();
        const auth_header = try std.fmt.allocPrint(allocator, "Bearer {s}", .{api_key});
        defer allocator.free(auth_header);

        _ = client.fetch(.{
            .location = .{ .url = "https://api.openai.com/v1/images/generations" },
            .method = .POST,
            .payload = body,
            .extra_headers = &.{
                .{ .name = "Authorization", .value = auth_header },
                .{ .name = "Content-Type", .value = "application/json" },
            },
            .response_writer = &response_writer.writer,
        }) catch return .{ .output = "HTTP request failed", .is_error = true };

        return .{ .output = try response_writer.toOwnedSlice() };
    }
};

test "ImageGenTool schema" {
    var tool = ImageGenTool{};
    const handler = tools_interface.makeToolHandler(ImageGenTool, &tool);
    try std.testing.expectEqualStrings("image_generate", handler.schema.name);
}
