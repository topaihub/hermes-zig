const std = @import("std");

pub const CheckResult = struct {
    name: []const u8,
    passed: bool,
    message: []const u8,
};

pub const Doctor = struct {
    pub fn runChecks(allocator: std.mem.Allocator) ![]CheckResult {
        _ = allocator;
        return &.{};
    }
};

test "Doctor runChecks returns empty" {
    const results = try Doctor.runChecks(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), results.len);
}
