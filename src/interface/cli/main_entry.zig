const std = @import("std");

pub const Command = enum {
    chat,
    gateway,
    setup,
    model,
    tools,
    skills,
    config,
    cron,
    doctor,
    auth,
    mcp,
    version,
    help,
};

const map = std.StaticStringMap(Command).initComptime(.{
    .{ "chat", .chat },
    .{ "gateway", .gateway },
    .{ "setup", .setup },
    .{ "model", .model },
    .{ "tools", .tools },
    .{ "skills", .skills },
    .{ "config", .config },
    .{ "cron", .cron },
    .{ "doctor", .doctor },
    .{ "auth", .auth },
    .{ "mcp", .mcp },
    .{ "version", .version },
    .{ "help", .help },
});

pub fn parseSubcommand(arg: []const u8) Command {
    return map.get(arg) orelse .help;
}

test "parseSubcommand known" {
    try std.testing.expectEqual(Command.chat, parseSubcommand("chat"));
    try std.testing.expectEqual(Command.auth, parseSubcommand("auth"));
    try std.testing.expectEqual(Command.mcp, parseSubcommand("mcp"));
}

test "parseSubcommand unknown defaults to help" {
    try std.testing.expectEqual(Command.help, parseSubcommand("bogus"));
}
