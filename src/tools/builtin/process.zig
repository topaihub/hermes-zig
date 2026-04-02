const std = @import("std");
const tools_interface = @import("../interface.zig");
const ToolResult = tools_interface.ToolResult;

pub const ProcessTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "process",
        .description = "Manage background processes and sessions",
        .parameters_schema =
            \\{"type":"object","properties":{"action":{"type":"string","enum":["list","poll","log","kill"],"description":"Process action"},"session_id":{"type":"string","description":"Session ID to act on"}},"required":["action"]}
        ,
    };

    pub fn execute(self: *ProcessTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const action = tools_interface.getString(args, "action") orelse return .{ .output = "missing action", .is_error = true };
        const session_id = tools_interface.getString(args, "session_id") orelse "";

        if (std.mem.eql(u8, action, "list")) {
            return .{ .output = try allocator.dupe(u8, "No background processes running.") };
        } else if (std.mem.eql(u8, action, "poll")) {
            return .{ .output = try std.fmt.allocPrint(allocator, "No process found for session: {s}", .{session_id}) };
        } else if (std.mem.eql(u8, action, "log")) {
            return .{ .output = try std.fmt.allocPrint(allocator, "No logs available for session: {s}", .{session_id}) };
        } else if (std.mem.eql(u8, action, "kill")) {
            return .{ .output = try std.fmt.allocPrint(allocator, "No process to kill for session: {s}", .{session_id}) };
        }
        return .{ .output = try std.fmt.allocPrint(allocator, "Unknown action: {s}", .{action}), .is_error = true };
    }
};

test "ProcessTool schema" {
    var tool = ProcessTool{};
    const handler = tools_interface.makeToolHandler(ProcessTool, &tool);
    try std.testing.expectEqualStrings("process", handler.schema.name);
}
