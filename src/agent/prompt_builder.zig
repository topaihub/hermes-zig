const std = @import("std");
const core_config = @import("../core/config.zig");
const skills_loader = @import("../intelligence/skills_loader.zig");
const injection = @import("../security/injection.zig");
const log = std.log.scoped(.prompt_builder);

pub fn buildSystemPrompt(
    allocator: std.mem.Allocator,
    config: *const core_config.Config,
    soul_content: ?[]const u8,
    active_skill: ?*const skills_loader.SkillDefinition,
) ![]u8 {
    var parts: std.ArrayList([]const u8) = .empty;
    defer parts.deinit(allocator);

    if (soul_content) |soul| {
        // Scan for injection in context content
        if (injection.scanForInjection(soul) != null) {
            log.warn("Injection pattern detected in soul content", .{});
        }
        try parts.append(allocator, soul);
    } else {
        try parts.append(allocator, "You are a helpful AI assistant.");
    }

    if (config.personality.len > 0) {
        try parts.append(allocator, "\n\n");
        try parts.append(allocator, config.personality);
    }

    if (active_skill) |skill| {
        if (skill.body.len > 0) {
            if (injection.scanForInjection(skill.body) != null) {
                log.warn("Injection pattern detected in active skill body", .{});
            }
            try parts.append(allocator, "\n\n## Active Skill\n");
            try parts.append(allocator, "Name: ");
            try parts.append(allocator, skill.name);
            if (skill.description.len > 0) {
                try parts.append(allocator, "\nDescription: ");
                try parts.append(allocator, skill.description);
            }
            try parts.append(allocator, "\n\n");
            try parts.append(allocator, skill.body);
        }
    }

    try parts.append(allocator, "\n\nWhen using tools, provide the required arguments as JSON. Report tool results to the user clearly.");
    try parts.append(allocator, "\n\nPlatform: CLI");

    return std.mem.concat(allocator, u8, parts.items);
}

test "buildSystemPrompt produces non-empty output" {
    const cfg = core_config.Config{};
    const result = try buildSystemPrompt(std.testing.allocator, &cfg, null, null);
    defer std.testing.allocator.free(result);
    try std.testing.expect(result.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, result, "helpful AI assistant") != null);
}

test "buildSystemPrompt includes soul content" {
    const cfg = core_config.Config{};
    const result = try buildSystemPrompt(std.testing.allocator, &cfg, "I am Hermes.", null);
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "I am Hermes.") != null);
}

test "buildSystemPrompt includes active skill body" {
    const cfg = core_config.Config{};
    const skill = skills_loader.SkillDefinition{
        .name = "poetry",
        .description = "Write poems",
        .body = "Prefer classical Chinese poetic form.",
    };
    const result = try buildSystemPrompt(std.testing.allocator, &cfg, "I am Hermes.", &skill);
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "## Active Skill") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "Prefer classical Chinese poetic form.") != null);
}
