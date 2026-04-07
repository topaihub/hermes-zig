const std = @import("std");

pub const CommandId = enum {
    new_session,
    model,
    tools,
    skills,
    skills_view,
    skills_use,
    skills_clear,
    skills_config,
    config,
    setup,
    usage,
    help,
    quit,
    unknown,
};

pub const CommandSpec = struct {
    id: CommandId,
    literal: []const u8,
    summary: []const u8,
    takes_arg: bool = false,
};

pub const ParsedCommand = struct {
    spec: CommandSpec,
    arg: ?[]const u8,
};

const primary_specs = [_]CommandSpec{
    .{ .id = .setup, .literal = "setup", .summary = "Configure provider, API key, and model" },
    .{ .id = .config, .literal = "config", .summary = "Show current configuration" },
    .{ .id = .model, .literal = "model", .summary = "Show configured models or switch model", .takes_arg = true },
    .{ .id = .new_session, .literal = "new", .summary = "Start a new conversation" },
    .{ .id = .tools, .literal = "tools", .summary = "List available tools" },
    .{ .id = .skills, .literal = "skills", .summary = "List installed skills" },
    .{ .id = .skills_view, .literal = "skills view", .summary = "View a skill body", .takes_arg = true },
    .{ .id = .skills_use, .literal = "skills use", .summary = "Activate a skill for this session", .takes_arg = true },
    .{ .id = .skills_clear, .literal = "skills clear", .summary = "Clear the active skill for this session" },
    .{ .id = .skills_config, .literal = "skills config", .summary = "Show the resolved skills directory" },
    .{ .id = .usage, .literal = "usage", .summary = "Show accumulated token usage" },
    .{ .id = .help, .literal = "help", .summary = "Show available commands" },
    .{ .id = .quit, .literal = "quit", .summary = "Exit hermes-zig" },
};

const alias_specs = [_]struct { literal: []const u8, target: CommandId }{
    .{ .literal = "reset", .target = .new_session },
    .{ .literal = "exit", .target = .quit },
};

const unknown_spec = CommandSpec{
    .id = .unknown,
    .literal = "",
    .summary = "",
    .takes_arg = false,
};

pub fn allPrimarySpecs() []const CommandSpec {
    return &primary_specs;
}

pub fn parseCommand(input: []const u8) ?ParsedCommand {
    const trimmed = std.mem.trim(u8, input, " \t\r\n");
    if (trimmed.len == 0 or trimmed[0] != '/') return null;

    const after_slash = trimmed[1..];
    if (resolveSpec(after_slash)) |spec| {
        const arg_text = std.mem.trim(u8, after_slash[spec.literal.len..], " \t");
        return .{
            .spec = spec,
            .arg = if (arg_text.len > 0) arg_text else null,
        };
    }

    return .{
        .spec = unknown_spec,
        .arg = if (after_slash.len > 0) after_slash else null,
    };
}

pub fn matchesForPrefix(prefix: []const u8, out: []usize) usize {
    var count: usize = 0;
    for (primary_specs, 0..) |spec, index| {
        if (!std.mem.startsWith(u8, spec.literal, prefix)) continue;
        if (count >= out.len) break;
        out[count] = index;
        count += 1;
    }
    return count;
}

pub fn renderHelp(writer: anytype) !void {
    try writer.writeAll("\n  \x1b[1mCommands:\x1b[0m\n");
    for (primary_specs) |spec| {
        const suffix = if (spec.takes_arg) " <arg>" else "";
        try writer.print("  /{s}{s} — {s}\n", .{ spec.literal, suffix, spec.summary });
    }
    try writer.writeByte('\n');
}

fn resolveSpec(input: []const u8) ?CommandSpec {
    var best: ?CommandSpec = null;
    var best_len: usize = 0;

    for (primary_specs) |spec| {
        if (!matchesLiteral(input, spec.literal)) continue;
        if (spec.literal.len > best_len) {
            best = spec;
            best_len = spec.literal.len;
        }
    }

    for (alias_specs) |alias| {
        if (!matchesLiteral(input, alias.literal)) continue;
        if (alias.literal.len > best_len) {
            best = primarySpecFor(alias.target);
            best_len = alias.literal.len;
        }
    }

    return best;
}

fn primarySpecFor(id: CommandId) CommandSpec {
    for (primary_specs) |spec| {
        if (spec.id == id) return spec;
    }
    unreachable;
}

fn matchesLiteral(input: []const u8, literal: []const u8) bool {
    if (!std.mem.startsWith(u8, input, literal)) return false;
    if (input.len == literal.len) return true;
    return input[literal.len] == ' ';
}

test "parseCommand resolves top-level command" {
    const result = parseCommand("/model gpt-4").?;
    try std.testing.expectEqual(CommandId.model, result.spec.id);
    try std.testing.expectEqualStrings("gpt-4", result.arg.?);
}

test "parseCommand resolves longest multi-word command" {
    const result = parseCommand("/skills use poetry-helper").?;
    try std.testing.expectEqual(CommandId.skills_use, result.spec.id);
    try std.testing.expectEqualStrings("poetry-helper", result.arg.?);
}

test "parseCommand resolves alias" {
    const result = parseCommand("/exit").?;
    try std.testing.expectEqual(CommandId.quit, result.spec.id);
}

test "matchesForPrefix returns filtered primary commands" {
    var indices: [8]usize = undefined;
    const count = matchesForPrefix("skills ", &indices);
    try std.testing.expect(count >= 3);
    try std.testing.expectEqualStrings("skills view", primary_specs[indices[0]].literal);
}

test "primary command surface excludes deferred placeholder commands" {
    for (primary_specs) |spec| {
        try std.testing.expect(!std.mem.eql(u8, spec.literal, "auth"));
        try std.testing.expect(!std.mem.eql(u8, spec.literal, "mcp"));
        try std.testing.expect(!std.mem.eql(u8, spec.literal, "cron"));
        try std.testing.expect(!std.mem.eql(u8, spec.literal, "hub"));
        try std.testing.expect(!std.mem.eql(u8, spec.literal, "pairing"));
        try std.testing.expect(!std.mem.eql(u8, spec.literal, "tools config"));
    }
}
