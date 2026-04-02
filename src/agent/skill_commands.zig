const std = @import("std");

pub const SkillAction = enum { install, create, list, unknown };

pub fn parseAction(args: []const u8) struct { action: SkillAction, arg: []const u8 } {
    const trimmed = std.mem.trim(u8, args, " \t");
    if (trimmed.len == 0) return .{ .action = .list, .arg = "" };
    const space = std.mem.indexOfScalar(u8, trimmed, ' ');
    const verb = if (space) |s| trimmed[0..s] else trimmed;
    const rest = if (space) |s| std.mem.trim(u8, trimmed[s + 1 ..], " \t") else "";
    const action: SkillAction = if (std.mem.eql(u8, verb, "install"))
        .install
    else if (std.mem.eql(u8, verb, "create"))
        .create
    else if (std.mem.eql(u8, verb, "list"))
        .list
    else
        .unknown;
    return .{ .action = action, .arg = rest };
}

pub fn handleSkillCommand(allocator: std.mem.Allocator, args: []const u8, writer: anytype) !void {
    _ = allocator;
    const parsed = parseAction(args);
    switch (parsed.action) {
        .install => try writer.print("Installing skill: {s}\n", .{parsed.arg}),
        .create => try writer.print("Creating skill: {s}\n", .{parsed.arg}),
        .list => try writer.writeAll("Listing skills...\n"),
        .unknown => try writer.writeAll("Unknown skill command\n"),
    }
}

test "parse install test-skill" {
    const result = parseAction("install test-skill");
    try std.testing.expectEqual(SkillAction.install, result.action);
    try std.testing.expectEqualStrings("test-skill", result.arg);
}

test "parse empty defaults to list" {
    const result = parseAction("");
    try std.testing.expectEqual(SkillAction.list, result.action);
}
