const std = @import("std");

pub const CronExpression = struct {
    minute: ?u8 = null,
    hour: ?u8 = null,
    day: ?u8 = null,
    month: ?u8 = null,
    weekday: ?u8 = null,
};

pub fn parseCronExpression(expr: []const u8) !CronExpression {
    var result = CronExpression{};
    var iter = std.mem.splitScalar(u8, expr, ' ');
    const fields = [_]*?u8{ &result.minute, &result.hour, &result.day, &result.month, &result.weekday };
    for (&fields) |field| {
        const token = iter.next() orelse return error.InvalidCronExpression;
        const trimmed = std.mem.trim(u8, token, " \t");
        if (!std.mem.eql(u8, trimmed, "*")) {
            field.* = std.fmt.parseInt(u8, trimmed, 10) catch return error.InvalidCronExpression;
        }
    }
    return result;
}

pub fn shouldRun(expr: CronExpression, minute: u8, hour: u8, day: u8, month: u8, weekday: u8) bool {
    if (expr.minute) |m| if (m != minute) return false;
    if (expr.hour) |h| if (h != hour) return false;
    if (expr.day) |d| if (d != day) return false;
    if (expr.month) |mo| if (mo != month) return false;
    if (expr.weekday) |w| if (w != weekday) return false;
    return true;
}

pub const CronJob = struct {
    name: []const u8,
    expression: CronExpression,
};

pub const CronScheduler = struct {
    jobs: std.ArrayList(CronJob),

    pub fn init(allocator: std.mem.Allocator) CronScheduler {
        return .{ .jobs = std.ArrayList(CronJob).init(allocator) };
    }

    pub fn deinit(self: *CronScheduler) void {
        self.jobs.deinit();
    }

    pub fn addJob(self: *CronScheduler, name: []const u8, expr: CronExpression) !void {
        try self.jobs.append(.{ .name = name, .expression = expr });
    }

    pub fn checkDueJobs(self: *const CronScheduler, allocator: std.mem.Allocator, minute: u8, hour: u8, day: u8, month: u8, weekday: u8) ![]usize {
        var due = std.ArrayList(usize).init(allocator);
        errdefer due.deinit();
        for (self.jobs.items, 0..) |job, i| {
            if (shouldRun(job.expression, minute, hour, day, month, weekday)) try due.append(i);
        }
        return due.toOwnedSlice();
    }
};

test "parseCronExpression parses specific values" {
    const expr = try parseCronExpression("30 2 * * 1");
    try std.testing.expectEqual(@as(?u8, 30), expr.minute);
    try std.testing.expectEqual(@as(?u8, 2), expr.hour);
    try std.testing.expectEqual(@as(?u8, null), expr.day);
    try std.testing.expectEqual(@as(?u8, null), expr.month);
    try std.testing.expectEqual(@as(?u8, 1), expr.weekday);
}

test "shouldRun matches correctly" {
    const expr = try parseCronExpression("30 2 * * 1");
    try std.testing.expect(shouldRun(expr, 30, 2, 15, 6, 1));
    try std.testing.expect(!shouldRun(expr, 31, 2, 15, 6, 1));
    try std.testing.expect(!shouldRun(expr, 30, 3, 15, 6, 1));
    try std.testing.expect(!shouldRun(expr, 30, 2, 15, 6, 2));
}

test "CronScheduler checkDueJobs" {
    var sched = CronScheduler.init(std.testing.allocator);
    defer sched.deinit();
    try sched.addJob("backup", try parseCronExpression("0 3 * * *"));
    try sched.addJob("cleanup", try parseCronExpression("30 2 * * 1"));
    const due = try sched.checkDueJobs(std.testing.allocator, 0, 3, 1, 1, 0);
    defer std.testing.allocator.free(due);
    try std.testing.expectEqual(@as(usize, 1), due.len);
    try std.testing.expectEqual(@as(usize, 0), due[0]);
}
