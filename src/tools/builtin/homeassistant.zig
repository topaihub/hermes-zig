const std = @import("std");
const tools_if = @import("../interface.zig");

pub const HaListEntities = struct {
    ha_url: []const u8 = "",
    token: []const u8 = "",

    pub const SCHEMA = tools_if.ToolSchema{ .name = "ha_list_entities", .description = "List all Home Assistant entities", .parameters_schema =
        \\{"type":"object","properties":{}}
    };
    pub fn execute(self: *HaListEntities, _: []const u8, ctx: *const tools_if.ToolContext) anyerror![]const u8 {
        return std.fmt.allocPrint(ctx.allocator, "[stub] ha_list_entities at {s}", .{self.ha_url});
    }
};

pub const HaGetState = struct {
    ha_url: []const u8 = "",
    token: []const u8 = "",

    pub const SCHEMA = tools_if.ToolSchema{ .name = "ha_get_state", .description = "Get state of a Home Assistant entity", .parameters_schema =
        \\{"type":"object","properties":{"entity_id":{"type":"string"}},"required":["entity_id"]}
    };
    pub fn execute(self: *HaGetState, args_json: []const u8, ctx: *const tools_if.ToolContext) anyerror![]const u8 {
        _ = self;
        const parsed = std.json.parseFromSlice(struct { entity_id: []const u8 = "" }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();
        return std.fmt.allocPrint(ctx.allocator, "[stub] ha_get_state: {s}", .{parsed.value.entity_id});
    }
};

pub const HaCallService = struct {
    ha_url: []const u8 = "",
    token: []const u8 = "",

    pub const SCHEMA = tools_if.ToolSchema{ .name = "ha_call_service", .description = "Call a Home Assistant service", .parameters_schema =
        \\{"type":"object","properties":{"domain":{"type":"string"},"service":{"type":"string"},"entity_id":{"type":"string"}},"required":["domain","service"]}
    };
    pub fn execute(self: *HaCallService, args_json: []const u8, ctx: *const tools_if.ToolContext) anyerror![]const u8 {
        _ = self;
        const parsed = std.json.parseFromSlice(struct { domain: []const u8 = "", service: []const u8 = "", entity_id: []const u8 = "" }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();
        return std.fmt.allocPrint(ctx.allocator, "[stub] ha_call_service: {s}.{s}", .{ parsed.value.domain, parsed.value.service });
    }
};

pub const HaListServices = struct {
    ha_url: []const u8 = "",
    token: []const u8 = "",

    pub const SCHEMA = tools_if.ToolSchema{ .name = "ha_list_services", .description = "List available Home Assistant services", .parameters_schema =
        \\{"type":"object","properties":{}}
    };
    pub fn execute(self: *HaListServices, _: []const u8, ctx: *const tools_if.ToolContext) anyerror![]const u8 {
        return std.fmt.allocPrint(ctx.allocator, "[stub] ha_list_services at {s}", .{self.ha_url});
    }
};

test "homeassistant schemas" {
    const testing = std.testing;
    var e = HaListEntities{};
    try testing.expectEqualStrings("ha_list_entities", tools_if.makeToolHandler(HaListEntities, &e).schema.name);
    var s = HaGetState{};
    try testing.expectEqualStrings("ha_get_state", tools_if.makeToolHandler(HaGetState, &s).schema.name);
    var c = HaCallService{};
    try testing.expectEqualStrings("ha_call_service", tools_if.makeToolHandler(HaCallService, &c).schema.name);
    var l = HaListServices{};
    try testing.expectEqualStrings("ha_list_services", tools_if.makeToolHandler(HaListServices, &l).schema.name);
}
