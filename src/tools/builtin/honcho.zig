const std = @import("std");
const tools_if = @import("../interface.zig");
const ToolResult = tools_if.ToolResult;

pub const HonchoContext = struct {
    base_url: []const u8 = "",
    api_key: []const u8 = "",

    pub const SCHEMA = tools_if.ToolSchema{ .name = "honcho_context", .description = "Get context from Honcho", .parameters_schema =
        \\{"type":"object","properties":{"session_id":{"type":"string"}},"required":["session_id"]}
    };
    pub fn execute(self: *HonchoContext, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const session_id = tools_if.getString(args, "session_id") orelse return .{ .output = "missing session_id", .is_error = true };
        return .{ .output = try std.fmt.allocPrint(allocator, "[honcho_context] Args: session_id={s}. Requires HONCHO_API configuration.", .{session_id}) };
    }
};

pub const HonchoProfile = struct {
    base_url: []const u8 = "",
    api_key: []const u8 = "",

    pub const SCHEMA = tools_if.ToolSchema{ .name = "honcho_profile", .description = "Get user profile from Honcho", .parameters_schema =
        \\{"type":"object","properties":{"user_id":{"type":"string"}},"required":["user_id"]}
    };
    pub fn execute(self: *HonchoProfile, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const user_id = tools_if.getString(args, "user_id") orelse return .{ .output = "missing user_id", .is_error = true };
        return .{ .output = try std.fmt.allocPrint(allocator, "[honcho_profile] Args: user_id={s}. Requires HONCHO_API configuration.", .{user_id}) };
    }
};

pub const HonchoSearch = struct {
    base_url: []const u8 = "",
    api_key: []const u8 = "",

    pub const SCHEMA = tools_if.ToolSchema{ .name = "honcho_search", .description = "Search Honcho memory", .parameters_schema =
        \\{"type":"object","properties":{"query":{"type":"string"}},"required":["query"]}
    };
    pub fn execute(self: *HonchoSearch, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const query = tools_if.getString(args, "query") orelse return .{ .output = "missing query", .is_error = true };
        return .{ .output = try std.fmt.allocPrint(allocator, "[honcho_search] Args: query={s}. Requires HONCHO_API configuration.", .{query}) };
    }
};

pub const HonchoConclude = struct {
    base_url: []const u8 = "",
    api_key: []const u8 = "",

    pub const SCHEMA = tools_if.ToolSchema{ .name = "honcho_conclude", .description = "Conclude a Honcho session", .parameters_schema =
        \\{"type":"object","properties":{"session_id":{"type":"string"}},"required":["session_id"]}
    };
    pub fn execute(self: *HonchoConclude, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const session_id = tools_if.getString(args, "session_id") orelse return .{ .output = "missing session_id", .is_error = true };
        return .{ .output = try std.fmt.allocPrint(allocator, "[honcho_conclude] Args: session_id={s}. Requires HONCHO_API configuration.", .{session_id}) };
    }
};

test "honcho schemas" {
    const testing = std.testing;
    var c = HonchoContext{};
    try testing.expectEqualStrings("honcho_context", tools_if.makeToolHandler(HonchoContext, &c).schema.name);
    var p = HonchoProfile{};
    try testing.expectEqualStrings("honcho_profile", tools_if.makeToolHandler(HonchoProfile, &p).schema.name);
    var s = HonchoSearch{};
    try testing.expectEqualStrings("honcho_search", tools_if.makeToolHandler(HonchoSearch, &s).schema.name);
    var d = HonchoConclude{};
    try testing.expectEqualStrings("honcho_conclude", tools_if.makeToolHandler(HonchoConclude, &d).schema.name);
}
