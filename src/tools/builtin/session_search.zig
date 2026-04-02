const std = @import("std");
const tools_interface = @import("../interface.zig");
const ToolResult = tools_interface.ToolResult;
const sqlite = @import("../../core/sqlite.zig");
const search = @import("../../core/search.zig");

pub const SessionSearchTool = struct {
    db: ?*sqlite.Database = null,

    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "session_search",
        .description = "Search through past session history",
        .parameters_schema =
            \\{"type":"object","properties":{"query":{"type":"string","description":"Search query"},"limit":{"type":"integer","description":"Max results to return"}},"required":["query"]}
        ,
    };

    pub fn execute(self: *SessionSearchTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        const query = tools_interface.getString(args, "query") orelse return .{ .output = "missing query", .is_error = true };
        const limit = tools_interface.getInt(args, "limit") orelse 10;

        const db_ptr = self.db orelse return .{ .output = "Session search requires database connection" };

        const results = search.searchMessages(db_ptr.*, allocator, query) catch |err| {
            return .{ .output = try std.fmt.allocPrint(allocator, "Search error: {s}", .{@errorName(err)}), .is_error = true };
        };
        defer search.freeResults(allocator, results);

        if (results.len == 0) return .{ .output = try std.fmt.allocPrint(allocator, "No results for: {s}", .{query}) };

        var out = std.ArrayList(u8).init(allocator);
        const w = out.writer();
        const n: usize = @min(results.len, @as(usize, @intCast(limit)));
        for (results[0..n], 0..) |r, i| {
            try w.print("{d}. [{s}] {s}: {s}\n", .{ i + 1, r.session_id, r.role, r.content });
        }
        return .{ .output = try out.toOwnedSlice() };
    }
};

test "SessionSearchTool schema" {
    var tool = SessionSearchTool{};
    const handler = tools_interface.makeToolHandler(SessionSearchTool, &tool);
    try std.testing.expectEqualStrings("session_search", handler.schema.name);
}
