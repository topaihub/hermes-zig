const std = @import("std");
const format = @import("format.zig");

pub const BatchRunner = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) BatchRunner {
        return .{ .allocator = allocator };
    }

    /// Stub: run a batch of tasks and return trajectories.
    pub fn runBatch(self: *BatchRunner, tasks: []const []const u8) ![]format.Trajectory {
        const results = try self.allocator.alloc(format.Trajectory, tasks.len);
        for (results, 0..) |*r, i| {
            _ = i;
            r.* = .{};
        }
        return results;
    }

    pub fn deinit(self: *BatchRunner) void {
        _ = self;
    }
};

test "BatchRunner init" {
    var runner = BatchRunner.init(std.testing.allocator);
    defer runner.deinit();
    const tasks = [_][]const u8{ "task1", "task2" };
    const results = try runner.runBatch(&tasks);
    defer std.testing.allocator.free(results);
    try std.testing.expectEqual(@as(usize, 2), results.len);
}
