const std = @import("std");
const tools_interface = @import("../interface.zig");

pub const CronjobTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "cronjob",
        .description = "Manage scheduled cron jobs",
        .parameters_schema =
            \\{"type":"object","properties":{"action":{"type":"string","enum":["add","list","delete"],"description":"Cron action"},"schedule":{"type":"string","description":"Cron schedule expression"},"command":{"type":"string","description":"Command to schedule"}},"required":["action","schedule","command"]}
        ,
    };

    pub fn execute(self: *CronjobTool, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        _ = self;
        const parsed = std.json.parseFromSlice(struct { action: []const u8 = "", schedule: []const u8 = "", command: []const u8 = "" }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();
        return std.fmt.allocPrint(ctx.allocator, "Cron: {s} - {s} - {s}", .{ parsed.value.action, parsed.value.schedule, parsed.value.command });
    }
};

test "CronjobTool schema" {
    var tool = CronjobTool{};
    const handler = tools_interface.makeToolHandler(CronjobTool, &tool);
    try std.testing.expectEqualStrings("cronjob", handler.schema.name);
}
