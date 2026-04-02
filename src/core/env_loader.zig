const std = @import("std");

pub const EnvMap = std.StringHashMap([]const u8);

pub fn loadEnvFile(allocator: std.mem.Allocator, path: []const u8) !EnvMap {
    var map = EnvMap.init(allocator);
    errdefer {
        var it = map.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        map.deinit();
    }

    const content = std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => return map,
        else => return err,
    };
    defer allocator.free(content);

    try parseEnvContent(allocator, content, &map);
    return map;
}

pub fn parseEnvContent(allocator: std.mem.Allocator, content: []const u8, map: *EnvMap) !void {
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const key = std.mem.trim(u8, line[0..eq], " \t");
        var val = std.mem.trim(u8, line[eq + 1 ..], " \t");
        // Strip surrounding quotes
        if (val.len >= 2 and (val[0] == '"' or val[0] == '\'') and val[val.len - 1] == val[0]) {
            val = val[1 .. val.len - 1];
        }
        const k = try allocator.dupe(u8, key);
        const v = try allocator.dupe(u8, val);
        try map.put(k, v);
    }
}

pub fn deinitEnvMap(allocator: std.mem.Allocator, map: *EnvMap) void {
    var it = map.iterator();
    while (it.next()) |entry| {
        allocator.free(entry.key_ptr.*);
        allocator.free(entry.value_ptr.*);
    }
    map.deinit();
}

test "parseEnvContent handles KEY=VALUE and comments" {
    var map = EnvMap.init(std.testing.allocator);
    defer deinitEnvMap(std.testing.allocator, &map);

    const content =
        \\# comment
        \\API_KEY=sk-test123
        \\QUOTED="hello world"
        \\SINGLE='value'
        \\EMPTY=
        \\
    ;
    try parseEnvContent(std.testing.allocator, content, &map);
    try std.testing.expectEqualStrings("sk-test123", map.get("API_KEY").?);
    try std.testing.expectEqualStrings("hello world", map.get("QUOTED").?);
    try std.testing.expectEqualStrings("value", map.get("SINGLE").?);
    try std.testing.expectEqualStrings("", map.get("EMPTY").?);
}
