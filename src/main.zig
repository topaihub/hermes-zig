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

test "Config defaults are correct" {
    const cfg = core.Config{};
    try std.testing.expectEqualStrings("openrouter/nous-hermes", cfg.model);
    try std.testing.expectEqualStrings("openrouter", cfg.provider);
    try std.testing.expect(cfg.temperature == 0.7);
    try std.testing.expectEqual(null, cfg.max_tokens);
    try std.testing.expectEqual(false, cfg.reasoning.enabled);
    try std.testing.expectEqualStrings("medium", cfg.reasoning.effort);
    try std.testing.expectEqual(true, cfg.security.command_approval);
    try std.testing.expectEqual(true, cfg.memory.enabled);
    try std.testing.expectEqual(@as(u32, 10), cfg.memory.nudge_interval);
}

test "JSON parsing works" {
    const json = "{\"model\": \"gpt-4\", \"temperature\": 0.5}";
    var loaded = try core.config_loader.loadFromString(json, std.testing.allocator);
    defer loaded.deinit();
    try std.testing.expectEqualStrings("gpt-4", loaded.parsed.value.model);
    try std.testing.expect(loaded.parsed.value.temperature == 0.5);
}

test "Empty JSON uses all defaults" {
    var loaded = try core.config_loader.loadFromString("{}", std.testing.allocator);
    defer loaded.deinit();
    try std.testing.expectEqualStrings("openrouter/nous-hermes", loaded.parsed.value.model);
    try std.testing.expect(loaded.parsed.value.temperature == 0.7);
}

test "Soul loading returns null when file doesn't exist" {
    const result = try core.soul.loadSoul(std.testing.allocator, "/tmp/nonexistent-hermes-test-dir");
    try std.testing.expectEqual(null, result);
}
