const std = @import("std");

pub const DevModel = struct {
    name: []const u8,
    provider: []const u8,
    base_url: []const u8 = "",
    notes: []const u8 = "",
};

pub const dev_models = [_]DevModel{
    .{ .name = "hermes-3-exp", .provider = "nous", .notes = "experimental hermes-3 build" },
    .{ .name = "claude-next", .provider = "anthropic", .notes = "pre-release claude" },
    .{ .name = "local-llama", .provider = "ollama", .base_url = "http://localhost:11434", .notes = "local llama via ollama" },
};

test "array not empty" {
    try std.testing.expect(dev_models.len > 0);
}
