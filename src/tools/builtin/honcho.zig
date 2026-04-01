const std = @import("std");
const tools_if = @import("../interface.zig");

pub const HonchoContext = struct {
    base_url: []const u8 = "",
    api_key: []const u8 = "",

    pub const SCHEMA = tools_if.ToolSchema{ .name = "honcho_context", .description = "Get context from Honcho", .parameters_schema =
        \\{"type":"object","properties":{"session_id":{"type":"string"}},"required":["session_id"]}
    };
    pub fn execute(self: *HonchoContext, args_json: []const u8, ctx: *const tools_if.ToolContext) anyerror![]const u8 {
        _ = self;
        const parsed = std.json.parseFromSlice(struct { session_id: []const u8 = "" }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();
        return std.fmt.allocPrint(ctx.allocator, "[stub] honcho_context: {s}", .{parsed.value.session_id});
    }
};

pub const HonchoProfile = struct {
    base_url: []const u8 = "",
    api_key: []const u8 = "",

    pub const SCHEMA = tools_if.ToolSchema{ .name = "honcho_profile", .description = "Get user profile from Honcho", .parameters_schema =
        \\{"type":"object","properties":{"user_id":{"type":"string"}},"required":["user_id"]}
    };
    pub fn execute(self: *HonchoProfile, args_json: []const u8, ctx: *const tools_if.ToolContext) anyerror![]const u8 {
        _ = self;
        const parsed = std.json.parseFromSlice(struct { user_id: []const u8 = "" }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();
        return std.fmt.allocPrint(ctx.allocator, "[stub] honcho_profile: {s}", .{parsed.value.user_id});
    }
};

pub const HonchoSearch = struct {
    base_url: []const u8 = "",
    api_key: []const u8 = "",

    pub const SCHEMA = tools_if.ToolSchema{ .name = "honcho_search", .description = "Search Honcho memory", .parameters_schema =
        \\{"type":"object","properties":{"query":{"type":"string"}},"required":["query"]}
    };
    pub fn execute(self: *HonchoSearch, args_json: []const u8, ctx: *const tools_if.ToolContext) anyerror![]const u8 {
        _ = self;
        const parsed = std.json.parseFromSlice(struct { query: []const u8 = "" }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();
        return std.fmt.allocPrint(ctx.allocator, "[stub] honcho_search: {s}", .{parsed.value.query});
    }
};

pub const HonchoConclude = struct {
    base_url: []const u8 = "",
    api_key: []const u8 = "",

    pub const SCHEMA = tools_if.ToolSchema{ .name = "honcho_conclude", .description = "Conclude a Honcho session", .parameters_schema =
        \\{"type":"object","properties":{"session_id":{"type":"string"}},"required":["session_id"]}
    };
    pub fn execute(self: *HonchoConclude, args_json: []const u8, ctx: *const tools_if.ToolContext) anyerror![]const u8 {
        _ = self;
        const parsed = std.json.parseFromSlice(struct { session_id: []const u8 = "" }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();
        return std.fmt.allocPrint(ctx.allocator, "[stub] honcho_conclude: {s}", .{parsed.value.session_id});
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
