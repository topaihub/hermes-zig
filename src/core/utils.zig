const std = @import("std");

pub fn atomicJsonWrite(dir_path: []const u8, filename: []const u8, json: []const u8) !void {
    const dir = try std.fs.cwd().openDir(dir_path, .{});
    const tmp_name = "._hermes_tmp";
    const file = try dir.createFile(tmp_name, .{});
    file.writeAll(json) catch |e| {
        file.close();
        return e;
    };
    file.close();
    try dir.rename(tmp_name, filename);
}

pub fn expandHome(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    if (path.len > 0 and path[0] == '~') {
        const home = std.posix.getenv("HOME") orelse "/tmp";
        return try std.fs.path.join(allocator, &.{ home, path[1..] });
    }
    return try allocator.dupe(u8, path);
}

test "atomicJsonWrite write and read back" {
    const dir = "/tmp";
    const fname = "hermes_test_atomic.json";
    const data = "{\"test\": true}";
    try atomicJsonWrite(dir, fname, data);
    const full = try std.fs.path.join(std.testing.allocator, &.{ dir, fname });
    defer std.testing.allocator.free(full);
    const read = try std.fs.cwd().readFileAlloc(std.testing.allocator, full, 4096);
    defer std.testing.allocator.free(read);
    try std.testing.expectEqualStrings(data, read);
    std.fs.cwd().deleteFile(full) catch {};
}

test "expandHome replaces tilde" {
    const result = try expandHome(std.testing.allocator, "~/test");
    defer std.testing.allocator.free(result);
    try std.testing.expect(result.len > 0);
    try std.testing.expect(!std.mem.startsWith(u8, result, "~"));
}
