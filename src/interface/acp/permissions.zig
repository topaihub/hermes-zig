const std = @import("std");

pub const ToolPermission = enum { allowed, denied, ask };

const dangerous_tools = [_][]const u8{ "terminal", "write_file", "patch", "execute_code", "process" };

pub fn checkPermission(tool_name: []const u8) ToolPermission {
    for (dangerous_tools) |d| {
        if (std.mem.eql(u8, tool_name, d)) return .ask;
    }
    return .allowed;
}

test "safe tools are allowed" {
    try std.testing.expectEqual(ToolPermission.allowed, checkPermission("read_file"));
    try std.testing.expectEqual(ToolPermission.allowed, checkPermission("web_search"));
}

test "dangerous tools require ask" {
    try std.testing.expectEqual(ToolPermission.ask, checkPermission("terminal"));
    try std.testing.expectEqual(ToolPermission.ask, checkPermission("write_file"));
    try std.testing.expectEqual(ToolPermission.ask, checkPermission("execute_code"));
}
