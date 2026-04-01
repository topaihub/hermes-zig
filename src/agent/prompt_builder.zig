const std = @import("std");
const core_config = @import("../core/config.zig");
const injection = @import("../security/injection.zig");
const log = std.log.scoped(.prompt_builder);

pub fn buildSystemPrompt(allocator: std.mem.Allocator, config: *const core_config.Config, soul_content: ?[]const u8) ![]u8 {
    var parts = std.ArrayList([]const u8).init(allocator);
    defer parts.deinit();

    if (soul_content) |soul| {
        // Scan for injection in context content
        if (injection.scanForInjection(soul) != null) {
            log.warn("Injection pattern detected in soul content", .{});
        }
        try parts.append(soul);
    } else {
        try parts.append("You are a helpful AI assistant.");
    }

    if (config.personality.len > 0) {
        try parts.append("\n\n");
        try parts.append(config.personality);
    }

    try parts.append("\n\nWhen using tools, provide the required arguments as JSON. Report tool results to the user clearly.");
    try parts.append("\n\nPlatform: CLI");

    return std.mem.concat(allocator, u8, parts.items);
}

test "buildSystemPrompt produces non-empty output" {
    const cfg = core_config.Config{};
    const result = try buildSystemPrompt(std.testing.allocator, &cfg, null);
    defer std.testing.allocator.free(result);
    try std.testing.expect(result.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, result, "helpful AI assistant") != null);
}

test "buildSystemPrompt includes soul content" {
    const cfg = core_config.Config{};
    const result = try buildSystemPrompt(std.testing.allocator, &cfg, "I am Hermes.");
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "I am Hermes.") != null);
}
