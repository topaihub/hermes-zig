const std = @import("std");

pub fn suggestModel(message: []const u8, available_models: []const []const u8) []const u8 {
    if (available_models.len == 0) return "gpt-4o";
    // Short simple questions -> first (cheapest) model; longer/code -> last (most powerful)
    const is_complex = message.len > 200 or std.mem.indexOf(u8, message, "```") != null or std.mem.indexOf(u8, message, "code") != null;
    if (is_complex) return available_models[available_models.len - 1];
    return available_models[0];
}

test "suggestModel short question picks first" {
    const models = &[_][]const u8{ "gpt-4o-mini", "gpt-4o" };
    const result = suggestModel("hi", models);
    try std.testing.expectEqualStrings("gpt-4o-mini", result);
}

test "suggestModel complex picks last" {
    const models = &[_][]const u8{ "gpt-4o-mini", "gpt-4o" };
    const result = suggestModel("write code for a web server", models);
    try std.testing.expectEqualStrings("gpt-4o", result);
}
