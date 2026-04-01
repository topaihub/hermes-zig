const std = @import("std");

pub const SkillsHubClient = struct {
    base_url: []const u8,

    pub fn init(base_url: []const u8) SkillsHubClient {
        return .{ .base_url = base_url };
    }

    pub fn search(self: *SkillsHubClient, allocator: std.mem.Allocator, query: []const u8) ![]u8 {
        _ = self;
        return std.fmt.allocPrint(allocator, "[stub] search results for: {s}", .{query});
    }

    pub fn download(self: *SkillsHubClient, allocator: std.mem.Allocator, skill_id: []const u8) ![]u8 {
        _ = self;
        return std.fmt.allocPrint(allocator, "[stub] downloaded skill: {s}", .{skill_id});
    }
};

test "SkillsHubClient init" {
    const client = SkillsHubClient.init("https://hub.hermes.ai");
    try std.testing.expectEqualStrings("https://hub.hermes.ai", client.base_url);
}

test "SkillsHubClient search stub" {
    var client = SkillsHubClient.init("https://hub.hermes.ai");
    const result = try client.search(std.testing.allocator, "coding");
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "coding") != null);
}

test "SkillsHubClient download stub" {
    var client = SkillsHubClient.init("https://hub.hermes.ai");
    const result = try client.download(std.testing.allocator, "skill-123");
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "skill-123") != null);
}
