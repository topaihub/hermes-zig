const std = @import("std");
const framework = @import("framework");
pub const core = @import("core/root.zig");

pub fn main() !void {
    std.debug.print("hermes-zig\n", .{});
}

test "framework import" {
    _ = framework;
}

test "Platform.displayName returns non-empty strings" {
    inline for (comptime std.enums.values(core.Platform)) |p| {
        const name = p.displayName();
        try std.testing.expect(name.len > 0);
    }
}

test "Message defaults are correct" {
    const msg = core.Message{};
    try std.testing.expectEqual(core.Role.user, msg.role);
    try std.testing.expectEqualStrings("", msg.content);
    try std.testing.expectEqual(null, msg.tool_call_id);
    try std.testing.expectEqual(null, msg.name);
}

test "SessionSource construction works" {
    const src = core.SessionSource{
        .platform = .telegram,
        .chat_id = "123",
        .user_id = "u1",
    };
    try std.testing.expectEqual(core.Platform.telegram, src.platform);
    try std.testing.expectEqualStrings("123", src.chat_id);
    try std.testing.expectEqualStrings("u1", src.user_id.?);
    try std.testing.expectEqual(null, src.thread_id);
}
