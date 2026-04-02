const std = @import("std");
const core_types = @import("../core/types.zig");

pub fn generateTitle(allocator: std.mem.Allocator, messages: []const core_types.Message) ![]u8 {
    for (messages) |msg| {
        if (msg.role == .user and msg.content.len > 0) {
            const len = @min(msg.content.len, 50);
            return try allocator.dupe(u8, msg.content[0..len]);
        }
    }
    return try allocator.dupe(u8, "New conversation");
}

test "generateTitle from user message" {
    const msgs = &[_]core_types.Message{
        .{ .role = .system, .content = "system" },
        .{ .role = .user, .content = "How do I write a Zig build script?" },
    };
    const title = try generateTitle(std.testing.allocator, msgs);
    defer std.testing.allocator.free(title);
    try std.testing.expect(title.len > 0);
    try std.testing.expectEqualStrings("How do I write a Zig build script?", title);
}
