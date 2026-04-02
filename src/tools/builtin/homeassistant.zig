const std = @import("std");
const tools_if = @import("../interface.zig");
const ToolResult = tools_if.ToolResult;

pub const HaListEntities = struct {
    ha_url: []const u8 = "",
    token: []const u8 = "",

    pub const SCHEMA = tools_if.ToolSchema{ .name = "ha_list_entities", .description = "List all Home Assistant entities", .parameters_schema =
        \\{"type":"object","properties":{}}
    };
    pub fn execute(self: *HaListEntities, allocator: std.mem.Allocator, _: std.json.ObjectMap) anyerror!ToolResult {
        return .{ .output = try std.fmt.allocPrint(allocator, "[stub] ha_list_entities at {s}", .{self.ha_url}) };
    }
};

pub const HaGetState = struct {
    ha_url: []const u8 = "",
    token: []const u8 = "",

    pub const SCHEMA = tools_if.ToolSchema{ .name = "ha_get_state", .description = "Get state of a Home Assistant entity", .parameters_schema =
        \\{"type":"object","properties":{"entity_id":{"type":"string"}},"required":["entity_id"]}
    };
    pub fn execute(self: *HaGetState, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const entity_id = tools_if.getString(args, "entity_id") orelse return .{ .output = "missing entity_id", .is_error = true };
        return .{ .output = try std.fmt.allocPrint(allocator, "[stub] ha_get_state: {s}", .{entity_id}) };
    }
};

pub const HaCallService = struct {
    ha_url: []const u8 = "",
    token: []const u8 = "",

    pub const SCHEMA = tools_if.ToolSchema{ .name = "ha_call_service", .description = "Call a Home Assistant service", .parameters_schema =
        \\{"type":"object","properties":{"domain":{"type":"string"},"service":{"type":"string"},"entity_id":{"type":"string"}},"required":["domain","service"]}
    };
    pub fn execute(self: *HaCallService, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const domain = tools_if.getString(args, "domain") orelse return .{ .output = "missing domain", .is_error = true };
        const service = tools_if.getString(args, "service") orelse return .{ .output = "missing service", .is_error = true };
        return .{ .output = try std.fmt.allocPrint(allocator, "[stub] ha_call_service: {s}.{s}", .{ domain, service }) };
    }
};

pub const HaListServices = struct {
    ha_url: []const u8 = "",
    token: []const u8 = "",

    pub const SCHEMA = tools_if.ToolSchema{ .name = "ha_list_services", .description = "List available Home Assistant services", .parameters_schema =
        \\{"type":"object","properties":{}}
    };
    pub fn execute(self: *HaListServices, allocator: std.mem.Allocator, _: std.json.ObjectMap) anyerror!ToolResult {
        return .{ .output = try std.fmt.allocPrint(allocator, "[stub] ha_list_services at {s}", .{self.ha_url}) };
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
