const core_types = @import("../../core/types.zig");

pub const Trajectory = struct {
    session_id: []const u8 = "",
    model: []const u8 = "",
    turns: []const Turn = &.{},
    metadata: TrajectoryMetadata = .{},
};

pub const Turn = struct {
    role: core_types.Role = .user,
    content: []const u8 = "",
    tool_calls: []const core_types.ToolCall = &.{},
    timestamp: i64 = 0,
};

pub const TrajectoryMetadata = struct {
    total_tokens: u32 = 0,
    total_turns: u32 = 0,
    duration_seconds: u32 = 0,
    success: bool = false,
};

test "metadata defaults" {
    const m = TrajectoryMetadata{};
    const std = @import("std");
    try std.testing.expectEqual(@as(u32, 0), m.total_tokens);
    try std.testing.expectEqual(@as(u32, 0), m.total_turns);
    try std.testing.expectEqual(@as(u32, 0), m.duration_seconds);
    try std.testing.expectEqual(false, m.success);
}

test "trajectory defaults" {
    const t = Trajectory{};
    try @import("std").testing.expectEqualStrings("", t.session_id);
    try @import("std").testing.expectEqual(@as(usize, 0), t.turns.len);
}
