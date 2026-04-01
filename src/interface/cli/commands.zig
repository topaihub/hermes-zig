const std = @import("std");

pub const Command = enum {
    new,
    model,
    personality,
    tools,
    skills,
    compress,
    usage,
    undo,
    retry,
    help,
    quit,
    unknown,
};

pub const ParsedCommand = struct {
    cmd: Command,
    arg: ?[]const u8,
};

const command_map = std.StaticStringMap(Command).initComptime(.{
    .{ "new", .new },
    .{ "reset", .new },
    .{ "model", .model },
    .{ "personality", .personality },
    .{ "tools", .tools },
    .{ "skills", .skills },
    .{ "compress", .compress },
    .{ "usage", .usage },
    .{ "undo", .undo },
    .{ "retry", .retry },
    .{ "help", .help },
    .{ "quit", .quit },
    .{ "exit", .quit },
});

/// Parse input as a slash command. Returns null if input doesn't start with '/'.
pub fn parseCommand(input: []const u8) ?ParsedCommand {
    const trimmed = std.mem.trim(u8, input, " \t\r\n");
    if (trimmed.len == 0 or trimmed[0] != '/') return null;

    const after_slash = trimmed[1..];
    const space_idx = std.mem.indexOfScalar(u8, after_slash, ' ');
    const name = if (space_idx) |i| after_slash[0..i] else after_slash;
    const arg = if (space_idx) |i| std.mem.trim(u8, after_slash[i + 1 ..], " \t") else null;
    const real_arg = if (arg) |a| (if (a.len == 0) null else a) else null;

    const cmd = command_map.get(name) orelse .unknown;
    return .{ .cmd = cmd, .arg = real_arg };
}

/// Action returned by command handlers.
pub const Action = enum { none, quit, new_session };

pub fn handleCommand(parsed: ParsedCommand, writer: anytype) !Action {
    switch (parsed.cmd) {
        .quit => return .quit,
        .new => {
            try writer.writeAll("Starting new session.\n");
            return .new_session;
        },
        .help => {
            try writer.writeAll(
                \\Commands:
                \\  /new, /reset    — new session
                \\  /model [name]   — switch model
                \\  /personality    — set personality
                \\  /tools          — list tools
                \\  /skills         — list skills
                \\  /compress       — compress context
                \\  /usage          — token usage
                \\  /undo           — remove last turn
                \\  /retry          — retry last message
                \\  /help           — this help
                \\  /quit           — exit
                \\
            );
            return .none;
        },
        .model => {
            if (parsed.arg) |m| {
                try writer.print("Model set to: {s}\n", .{m});
            } else {
                try writer.writeAll("Usage: /model <provider:model>\n");
            }
            return .none;
        },
        .unknown => {
            try writer.writeAll("Unknown command. Type /help for available commands.\n");
            return .none;
        },
        else => {
            try writer.print("/{s}: not yet implemented.\n", .{@tagName(parsed.cmd)});
            return .none;
        },
    }
}

test "parseCommand with slash prefix returns command" {
    const result = parseCommand("/model gpt-4").?;
    try std.testing.expectEqual(Command.model, result.cmd);
    try std.testing.expectEqualStrings("gpt-4", result.arg.?);
}

test "parseCommand without slash returns null" {
    try std.testing.expectEqual(null, parseCommand("hello"));
}

test "parseCommand /quit" {
    const result = parseCommand("/quit").?;
    try std.testing.expectEqual(Command.quit, result.cmd);
    try std.testing.expectEqual(null, result.arg);
}

test "parseCommand /reset maps to new" {
    const result = parseCommand("/reset").?;
    try std.testing.expectEqual(Command.new, result.cmd);
}

test "parseCommand unknown command" {
    const result = parseCommand("/foobar").?;
    try std.testing.expectEqual(Command.unknown, result.cmd);
}
