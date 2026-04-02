const std = @import("std");

pub fn sendSseEvent(writer: anytype, event_type: []const u8, data: []const u8) !void {
    try writer.print("event: {s}\ndata: {s}\n\n", .{ event_type, data });
}

pub fn makeToolProgressEvent(allocator: std.mem.Allocator, tool_name: []const u8, status: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "{{\"type\":\"tool_progress\",\"tool\":\"{s}\",\"status\":\"{s}\"}}", .{ tool_name, status });
}

pub fn makeThinkingEvent(allocator: std.mem.Allocator, content: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "{{\"type\":\"thinking\",\"content\":\"{s}\"}}", .{content});
}

test "sendSseEvent formats correctly" {
    var buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try sendSseEvent(fbs.writer(), "message", "hello");
    try std.testing.expectEqualStrings("event: message\ndata: hello\n\n", fbs.getWritten());
}

test "makeToolProgressEvent" {
    const result = try makeToolProgressEvent(std.testing.allocator, "read_file", "running");
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "read_file") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "running") != null);
}

test "makeThinkingEvent" {
    const result = try makeThinkingEvent(std.testing.allocator, "analyzing");
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "thinking") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "analyzing") != null);
}
