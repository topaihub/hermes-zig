const std = @import("std");

pub const ModelInfo = struct {
    name: []const u8,
    context_window: u32,
    supports_vision: bool = false,
    supports_tools: bool = true,
    input_price_per_mtok: f64 = 0.0,
    output_price_per_mtok: f64 = 0.0,
};

pub const models = [_]ModelInfo{
    .{ .name = "gpt-4o", .context_window = 128000, .supports_vision = true, .input_price_per_mtok = 2.5, .output_price_per_mtok = 10.0 },
    .{ .name = "gpt-4o-mini", .context_window = 128000, .supports_vision = true, .input_price_per_mtok = 0.15, .output_price_per_mtok = 0.6 },
    .{ .name = "o1-preview", .context_window = 128000, .input_price_per_mtok = 15.0, .output_price_per_mtok = 60.0 },
    .{ .name = "o3-mini", .context_window = 200000, .input_price_per_mtok = 1.1, .output_price_per_mtok = 4.4 },
    .{ .name = "claude-sonnet-4", .context_window = 200000, .supports_vision = true, .input_price_per_mtok = 3.0, .output_price_per_mtok = 15.0 },
    .{ .name = "claude-haiku-3.5", .context_window = 200000, .supports_vision = true, .input_price_per_mtok = 0.8, .output_price_per_mtok = 4.0 },
    .{ .name = "claude-opus-4", .context_window = 200000, .supports_vision = true, .input_price_per_mtok = 15.0, .output_price_per_mtok = 75.0 },
    .{ .name = "gemini-2.5-pro", .context_window = 1000000, .supports_vision = true, .input_price_per_mtok = 1.25, .output_price_per_mtok = 10.0 },
    .{ .name = "gemini-2.5-flash", .context_window = 1000000, .supports_vision = true, .input_price_per_mtok = 0.15, .output_price_per_mtok = 0.6 },
    .{ .name = "nous/hermes-3", .context_window = 128000, .input_price_per_mtok = 2.0, .output_price_per_mtok = 6.0 },
};

pub fn lookup(model: []const u8) ?ModelInfo {
    for (models) |m| {
        if (std.mem.eql(u8, m.name, model)) return m;
    }
    return null;
}

test "lookup gpt-4o returns correct context_window" {
    const info = lookup("gpt-4o").?;
    try std.testing.expectEqual(@as(u32, 128000), info.context_window);
    try std.testing.expect(info.supports_vision);
}

test "lookup unknown returns null" {
    try std.testing.expectEqual(@as(?ModelInfo, null), lookup("nonexistent-model"));
}
