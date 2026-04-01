const std = @import("std");

pub const InjectionAlert = struct {
    pattern: []const u8,
};

const THREAT_PATTERNS = [_][]const u8{
    "ignore previous instructions",
    "system prompt override",
    "disregard your rules",
};

pub fn scanForInjection(text: []const u8) ?InjectionAlert {
    const lower_buf: [4096]u8 = undefined;
    const check = if (text.len <= lower_buf.len) blk: {
        var buf: [4096]u8 = undefined;
        const len = @min(text.len, buf.len);
        @memcpy(buf[0..len], text[0..len]);
        for (buf[0..len]) |*c| {
            if (c.* >= 'A' and c.* <= 'Z') c.* = c.* + 32;
        }
        break :blk buf[0..len];
    } else text;

    for (&THREAT_PATTERNS) |pat| {
        if (std.mem.indexOf(u8, check, pat) != null) return .{ .pattern = pat };
    }
    return null;
}
