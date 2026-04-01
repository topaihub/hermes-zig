const std = @import("std");
const tools_interface = @import("../interface.zig");

pub const SessionSearchTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "session_search",
        .description = "Search through past session history",
        .parameters_schema =
            \\{"type":"object","properties":{"query":{"type":"string","description":"Search query"},"limit":{"type":"integer","description":"Max results to return"}},"required":["query"]}
        ,
    };

    pub fn execute(self: *SessionSearchTool, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        _ = self;
        const parsed = std.json.parseFromSlice(struct { query: []const u8 = "", limit: u32 = 10 }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();
        return std.fmt.allocPrint(ctx.allocator, "Session search stub: query=\"{s}\" limit={d}. Requires database connection.", .{ parsed.value.query, parsed.value.limit });
    }
};

test "SessionSearchTool schema" {
    var tool = SessionSearchTool{};
    const handler = tools_interface.makeToolHandler(SessionSearchTool, &tool);
    try std.testing.expectEqualStrings("session_search", handler.schema.name);
}
