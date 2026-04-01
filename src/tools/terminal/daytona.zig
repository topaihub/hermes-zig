const backend = @import("backend.zig");
const ExecResult = backend.ExecResult;
const std = @import("std");

pub const DaytonaBackend = struct {
    pub fn execute(_: *DaytonaBackend, _: std.mem.Allocator, _: []const u8, _: []const u8, _: u64) !ExecResult {
        return error.NotImplemented;
    }

    pub fn cleanup(_: *DaytonaBackend) !void {}
};
