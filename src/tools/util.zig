const std = @import("std");

pub const Hunk = struct {
    old_start: u32,
    old_count: u32,
    new_start: u32,
    new_count: u32,
    lines: []const u8,
};

pub fn stripAnsi(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);
    var i: usize = 0;
    while (i < input.len) {
        if (input[i] == 0x1b and i + 1 < input.len and input[i + 1] == '[') {
            i += 2;
            while (i < input.len and input[i] != 'm') : (i += 1) {}
            if (i < input.len) i += 1;
        } else {
            try result.append(allocator, input[i]);
            i += 1;
        }
    }
    return result.toOwnedSlice(allocator);
}

pub fn fuzzyMatch(query: []const u8, candidate: []const u8) f32 {
    if (query.len == 0) return 1.0;
    if (candidate.len == 0) return 0.0;
    var qi: usize = 0;
    for (candidate) |ch| {
        if (qi < query.len and toLower(ch) == toLower(query[qi])) qi += 1;
    }
    if (qi == query.len) return @as(f32, @floatFromInt(query.len)) / @as(f32, @floatFromInt(candidate.len));
    return 0.0;
}

fn toLower(c: u8) u8 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

pub fn parsePatch(allocator: std.mem.Allocator, diff: []const u8) ![]Hunk {
    var hunks = std.ArrayList(Hunk){};
    errdefer hunks.deinit(allocator);
    var lines = std.mem.splitScalar(u8, diff, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "@@ ")) {
            try hunks.append(allocator, .{ .old_start = 0, .old_count = 0, .new_start = 0, .new_count = 0, .lines = line });
        }
    }
    return hunks.toOwnedSlice(allocator);
}

test "stripAnsi removes escape sequences" {
    const input = "\x1b[31mhello\x1b[0m world";
    const result = try stripAnsi(std.testing.allocator, input);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("hello world", result);
}

test "stripAnsi passes through plain text" {
    const result = try stripAnsi(std.testing.allocator, "plain text");
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("plain text", result);
}

test "fuzzyMatch scores" {
    try std.testing.expect(fuzzyMatch("abc", "abc") > 0.9);
    try std.testing.expect(fuzzyMatch("abc", "aXbXc") > 0.0);
    try std.testing.expect(fuzzyMatch("xyz", "abc") == 0.0);
    try std.testing.expect(fuzzyMatch("", "anything") == 1.0);
}

test "parsePatch finds hunks" {
    const diff = "--- a/file\n+++ b/file\n@@ -1,3 +1,4 @@\n context\n";
    const hunks = try parsePatch(std.testing.allocator, diff);
    defer std.testing.allocator.free(hunks);
    try std.testing.expectEqual(@as(usize, 1), hunks.len);
}
