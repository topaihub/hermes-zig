const std = @import("std");
const core_types = @import("../core/types.zig");

pub const SessionInsights = struct {
    total_tokens: u32,
    total_cost: f64,
    tool_calls: u32,
    duration_ms: i64,

    pub fn fromSession(usage: core_types.TokenUsage, tool_calls: u32, start_ms: i64) SessionInsights {
        const time_utils = @import("../core/time_utils.zig");
        const now = time_utils.getCurrentTimestamp();
        return .{
            .total_tokens = usage.total_tokens,
            .total_cost = @as(f64, @floatFromInt(usage.total_tokens)) * 0.00001,
            .tool_calls = tool_calls,
            .duration_ms = now - start_ms,
        };
    }
};

test "SessionInsights fromSession" {
    const usage = core_types.TokenUsage{ .prompt_tokens = 100, .completion_tokens = 50, .total_tokens = 150 };
    const insights = SessionInsights.fromSession(usage, 3, 0);
    try std.testing.expectEqual(@as(u32, 150), insights.total_tokens);
    try std.testing.expectEqual(@as(u32, 3), insights.tool_calls);
    try std.testing.expect(insights.duration_ms > 0);
    try std.testing.expect(insights.total_cost > 0);
}
