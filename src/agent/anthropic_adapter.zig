const std = @import("std");

pub fn getMaxOutput(model: []const u8) u32 {
    if (std.mem.indexOf(u8, model, "opus") != null) return 4096;
    if (std.mem.indexOf(u8, model, "sonnet") != null) return 8192;
    return 4096;
}

pub fn supportsAdaptiveThinking(model: []const u8) bool {
    return std.mem.indexOf(u8, model, "claude") != null;
}

pub fn isOAuthToken(key: []const u8) bool {
    return std.mem.startsWith(u8, key, "oa-");
}

test "getMaxOutput for known models" {
    try std.testing.expectEqual(@as(u32, 8192), getMaxOutput("claude-sonnet-4"));
    try std.testing.expectEqual(@as(u32, 4096), getMaxOutput("claude-opus-4"));
    try std.testing.expectEqual(@as(u32, 4096), getMaxOutput("unknown-model"));
}

test "supportsAdaptiveThinking" {
    try std.testing.expect(supportsAdaptiveThinking("claude-sonnet-4"));
    try std.testing.expect(!supportsAdaptiveThinking("gpt-4o"));
}

test "isOAuthToken" {
    try std.testing.expect(isOAuthToken("oa-abc123"));
    try std.testing.expect(!isOAuthToken("sk-abc123"));
}
