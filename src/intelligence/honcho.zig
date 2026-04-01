const std = @import("std");

pub const HonchoClient = struct {
    base_url: []const u8,
    api_key: []const u8,

    pub fn init(base_url: []const u8, api_key: []const u8) HonchoClient {
        return .{ .base_url = base_url, .api_key = api_key };
    }

    pub fn getUserContext(self: *HonchoClient, allocator: std.mem.Allocator, user_id: []const u8) ![]u8 {
        _ = self;
        return std.fmt.allocPrint(allocator, "[stub] user context for {s}", .{user_id});
    }

    pub fn updateUserModel(self: *HonchoClient, allocator: std.mem.Allocator, user_id: []const u8, data: []const u8) ![]u8 {
        _ = self;
        return std.fmt.allocPrint(allocator, "[stub] updated model for {s}: {s}", .{ user_id, data });
    }
};

test "HonchoClient init" {
    const client = HonchoClient.init("https://api.honcho.dev", "key");
    try std.testing.expectEqualStrings("https://api.honcho.dev", client.base_url);
}

test "HonchoClient getUserContext stub" {
    var client = HonchoClient.init("https://api.honcho.dev", "key");
    const result = try client.getUserContext(std.testing.allocator, "user1");
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "user1") != null);
}

test "HonchoClient updateUserModel stub" {
    var client = HonchoClient.init("https://api.honcho.dev", "key");
    const result = try client.updateUserModel(std.testing.allocator, "user1", "{}");
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "user1") != null);
}
