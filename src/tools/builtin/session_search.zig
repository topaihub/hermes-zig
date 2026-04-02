const std = @import("std");
const tools_interface = @import("../interface.zig");
const ToolResult = tools_interface.ToolResult;

pub const SessionSearchTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "session_search",
        .description = "Search through past session history",
        .parameters_schema =
            \\{"type":"object","properties":{"query":{"type":"string","description":"Search query"},"limit":{"type":"integer","description":"Max results to return"}},"required":["query"]}
        ,
    };

    pub fn execute(self: *SessionSearchTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const query = tools_interface.getString(args, "query") orelse return .{ .output = "missing query", .is_error = true };
        const limit = tools_interface.getInt(args, "limit") orelse 10;
        return .{ .output = try std.fmt.allocPrint(allocator, "Session search stub: query=\"{s}\" limit={d}. Requires database connection.", .{ query, limit }) };
    }
};

test "SessionSearchTool schema" {
    var tool = SessionSearchTool{};
    const handler = tools_interface.makeToolHandler(SessionSearchTool, &tool);
    try std.testing.expectEqualStrings("session_search", handler.schema.name);
}
