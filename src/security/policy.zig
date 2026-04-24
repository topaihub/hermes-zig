const std = @import("std");

pub const AutonomyLevel = enum { full, supervised, restricted };

pub fn requiresApproval(level: AutonomyLevel, tool_name: []const u8) bool {
    return switch (level) {
        .full => false,
        .supervised => isDangerousTool(tool_name),
        .restricted => true,
    };
}

fn isDangerousTool(name: []const u8) bool {
    const dangerous = [_][]const u8{ "shell", "exec", "delete", "rm", "drop", "truncate" };
    for (dangerous) |d| {
        if (std.mem.eql(u8, name, d)) return true;
    }
    return false;
}

pub fn checkWebsitePolicy(url: []const u8, rules: []const []const u8) bool {
    // Process rules in order - first match wins
    for (rules) |rule| {
        if (std.mem.startsWith(u8, rule, "allow:")) {
            const pattern = rule[6..];
            if (std.mem.indexOf(u8, url, pattern) != null) return true;
        }
        if (std.mem.startsWith(u8, rule, "block:")) {
            const pattern = rule[6..];
            if (std.mem.indexOf(u8, url, pattern) != null) return false;
        }
    }
    return true;
}

test "checkWebsitePolicy blocks matching rule" {
    const rules = &[_][]const u8{"block:evil.com"};
    try std.testing.expect(!checkWebsitePolicy("https://evil.com/page", rules));
}

test "checkWebsitePolicy allows non-matching" {
    const rules = &[_][]const u8{"block:evil.com"};
    try std.testing.expect(checkWebsitePolicy("https://good.com/page", rules));
}

test "checkWebsitePolicy allow rule" {
    const rules = &[_][]const u8{ "allow:example.com/safe", "block:example.com" };
    try std.testing.expect(checkWebsitePolicy("https://example.com/safe/page", rules));
}

test "requiresApproval full allows everything" {
    try std.testing.expect(!requiresApproval(.full, "shell"));
    try std.testing.expect(!requiresApproval(.full, "read"));
}

test "requiresApproval supervised blocks dangerous" {
    try std.testing.expect(requiresApproval(.supervised, "shell"));
    try std.testing.expect(!requiresApproval(.supervised, "read"));
}

test "requiresApproval restricted blocks everything" {
    try std.testing.expect(requiresApproval(.restricted, "shell"));
    try std.testing.expect(requiresApproval(.restricted, "read"));
}
