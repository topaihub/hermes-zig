const std = @import("std");
const tools_interface = @import("../interface.zig");
const ToolResult = tools_interface.ToolResult;

pub const WebSearchTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "web_search",
        .description = "Search the web for information",
        .parameters_schema =
            \\{"type":"object","properties":{"query":{"type":"string","description":"Search query"}},"required":["query"]}
        ,
    };

    pub fn execute(self: *WebSearchTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const query = tools_interface.getString(args, "query") orelse return .{ .output = "missing query", .is_error = true };
        return .{ .output = try std.fmt.allocPrint(allocator, "[web_search stub] No results for: {s}", .{query}) };
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

    pub fn execute(self: *WebExtractTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const url = tools_interface.getString(args, "url") orelse return .{ .output = "missing url", .is_error = true };
        return .{ .output = try std.fmt.allocPrint(allocator, "Extracted content from: {s}", .{url}) };
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
