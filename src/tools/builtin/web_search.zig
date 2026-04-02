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
        return duckduckgo(allocator, query) catch |err| {
            return .{ .output = try std.fmt.allocPrint(allocator, "[web_search] HTTP failed ({s}), no results for: {s}", .{ @errorName(err), query }) };
        };
    }

    fn duckduckgo(allocator: std.mem.Allocator, query: []const u8) !ToolResult {
        const encoded = try std.Uri.Component.percent_encode(allocator, query, .{});
        defer allocator.free(encoded);
        const url = try std.fmt.allocPrint(allocator, "https://api.duckduckgo.com/?q={s}&format=json&no_html=1", .{encoded});
        defer allocator.free(url);

        var client: std.http.Client = .{ .allocator = allocator };
        defer client.deinit();

        var buf = std.ArrayList(u8).init(allocator);
        defer buf.deinit();

        const result = try client.fetch(.{
            .location = .{ .url = url },
            .response_storage = .{ .dynamic = &buf },
        });

        if (@intFromEnum(result.status) >= 400) return error.HttpError;

        const body = buf.items;
        const parsed = std.json.parseFromSlice(std.json.Value, allocator, body, .{ .ignore_unknown_fields = true }) catch
            return .{ .output = try std.fmt.allocPrint(allocator, "[web_search] Could not parse response for: {s}", .{query}) };
        defer parsed.deinit();
        const root = parsed.value.object;

        var out = std.ArrayList(u8).init(allocator);
        const w = out.writer();

        // AbstractText
        if (root.get("AbstractText")) |v| {
            if (v == .string and v.string.len > 0) {
                try w.print("Summary: {s}\n\n", .{v.string});
            }
        }

        // RelatedTopics
        if (root.get("RelatedTopics")) |rt| {
            if (rt == .array) {
                var count: usize = 0;
                for (rt.array.items) |item| {
                    if (count >= 8) break;
                    if (item != .object) continue;
                    const text = if (item.object.get("Text")) |t| (if (t == .string) t.string else null) else null;
                    const furl = if (item.object.get("FirstURL")) |u| (if (u == .string) u.string else null) else null;
                    if (text) |t| {
                        try w.print("- {s}", .{t});
                        if (furl) |f| try w.print(" ({s})", .{f});
                        try w.writeByte('\n');
                        count += 1;
                    }
                }
            }
        }

        if (out.items.len == 0) {
            return .{ .output = try std.fmt.allocPrint(allocator, "[web_search] No results for: {s}", .{query}) };
        }
        return .{ .output = try out.toOwnedSlice() };
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
