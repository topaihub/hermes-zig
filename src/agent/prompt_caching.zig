const core_types = @import("../core/types.zig");

/// Anthropic prompt caching: mark stable prompt blocks with cache hints.
/// System prompt and tool schemas rarely change, so they get cache_control.
pub const CacheHint = struct {
    message_index: usize,
    cache_type: []const u8 = "ephemeral",
};

/// Identify which messages should be cached (system messages, early context).
pub fn identifyCacheableMessages(messages: []const core_types.Message) []const CacheHint {
    const S = struct {
        var hints: [8]CacheHint = undefined;
    };
    var count: usize = 0;
    for (messages, 0..) |msg, i| {
        if (msg.role == .system and count < S.hints.len) {
            S.hints[count] = .{ .message_index = i };
            count += 1;
        }
    }
    return S.hints[0..count];
}

test "system messages get cache hints" {
    const msgs = [_]core_types.Message{
        .{ .role = .system, .content = "you are helpful" },
        .{ .role = .user, .content = "hello" },
        .{ .role = .assistant, .content = "hi" },
        .{ .role = .system, .content = "extra context" },
    };
    const hints = identifyCacheableMessages(&msgs);
    try @import("std").testing.expectEqual(@as(usize, 2), hints.len);
    try @import("std").testing.expectEqual(@as(usize, 0), hints[0].message_index);
    try @import("std").testing.expectEqual(@as(usize, 3), hints[1].message_index);
}

test "non-system messages get no hints" {
    const msgs = [_]core_types.Message{
        .{ .role = .user, .content = "hello" },
        .{ .role = .assistant, .content = "hi" },
    };
    const hints = identifyCacheableMessages(&msgs);
    try @import("std").testing.expectEqual(@as(usize, 0), hints.len);
}
