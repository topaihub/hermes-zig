const std = @import("std");

const DANGEROUS_PATTERNS = [_][]const u8{
    "rm -rf /",
    "mkfs.",
    "dd if=/dev/zero",
    "> /dev/sda",
    "chmod 777 /",
    ":(){ :|:& };:",
};

pub fn preExecScan(command: []const u8) ?[]const u8 {
    for (&DANGEROUS_PATTERNS) |pattern| {
        if (std.mem.indexOf(u8, command, pattern) != null) return pattern;
    }
    return null;
}

test "preExecScan detects rm -rf /" {
    try std.testing.expectEqualStrings("rm -rf /", preExecScan("rm -rf /").?);
}

test "preExecScan detects mkfs" {
    try std.testing.expect(preExecScan("mkfs.ext4 /dev/sda1") != null);
}

test "preExecScan allows safe commands" {
    try std.testing.expectEqual(@as(?[]const u8, null), preExecScan("ls -la"));
    try std.testing.expectEqual(@as(?[]const u8, null), preExecScan("echo hello"));
}
