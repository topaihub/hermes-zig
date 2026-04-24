const std = @import("std");
const builtin = @import("builtin");

/// Get current time in nanoseconds since epoch
fn nowNanoseconds() i128 {
    return switch (builtin.os.tag) {
        .windows => blk: {
            const epoch_ns = std.time.epoch.windows * std.time.ns_per_s;
            break :blk @as(i128, std.os.windows.ntdll.RtlGetSystemTimePrecise()) * 100 + epoch_ns;
        },
        .wasi => blk: {
            var ts: std.os.wasi.timestamp_t = undefined;
            if (std.os.wasi.clock_time_get(.REALTIME, 1, &ts) == .SUCCESS) {
                break :blk @intCast(ts);
            }
            break :blk 0;
        },
        else => blk: {
            var ts: std.posix.timespec = undefined;
            switch (std.posix.errno(std.posix.system.clock_gettime(.REALTIME, &ts))) {
                .SUCCESS => break :blk @as(i128, ts.sec) * std.time.ns_per_s + ts.nsec,
                else => break :blk 0,
            }
        },
    };
}

/// Get current Unix timestamp in seconds
pub fn getCurrentTimestamp() i64 {
    return @intCast(@divTrunc(nowNanoseconds(), std.time.ns_per_s));
}

/// Get current timestamp in milliseconds
pub fn milliTimestamp() i64 {
    return @intCast(@divTrunc(nowNanoseconds(), std.time.ns_per_ms));
}

/// Format a Unix timestamp as ISO 8601 string (YYYY-MM-DDTHH:MM:SSZ)
pub fn formatTimestamp(allocator: std.mem.Allocator, timestamp: i64) ![]u8 {
    const epoch_seconds: u64 = @intCast(timestamp);
    const epoch_day: u47 = @intCast(epoch_seconds / std.time.s_per_day);
    const day_seconds = epoch_seconds % std.time.s_per_day;

    const year_day = std.time.epoch.EpochDay{ .day = epoch_day };
    const year = year_day.calculateYearDay();
    const month_day = year.calculateMonthDay();

    const hours = day_seconds / std.time.s_per_hour;
    const minutes = (day_seconds % std.time.s_per_hour) / std.time.s_per_min;
    const seconds = day_seconds % std.time.s_per_min;

    return try std.fmt.allocPrint(
        allocator,
        "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}Z",
        .{
            year.year,
            month_day.month.numeric(),
            month_day.day_index + 1,
            hours,
            minutes,
            seconds,
        },
    );
}

test "formatTimestamp produces valid ISO 8601" {
    const allocator = std.testing.allocator;
    
    // Test known timestamp: 2024-01-15 13:10:45 UTC
    const timestamp: i64 = 1705324245;
    const formatted = try formatTimestamp(allocator, timestamp);
    defer allocator.free(formatted);
    
    try std.testing.expectEqualStrings("2024-01-15T13:10:45Z", formatted);
}

test "formatTimestamp handles epoch zero" {
    const allocator = std.testing.allocator;
    
    const formatted = try formatTimestamp(allocator, 0);
    defer allocator.free(formatted);
    
    try std.testing.expectEqualStrings("1970-01-01T00:00:00Z", formatted);
}

test "getCurrentTimestamp returns positive value" {
    const ts = getCurrentTimestamp();
    try std.testing.expect(ts > 0);
}

test "milliTimestamp returns positive value" {
    const ts = milliTimestamp();
    try std.testing.expect(ts > 0);
}
