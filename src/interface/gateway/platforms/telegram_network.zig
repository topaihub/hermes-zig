const std = @import("std");

pub const TelegramNetwork = struct {
    bot_token: []const u8,
    base_url: []const u8 = "https://api.telegram.org",

    pub fn init(bot_token: []const u8) TelegramNetwork {
        return .{ .bot_token = bot_token };
    }

    pub fn sendMessage(self: *TelegramNetwork, allocator: std.mem.Allocator, chat_id: []const u8, text: []const u8) ![]u8 {
        _ = self;
        return std.fmt.allocPrint(allocator, "[stub] sent to {s}: {s}", .{ chat_id, text });
    }

    pub fn getUpdates(self: *TelegramNetwork, allocator: std.mem.Allocator, offset: i64) ![]u8 {
        _ = self;
        return std.fmt.allocPrint(allocator, "[stub] updates from offset {d}", .{offset});
    }
};

test "TelegramNetwork init" {
    const net = TelegramNetwork.init("bot123:ABC");
    try std.testing.expectEqualStrings("bot123:ABC", net.bot_token);
}

test "TelegramNetwork sendMessage stub" {
    var net = TelegramNetwork.init("bot123:ABC");
    const result = try net.sendMessage(std.testing.allocator, "12345", "hello");
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "12345") != null);
}
