const std = @import("std");

pub const ToolKind = enum { read_only, write, dangerous };

const write_tools = [_][]const u8{ "write_file", "patch" };
const dangerous_tools = [_][]const u8{ "terminal", "execute_code", "process" };

pub fn getToolKind(name: []const u8) ToolKind {
    for (dangerous_tools) |d| {
        if (std.mem.eql(u8, name, d)) return .dangerous;
    }
    for (write_tools) |w| {
        if (std.mem.eql(u8, name, w)) return .write;
    }
    return .read_only;
}

pub fn buildToolStartEvent(allocator: std.mem.Allocator, name: []const u8, args: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "{{\"type\":\"tool_start\",\"name\":\"{s}\",\"args\":{s}}}", .{ name, args });
}

pub fn buildToolCompleteEvent(allocator: std.mem.Allocator, name: []const u8, result: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "{{\"type\":\"tool_complete\",\"name\":\"{s}\",\"result\":\"{s}\"}}", .{ name, result });
}

test "getToolKind classification" {
    try std.testing.expectEqual(ToolKind.dangerous, getToolKind("terminal"));
    try std.testing.expectEqual(ToolKind.write, getToolKind("write_file"));
    try std.testing.expectEqual(ToolKind.read_only, getToolKind("read_file"));
    try std.testing.expectEqual(ToolKind.read_only, getToolKind("web_search"));
}

test "buildToolStartEvent" {
    const ev = try buildToolStartEvent(std.testing.allocator, "read_file", "{}");
    defer std.testing.allocator.free(ev);
    try std.testing.expect(std.mem.indexOf(u8, ev, "tool_start") != null);
    try std.testing.expect(std.mem.indexOf(u8, ev, "read_file") != null);
}

test "buildToolCompleteEvent" {
    const ev = try buildToolCompleteEvent(std.testing.allocator, "read_file", "ok");
    defer std.testing.allocator.free(ev);
    try std.testing.expect(std.mem.indexOf(u8, ev, "tool_complete") != null);
}
