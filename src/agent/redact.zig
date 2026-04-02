const std = @import("std");

pub fn maskToken(token: []const u8) []const u8 {
    if (token.len <= 8) return "***";
    _ = .{ token[0], token[token.len - 1] }; // bounds check
    return token[0..4] ++ "***" ++ token[token.len - 4 ..];
}

const sensitive_prefixes = [_][]const u8{ "sk-", "AIza", "Bearer ", "ghp_", "token=", "password=" };

pub fn redactText(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    var result = try allocator.dupe(u8, text);
    for (sensitive_prefixes) |prefix| {
        var pos: usize = 0;
        while (pos < result.len) {
            const idx = std.mem.indexOfPos(u8, result, pos, prefix) orelse break;
            // Find end of token (next whitespace, quote, or end)
            var end = idx + prefix.len;
            while (end < result.len and result[end] != ' ' and result[end] != '"' and result[end] != '\'' and result[end] != '\n' and result[end] != ',') : (end += 1) {}
            const token = result[idx..end];
            const masked = maskToken(token);
            if (masked.len == token.len) {
                @memcpy(result[idx..end], masked);
                pos = end;
            } else {
                // Different length — rebuild
                var new = try std.ArrayList(u8).initCapacity(allocator, result.len);
                try new.appendSlice(allocator, result[0..idx]);
                try new.appendSlice(allocator, masked);
                try new.appendSlice(allocator, result[end..]);
                allocator.free(result);
                result = try new.toOwnedSlice(allocator);
                pos = idx + masked.len;
            }
        }
    }
    return result;
}

test "maskToken shows first 4 and last 4" {
    try std.testing.expectEqualStrings("sk-1***cdef", maskToken("sk-1234567890abcdef"));
}

test "maskToken short token" {
    try std.testing.expectEqualStrings("***", maskToken("short"));
}

test "redactText masks sensitive patterns" {
    const result = try redactText(std.testing.allocator, "key is sk-1234567890abcdef here");
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "1234567890ab") == null);
    try std.testing.expect(std.mem.indexOf(u8, result, "sk-1") != null);
}
