pub const default: []const []const u8 = &.{ "bash", "file_read", "file_write", "file_edit", "file_tools", "web_search", "todo", "memory" };
pub const coding: []const []const u8 = &.{ "bash", "file_read", "file_write", "file_edit", "file_tools", "web_search", "todo", "memory", "code_execution", "delegate", "process", "checkpoint" };
pub const research: []const []const u8 = &.{ "bash", "file_read", "file_write", "file_edit", "file_tools", "web_search", "todo", "memory", "browser", "vision", "session_search" };
pub const creative: []const []const u8 = &.{ "bash", "file_read", "file_write", "file_edit", "file_tools", "web_search", "todo", "memory", "image_gen", "tts", "voice_mode" };
pub const all: []const []const u8 = &.{
    "bash",           "file_read",       "file_write",     "file_edit",
    "file_tools",     "web_search",      "todo",           "memory",
    "code_execution", "delegate",        "browser",        "vision",
    "image_gen",      "tts",             "voice_mode",     "clarify",
    "send_message",   "cronjob",         "honcho_context", "honcho_profile",
    "honcho_search",  "honcho_conclude", "skills_list",    "skill_view",
    "skill_manage",   "session_search",  "mixture_of_agents",
    "process",        "checkpoint",      "rl_start_training",
    "rl_stop_training", "rl_check_status", "rl_get_results",
};

pub fn resolveToolset(name: []const u8) ?[]const []const u8 {
    const std = @import("std");
    const map = .{
        .{ "default", default },
        .{ "coding", coding },
        .{ "research", research },
        .{ "creative", creative },
        .{ "all", all },
    };
    inline for (map) |entry| {
        if (std.mem.eql(u8, name, entry[0])) return entry[1];
    }
    return null;
}

test "resolveToolset returns correct presets" {
    const std = @import("std");
    const d = resolveToolset("default").?;
    try std.testing.expectEqual(@as(usize, 8), d.len);
    try std.testing.expectEqualStrings("bash", d[0]);

    const c = resolveToolset("coding").?;
    try std.testing.expect(c.len > d.len);

    const a = resolveToolset("all").?;
    try std.testing.expect(a.len >= 33);

    try std.testing.expectEqual(@as(?[]const []const u8, null), resolveToolset("nonexistent"));
}
