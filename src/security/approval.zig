const std = @import("std");

pub const ApprovalResult = enum { allowed, needs_approval, denied };

pub fn checkApproval(command: []const u8, patterns: []const []const u8) ApprovalResult {
    for (patterns) |pat| {
        if (matchGlob(pat, command)) return .allowed;
    }
    return .needs_approval;
}

fn matchGlob(pattern: []const u8, text: []const u8) bool {
    if (std.mem.endsWith(u8, pattern, " *")) {
        const prefix = pattern[0 .. pattern.len - 2];
        return std.mem.startsWith(u8, text, prefix);
    }
    return std.mem.eql(u8, pattern, text);
}

test "checkApproval allows matching pattern" {
    const patterns = &[_][]const u8{ "git *", "npm *" };
    try std.testing.expectEqual(ApprovalResult.allowed, checkApproval("git status", patterns));
    try std.testing.expectEqual(ApprovalResult.allowed, checkApproval("npm install", patterns));
}

test "checkApproval needs approval for unmatched" {
    const patterns = &[_][]const u8{"git *"};
    try std.testing.expectEqual(ApprovalResult.needs_approval, checkApproval("rm -rf /", patterns));
}
