const std = @import("std");
const tools_interface = @import("../interface.zig");
const ToolResult = tools_interface.ToolResult;

pub const CronjobTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "cronjob",
        .description = "Manage scheduled cron jobs",
        .parameters_schema =
            \\{"type":"object","properties":{"action":{"type":"string","enum":["add","list","delete"],"description":"Cron action"},"schedule":{"type":"string","description":"Cron schedule expression"},"command":{"type":"string","description":"Command to schedule"}},"required":["action","schedule","command"]}
        ,
    };

    pub fn execute(self: *CronjobTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const action = tools_interface.getString(args, "action") orelse return .{ .output = "missing action", .is_error = true };
        const schedule = tools_interface.getString(args, "schedule") orelse return .{ .output = "missing schedule", .is_error = true };
        const command = tools_interface.getString(args, "command") orelse return .{ .output = "missing command", .is_error = true };
        return .{ .output = try std.fmt.allocPrint(allocator, "Cron: {s} - {s} - {s}", .{ action, schedule, command }) };
    }
};

test "CronjobTool schema" {
    var tool = CronjobTool{};
    const handler = tools_interface.makeToolHandler(CronjobTool, &tool);
    try std.testing.expectEqualStrings("cronjob", handler.schema.name);
}
