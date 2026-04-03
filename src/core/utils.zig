const std = @import("std");
const env = @import("env.zig");

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
        const home = try env.getHomeDirOwned(allocator);
        const suffix = std.mem.trimLeft(u8, path[1..], "/\\");
        if (suffix.len == 0) {
            return home;
        }
        defer allocator.free(home);
        return try std.fs.path.join(allocator, &.{ home, suffix });
    }
    return try allocator.dupe(u8, path);
}

test "atomicJsonWrite write and read back" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const dir = try std.fs.path.join(std.testing.allocator, &.{ ".zig-cache", "tmp", tmp.sub_path[0..] });
    defer std.testing.allocator.free(dir);
    const fname = "hermes_test_atomic.json";
    const data = "{\"test\": true}";
    try atomicJsonWrite(dir, fname, data);
    const read = try tmp.dir.readFileAlloc(std.testing.allocator, fname, 4096);
    defer std.testing.allocator.free(read);
    try std.testing.expectEqualStrings(data, read);
}

test "expandHome replaces tilde" {
    const result = try expandHome(std.testing.allocator, "~/test");
    defer std.testing.allocator.free(result);
    try std.testing.expect(result.len > 0);
    try std.testing.expect(!std.mem.startsWith(u8, result, "~"));
}
