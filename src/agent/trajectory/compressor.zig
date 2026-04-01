const std = @import("std");
const format = @import("format.zig");
const core_types = @import("../../core/types.zig");

/// Compress a trajectory by removing system messages and merging consecutive
/// assistant messages with no tool calls.
pub fn compress(allocator: std.mem.Allocator, trajectory: format.Trajectory) !format.Trajectory {
    var kept = std.ArrayList(format.Turn).init(allocator);
    defer kept.deinit();

    for (trajectory.turns) |turn| {
        // Remove system messages (reconstructible)
        if (turn.role == .system) continue;

        // Merge consecutive assistant messages with no tool calls
        if (turn.role == .assistant and turn.tool_calls.len == 0 and kept.items.len > 0) {
            const last = &kept.items[kept.items.len - 1];
            if (last.role == .assistant and last.tool_calls.len == 0) {
                continue; // skip duplicate assistant turn
            }
        }

        try kept.append(turn);
    }

    const turns = try allocator.dupe(format.Turn, kept.items);
    return .{
        .session_id = trajectory.session_id,
        .model = trajectory.model,
        .turns = turns,
        .metadata = trajectory.metadata,
    };
}

test "compress removes system messages" {
    const turns = [_]format.Turn{
        .{ .role = .system, .content = "sys" },
        .{ .role = .user, .content = "hi" },
        .{ .role = .assistant, .content = "hello" },
    };
    const traj = format.Trajectory{ .turns = &turns };
    const result = try compress(std.testing.allocator, traj);
    defer std.testing.allocator.free(result.turns);
    try std.testing.expectEqual(@as(usize, 2), result.turns.len);
    try std.testing.expectEqual(core_types.Role.user, result.turns[0].role);
}
