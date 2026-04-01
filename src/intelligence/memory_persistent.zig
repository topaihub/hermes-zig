const std = @import("std");

pub fn readMemory(allocator: std.mem.Allocator, path: []const u8) ?[]u8 {
    return std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024) catch null;
}

pub fn writeMemory(path: []const u8, content: []const u8) !void {
    // Create parent directories if needed
    if (std.mem.lastIndexOfScalar(u8, path, '/')) |idx| {
        std.fs.cwd().makePath(path[0..idx]) catch {};
    }
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    try file.writeAll(content);
}

pub fn appendMemory(path: []const u8, content: []const u8) !void {
    if (std.mem.lastIndexOfScalar(u8, path, '/')) |idx| {
        std.fs.cwd().makePath(path[0..idx]) catch {};
    }
    const file = std.fs.cwd().openFile(path, .{ .mode = .write_only }) catch |err| switch (err) {
        error.FileNotFound => try std.fs.cwd().createFile(path, .{}),
        else => return err,
    };
    defer file.close();
    try file.seekFromEnd(0);
    try file.writeAll(content);
}

test "readMemory returns null for missing file" {
    const result = readMemory(std.testing.allocator, "/tmp/_hermes_nonexistent_memory_test");
    try std.testing.expectEqual(null, result);
}

test "writeMemory + readMemory roundtrip" {
    const path = "/tmp/_hermes_memory_test_roundtrip.txt";
    defer std.fs.cwd().deleteFile(path) catch {};
    try writeMemory(path, "hello memory");
    const data = readMemory(std.testing.allocator, path).?;
    defer std.testing.allocator.free(data);
    try std.testing.expectEqualStrings("hello memory", data);
}
