const std = @import("std");

pub const ChecklistItem = struct {
    label: []const u8,
    checked: bool = false,
};

pub fn runChecklist(allocator: std.mem.Allocator, items: []ChecklistItem, stdout: std.fs.File, stdin: std.fs.File) !void {
    var buf: [64]u8 = undefined;
    while (true) {
        for (items, 1..) |item, i| {
            const mark: []const u8 = if (item.checked) "[x]" else "[ ]";
            const msg = try std.fmt.allocPrint(allocator, "  {d}. {s} {s}\n", .{ i, mark, item.label });
            defer allocator.free(msg);
            try stdout.writeAll(msg);
        }
        try stdout.writeAll("  Toggle # (empty to confirm): ");
        var n: usize = 0;
        while (n < buf.len) {
            const r = stdin.read(buf[n .. n + 1]) catch return;
            if (r == 0) return;
            if (buf[n] == '\n') break;
            n += 1;
        }
        const line = std.mem.trim(u8, buf[0..n], " \t\r");
        if (line.len == 0) return;
        const idx = std.fmt.parseInt(usize, line, 10) catch continue;
        if (idx >= 1 and idx <= items.len) items[idx - 1].checked = !items[idx - 1].checked;
    }
}

test "ChecklistItem init" {
    const item = ChecklistItem{ .label = "test" };
    try std.testing.expectEqualStrings("test", item.label);
    try std.testing.expect(!item.checked);
}
