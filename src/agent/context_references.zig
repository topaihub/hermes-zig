const std = @import("std");

pub const Reference = struct { path: []const u8 };

pub fn parseReferences(allocator: std.mem.Allocator, message: []const u8) ![]Reference {
    var refs = std.ArrayList(Reference).init(allocator);
    var i: usize = 0;
    while (i < message.len) {
        if (message[i] == '@') {
            const start = i + 1;
            var end = start;
            while (end < message.len and message[end] != ' ' and message[end] != '\n') : (end += 1) {}
            if (end > start) try refs.append(.{ .path = message[start..end] });
            i = end;
        } else i += 1;
    }
    return refs.toOwnedSlice();
}

pub fn expandReference(allocator: std.mem.Allocator, ref: Reference, working_dir: []const u8) ![]u8 {
    const full = try std.fs.path.join(allocator, &.{ working_dir, ref.path });
    defer allocator.free(full);
    return std.fs.cwd().readFileAlloc(allocator, full, 1024 * 1024) catch
        try std.fmt.allocPrint(allocator, "[Could not read: {s}]", .{ref.path});
}

test "parseReferences extracts path" {
    const refs = try parseReferences(std.testing.allocator, "look at @src/main.zig please");
    defer std.testing.allocator.free(refs);
    try std.testing.expectEqual(@as(usize, 1), refs.len);
    try std.testing.expectEqualStrings("src/main.zig", refs[0].path);
}
