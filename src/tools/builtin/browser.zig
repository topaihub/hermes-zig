const std = @import("std");
const tools_interface = @import("../interface.zig");
const ToolResult = tools_interface.ToolResult;

pub const BrowserTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "browser",
        .description = "Automate browser actions like navigation, clicking, and screenshots",
        .parameters_schema =
            \\{"type":"object","properties":{"url":{"type":"string","description":"URL to navigate to"},"action":{"type":"string","enum":["navigate","click","screenshot"],"description":"Browser action to perform"}},"required":["url","action"]}
        ,
    };

    pub fn execute(self: *BrowserTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const url = tools_interface.getString(args, "url") orelse return .{ .output = "missing url", .is_error = true };
        const action = tools_interface.getString(args, "action") orelse return .{ .output = "missing action", .is_error = true };
        return .{ .output = try std.fmt.allocPrint(allocator, "Browser automation requires headless browser. URL: {s}, Action: {s}", .{ url, action }) };
    }
};

test "BrowserTool schema" {
    var tool = BrowserTool{};
    const handler = tools_interface.makeToolHandler(BrowserTool, &tool);
    try std.testing.expectEqualStrings("browser", handler.schema.name);
}
