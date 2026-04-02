const std = @import("std");
const model_metadata = @import("model_metadata.zig");

pub const CostResult = struct {
    input_cost: f64 = 0.0,
    output_cost: f64 = 0.0,
    total_cost: f64 = 0.0,
};

pub fn calculateCost(model: []const u8, input_tokens: u32, output_tokens: u32) CostResult {
    const info = model_metadata.lookup(model) orelse return .{};
    const input_cost = @as(f64, @floatFromInt(input_tokens)) * info.input_price_per_mtok / 1_000_000.0;
    const output_cost = @as(f64, @floatFromInt(output_tokens)) * info.output_price_per_mtok / 1_000_000.0;
    return .{ .input_cost = input_cost, .output_cost = output_cost, .total_cost = input_cost + output_cost };
}

test "calculateCost for known model" {
    const cost = calculateCost("gpt-4o", 1000, 500);
    // input: 1000 * 2.5 / 1M = 0.0025, output: 500 * 10.0 / 1M = 0.005
    try std.testing.expectApproxEqAbs(@as(f64, 0.0025), cost.input_cost, 1e-9);
    try std.testing.expectApproxEqAbs(@as(f64, 0.005), cost.output_cost, 1e-9);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0075), cost.total_cost, 1e-9);
}

test "calculateCost for unknown model returns zeros" {
    const cost = calculateCost("unknown", 1000, 500);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), cost.total_cost, 1e-9);
}
