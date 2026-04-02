const std = @import("std");

pub const CodexModel = struct {
    name: []const u8,
};

pub const default_models = [_]CodexModel{
    .{ .name = "gpt-4o" },
    .{ .name = "gpt-4o-mini" },
    .{ .name = "o1-preview" },
    .{ .name = "o3-mini" },
};

pub fn listModels() []const CodexModel {
    return &default_models;
}

test "listModels non-empty" {
    try std.testing.expect(listModels().len > 0);
}
