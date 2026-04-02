const std = @import("std");

pub const TelegramNetwork = struct {
    bot_token: []const u8,
    base_url: []const u8 = "https://api.telegram.org",

    pub fn init(bot_token: []const u8) TelegramNetwork {
        return .{ .bot_token = bot_token };
    }

    pub fn sendMessage(self: *TelegramNetwork, allocator: std.mem.Allocator, chat_id: []const u8, text: []const u8) ![]u8 {
        // POST {base_url}/bot{token}/sendMessage
        // Body: {"chat_id": chat_id, "text": text, "parse_mode": "Markdown"}
        return std.fmt.allocPrint(allocator, "POST {s}/bot{s}/sendMessage chat_id={s} text_len={d}", .{ self.base_url, self.bot_token, chat_id, text.len });
    }

    pub fn getUpdates(self: *TelegramNetwork, allocator: std.mem.Allocator, offset: i64) ![]u8 {
        // GET {base_url}/bot{token}/getUpdates?offset={offset}&timeout=30
        return std.fmt.allocPrint(allocator, "GET {s}/bot{s}/getUpdates?offset={d}&timeout=30", .{ self.base_url, self.bot_token, offset });
    }
};

test "TelegramNetwork init" {
    const net = TelegramNetwork.init("bot123:ABC");
    try std.testing.expectEqualStrings("bot123:ABC", net.bot_token);
}

test "TelegramNetwork sendMessage" {
    var net = TelegramNetwork.init("bot123:ABC");
    const result = try net.sendMessage(std.testing.allocator, "12345", "hello");
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "12345") != null);
}
