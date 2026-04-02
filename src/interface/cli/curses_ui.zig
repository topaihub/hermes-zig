const std = @import("std");

pub fn runInteractiveSelect(allocator: std.mem.Allocator, items: []const []const u8, stdout: std.fs.File) !?usize {
    // Text fallback: print numbered list
    for (items, 1..) |item, i| {
        const msg = try std.fmt.allocPrint(allocator, "  {d}) {s}\n", .{ i, item });
        defer allocator.free(msg);
        try stdout.writeAll(msg);
    }
    _ = items.len;
    return if (items.len > 0) 0 else null;
}

test "runInteractiveSelect exists" {
    try std.testing.expect(@TypeOf(runInteractiveSelect) != void);
}
