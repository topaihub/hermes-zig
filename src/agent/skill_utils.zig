const std = @import("std");

pub fn parseFrontmatter(allocator: std.mem.Allocator, content: []const u8) !std.StringHashMap([]const u8) {
    var map = std.StringHashMap([]const u8).init(allocator);
    errdefer {
        var it = map.iterator();
        while (it.next()) |e| {
            allocator.free(e.key_ptr.*);
            allocator.free(e.value_ptr.*);
        }
        map.deinit();
    }

    if (!std.mem.startsWith(u8, content, "---")) return map;
    const after_first = content[3..];
    const end = std.mem.indexOf(u8, after_first, "---") orelse return map;
    const block = std.mem.trim(u8, after_first[0..end], " \t\r\n");

    var lines = std.mem.splitScalar(u8, block, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        const key = std.mem.trim(u8, line[0..colon], " \t");
        const val = std.mem.trim(u8, line[colon + 1 ..], " \t");
        if (key.len == 0) continue;
        try map.put(try allocator.dupe(u8, key), try allocator.dupe(u8, val));
    }
    return map;
}

pub fn extractDescription(content: []const u8) []const u8 {
    // Skip frontmatter if present
    var body = content;
    if (std.mem.startsWith(u8, body, "---")) {
        const after = body[3..];
        if (std.mem.indexOf(u8, after, "---")) |end| {
            body = std.mem.trim(u8, after[end + 3 ..], " \t\r\n");
        }
    }
    // Return first paragraph (up to double newline or end)
    if (std.mem.indexOf(u8, body, "\n\n")) |end| return body[0..end];
    return body;
}

fn deinitMap(allocator: std.mem.Allocator, map: *std.StringHashMap([]const u8)) void {
    var it = map.iterator();
    while (it.next()) |e| {
        allocator.free(e.key_ptr.*);
        allocator.free(e.value_ptr.*);
    }
    map.deinit();
}

test "parse frontmatter between --- markers" {
    const content =
        \\---
        \\name: test-skill
        \\version: 1.0
        \\---
        \\This is the description.
    ;
    var map = try parseFrontmatter(std.testing.allocator, content);
    defer deinitMap(std.testing.allocator, &map);
    try std.testing.expectEqualStrings("test-skill", map.get("name").?);
    try std.testing.expectEqualStrings("1.0", map.get("version").?);
}

test "extractDescription skips frontmatter" {
    const content =
        \\---
        \\name: test
        \\---
        \\First paragraph here.
        \\
        \\Second paragraph.
    ;
    const desc = extractDescription(content);
    try std.testing.expectEqualStrings("First paragraph here.", desc);
}
