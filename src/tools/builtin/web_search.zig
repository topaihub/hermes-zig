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

test "WebSearchTool schema" {
    var tool = WebSearchTool{};
    const handler = tools_interface.makeToolHandler(WebSearchTool, &tool);
    try std.testing.expectEqualStrings("web_search", handler.schema.name);
}
