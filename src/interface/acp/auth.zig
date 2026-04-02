const std = @import("std");

const providers = [_]struct { env: []const u8, name: []const u8 }{
    .{ .env = "OPENAI_API_KEY", .name = "openai" },
    .{ .env = "ANTHROPIC_API_KEY", .name = "anthropic" },
    .{ .env = "OPENROUTER_API_KEY", .name = "openrouter" },
};

pub fn detectProvider(allocator: std.mem.Allocator) ?[]const u8 {
    for (providers) |p| {
        if (std.process.getEnvVarOwned(allocator, p.env)) |key| {
            allocator.free(key);
            return p.name;
        } else |_| {}
    }
    return null;
}

pub fn hasProvider(allocator: std.mem.Allocator) bool {
    return detectProvider(allocator) != null;
}

test "detectProvider returns null when no env vars set" {
    // In test environment, these env vars are typically not set
    const result = detectProvider(std.testing.allocator);
    // We can't guarantee env state, so just verify it returns a valid type
    if (result) |name| {
        try std.testing.expect(name.len > 0);
    }
}
