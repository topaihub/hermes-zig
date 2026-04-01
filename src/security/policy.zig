const std = @import("std");

pub fn checkWebsitePolicy(url: []const u8, rules: []const []const u8) bool {
    for (rules) |rule| {
        if (std.mem.startsWith(u8, rule, "block:")) {
            const pattern = rule[6..];
            if (std.mem.indexOf(u8, url, pattern) != null) return false;
        }
        if (std.mem.startsWith(u8, rule, "allow:")) {
            const pattern = rule[6..];
            if (std.mem.indexOf(u8, url, pattern) != null) return true;
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
    const rules = &[_][]const u8{ "block:example.com", "allow:example.com/safe" };
    try std.testing.expect(checkWebsitePolicy("https://example.com/safe/page", rules));
}
