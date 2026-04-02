const std = @import("std");

pub fn formatTimestamp(allocator: std.mem.Allocator, unix_ms: i64) ![]u8 {
    const secs: u64 = @intCast(@divTrunc(unix_ms, 1000));
    const es = std.time.epoch.EpochSeconds{ .secs = secs };
    const day = es.getEpochDay();
    const yd = day.calculateYearDay();
    const md = yd.calculateMonthDay();
    const ds = es.getDaySeconds();
    return try std.fmt.allocPrint(allocator, "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}", .{
        yd.year, @intFromEnum(md.month), md.day_index + 1, ds.getHoursIntoDay(), ds.getMinutesIntoHour(), ds.getSecondsIntoMinute(),
    });
}

pub fn relativeTime(allocator: std.mem.Allocator, unix_ms: i64) ![]u8 {
    const now_ms: i64 = @intCast(std.time.milliTimestamp());
    const diff_secs: u64 = @intCast(@max(0, @divTrunc(now_ms - unix_ms, 1000)));
    if (diff_secs < 60) return try std.fmt.allocPrint(allocator, "{d} seconds ago", .{diff_secs});
    if (diff_secs < 3600) return try std.fmt.allocPrint(allocator, "{d} minutes ago", .{diff_secs / 60});
    if (diff_secs < 86400) return try std.fmt.allocPrint(allocator, "{d} hours ago", .{diff_secs / 3600});
    return try std.fmt.allocPrint(allocator, "{d} days ago", .{diff_secs / 86400});
}

test "formatTimestamp known value" {
    // 2024-01-01 00:00:00 UTC = 1704067200000 ms
    const result = try formatTimestamp(std.testing.allocator, 1704067200000);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("2024-01-01 00:00:00", result);
}

test "relativeTime returns non-empty" {
    const result = try relativeTime(std.testing.allocator, 0);
    defer std.testing.allocator.free(result);
    try std.testing.expect(result.len > 0);
}
