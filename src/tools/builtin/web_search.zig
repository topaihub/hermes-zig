const std = @import("std");
const tools_interface = @import("../interface.zig");

pub const WebSearchTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "web_search",
        .description = "Search the web for information",
        .parameters_schema =
            \\{"type":"object","properties":{"query":{"type":"string","description":"Search query"}},"required":["query"]}
        ,
    };

    pub fn execute(self: *WebSearchTool, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        _ = self;
        const parsed = std.json.parseFromSlice(struct { query: []const u8 }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();
        return std.fmt.allocPrint(ctx.allocator, "[web_search stub] No results for: {s}", .{parsed.value.query});
    }
};

pub const WebExtractTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "web_extract",
        .description = "Extract and summarize content from a specific web page URL.",
        .parameters_schema =
            \\{"type":"object","properties":{"url":{"type":"string","description":"URL to extract content from"},"instructions":{"type":"string","description":"What to extract or focus on"}},"required":["url"]}
        ,
    };

    pub fn execute(self: *WebExtractTool, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        _ = self;
        const parsed = std.json.parseFromSlice(struct { url: []const u8 }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();
        return std.fmt.allocPrint(ctx.allocator, "Extracted content from: {s}", .{parsed.value.url});
    }
};

test "WebSearchTool and WebExtractTool schemas" {
    var tool = WebSearchTool{};
    const handler = tools_interface.makeToolHandler(WebSearchTool, &tool);
    try std.testing.expectEqualStrings("web_search", handler.schema.name);

    var ext = WebExtractTool{};
    const ext_handler = tools_interface.makeToolHandler(WebExtractTool, &ext);
    try std.testing.expectEqualStrings("web_extract", ext_handler.schema.name);
}
