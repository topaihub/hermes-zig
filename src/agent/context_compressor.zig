const std = @import("std");
const core_types = @import("../core/types.zig");

pub fn compress(allocator: std.mem.Allocator, messages: []const core_types.Message, max_tokens: u32) ![]core_types.Message {
    const char_budget = @as(usize, max_tokens) * 4;

    // Calculate total chars
    var total: usize = 0;
    for (messages) |m| total += m.content.len;

    if (total <= char_budget) {
        return try allocator.dupe(core_types.Message, messages);
    }

    // Keep system messages and trim oldest non-system messages
    var result = std.ArrayList(core_types.Message).empty;

    // First pass: collect system messages
    for (messages) |m| {
        if (m.role == .system) try result.append(allocator, m);
    }

    // Second pass: collect non-system from the end until budget
    var kept = std.ArrayList(core_types.Message).empty;
    defer kept.deinit(allocator);
    var used: usize = 0;
    for (result.items) |m| used += m.content.len;

    var i = messages.len;
    while (i > 0) {
        i -= 1;
        if (messages[i].role == .system) continue;
        if (used + messages[i].content.len > char_budget) break;
        used += messages[i].content.len;
        try kept.append(allocator, messages[i]);
    }

    // Reverse kept to restore order
    std.mem.reverse(core_types.Message, kept.items);
    try result.appendSlice(allocator, kept.items);

    return result.toOwnedSlice(allocator);
}

test "compress keeps all messages when under limit" {
    const msgs = &[_]core_types.Message{
        .{ .role = .system, .content = "sys" },
        .{ .role = .user, .content = "hi" },
    };
    const result = try compress(std.testing.allocator, msgs, 1000);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqual(@as(usize, 2), result.len);
}

test "compress removes old messages when over limit" {
    const msgs = &[_]core_types.Message{
        .{ .role = .system, .content = "sys" },
        .{ .role = .user, .content = "a" ** 100 },
        .{ .role = .assistant, .content = "b" ** 100 },
        .{ .role = .user, .content = "c" ** 100 },
    };
    // Budget = 10 * 4 = 40 chars — only system + last message should fit
    const result = try compress(std.testing.allocator, msgs, 10);
    defer std.testing.allocator.free(result);
    try std.testing.expect(result.len < msgs.len);
    // System message always kept
    try std.testing.expectEqual(core_types.Role.system, result[0].role);
}
