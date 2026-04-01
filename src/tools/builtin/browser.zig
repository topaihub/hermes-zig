const std = @import("std");
const tools_interface = @import("../interface.zig");

pub const BrowserTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "browser",
        .description = "Automate browser actions like navigation, clicking, and screenshots",
        .parameters_schema =
            \\{"type":"object","properties":{"url":{"type":"string","description":"URL to navigate to"},"action":{"type":"string","enum":["navigate","click","screenshot"],"description":"Browser action to perform"}},"required":["url","action"]}
        ,
    };

    pub fn execute(self: *BrowserTool, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        _ = self;
        const parsed = std.json.parseFromSlice(struct { url: []const u8 = "", action: []const u8 = "" }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();
        return std.fmt.allocPrint(ctx.allocator, "Browser automation requires headless browser. URL: {s}, Action: {s}", .{ parsed.value.url, parsed.value.action });
    }
};

test "BrowserTool schema" {
    var tool = BrowserTool{};
    const handler = tools_interface.makeToolHandler(BrowserTool, &tool);
    try std.testing.expectEqualStrings("browser", handler.schema.name);
}
