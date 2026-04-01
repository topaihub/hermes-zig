const backend = @import("backend.zig");
const ExecResult = backend.ExecResult;
const std = @import("std");

pub const ModalBackend = struct {
    pub fn execute(_: *ModalBackend, allocator: std.mem.Allocator, _: []const u8, _: []const u8, _: u64) !ExecResult {
        return .{
            .stdout = try allocator.dupe(u8, ""),
            .stderr = try allocator.dupe(u8, "Modal backend is not yet implemented"),
            .exit_code = 1,
            .allocator = allocator,
        };
    }

    pub fn cleanup(_: *ModalBackend) !void {}
};
