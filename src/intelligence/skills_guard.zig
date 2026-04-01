const std = @import("std");

const dangerous_patterns = [_][]const u8{
    "rm -rf",
    "sudo ",
    "curl|bash",
    "curl | bash",
    "wget|bash",
    "wget | bash",
};

pub fn scanSkillForDangers(body: []const u8) ?[]const u8 {
    for (&dangerous_patterns) |pattern| {
        if (std.mem.indexOf(u8, body, pattern) != null) return pattern;
    }
    return null;
}

test "scanSkillForDangers detects rm -rf" {
    try std.testing.expectEqualStrings("rm -rf", scanSkillForDangers("run rm -rf /").?);
}

test "scanSkillForDangers detects sudo" {
    try std.testing.expectEqualStrings("sudo ", scanSkillForDangers("use sudo apt install").?);
}

test "scanSkillForDangers returns null for safe content" {
    try std.testing.expectEqual(null, scanSkillForDangers("echo hello world"));
}
