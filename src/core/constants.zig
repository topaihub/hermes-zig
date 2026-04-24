const std = @import("std");

/// Provider base URLs
pub const OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1";
pub const OPENAI_BASE_URL = "https://api.openai.com/v1";
pub const ANTHROPIC_BASE_URL = "https://api.anthropic.com";
pub const NOUS_BASE_URL = "https://inference-api.nousresearch.com/v1";

/// Get HERMES_HOME directory path
/// Returns HERMES_HOME env var if set, otherwise ~/.hermes
pub fn getHermesHome(allocator: std.mem.Allocator) ![]u8 {
    // 获取环境变量块
    const environ = std.process.Environ{ .block = .global };
    
    // 尝试获取 HERMES_HOME
    if (environ.getAlloc(allocator, "HERMES_HOME")) |home| {
        return home;
    } else |_| {
        // 回退到 HOME/.hermes
        if (environ.getAlloc(allocator, "HOME")) |home| {
            defer allocator.free(home);
            return try std.fs.path.join(allocator, &.{ home, ".hermes" });
        } else |_| {
            // 如果 HOME 也不存在，使用当前目录下的 .hermes
            return try allocator.dupe(u8, ".hermes");
        }
    }
}

test "getHermesHome returns non-empty path" {
    const allocator = std.testing.allocator;
    
    const home = try getHermesHome(allocator);
    defer allocator.free(home);
    
    try std.testing.expect(home.len > 0);
}

test "provider URLs are valid" {
    try std.testing.expect(OPENROUTER_BASE_URL.len > 0);
    try std.testing.expect(OPENAI_BASE_URL.len > 0);
    try std.testing.expect(ANTHROPIC_BASE_URL.len > 0);
    try std.testing.expect(NOUS_BASE_URL.len > 0);
}
