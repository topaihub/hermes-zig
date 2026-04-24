const std = @import("std");
const model_metadata = @import("model_metadata.zig");

/// Cost calculation result
pub const CostResult = struct {
    input_cost: f64,
    output_cost: f64,
    total_cost: f64,

    pub fn format(
        self: CostResult,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("${d:.6} (input: ${d:.6}, output: ${d:.6})", .{
            self.total_cost,
            self.input_cost,
            self.output_cost,
        });
    }
};

/// Calculate cost for API call based on token usage
pub fn calculateCost(model_name: []const u8, input_tokens: u32, output_tokens: u32) CostResult {
    const info = model_metadata.lookup(model_name);
    
    if (info == null) {
        // Unknown model, return zero cost
        return .{
            .input_cost = 0.0,
            .output_cost = 0.0,
            .total_cost = 0.0,
        };
    }

    const model = info.?;
    
    // Convert tokens to millions and multiply by cost per 1M tokens
    const input_cost = @as(f64, @floatFromInt(input_tokens)) / 1_000_000.0 * model.input_cost_per_1m;
    const output_cost = @as(f64, @floatFromInt(output_tokens)) / 1_000_000.0 * model.output_cost_per_1m;
    
    return .{
        .input_cost = input_cost,
        .output_cost = output_cost,
        .total_cost = input_cost + output_cost,
    };
}

/// Calculate cost with floating point token counts (for estimates)
pub fn calculateCostFloat(model_name: []const u8, input_tokens: f64, output_tokens: f64) CostResult {
    const info = model_metadata.lookup(model_name);
    
    if (info == null) {
        return .{
            .input_cost = 0.0,
            .output_cost = 0.0,
            .total_cost = 0.0,
        };
    }

    const model = info.?;
    
    const input_cost = input_tokens / 1_000_000.0 * model.input_cost_per_1m;
    const output_cost = output_tokens / 1_000_000.0 * model.output_cost_per_1m;
    
    return .{
        .input_cost = input_cost,
        .output_cost = output_cost,
        .total_cost = input_cost + output_cost,
    };
}

// Tests
test "calculateCost for gpt-4o" {
    const cost = calculateCost("gpt-4o", 1000, 500);
    
    // gpt-4o: $2.50 per 1M input, $10.00 per 1M output
    // 1000 tokens input = 0.001M * $2.50 = $0.0025
    // 500 tokens output = 0.0005M * $10.00 = $0.005
    // Total = $0.0075
    
    try std.testing.expectApproxEqAbs(@as(f64, 0.0025), cost.input_cost, 0.000001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.005), cost.output_cost, 0.000001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0075), cost.total_cost, 0.000001);
}

test "calculateCost for claude-opus" {
    const cost = calculateCost("claude-opus-4-20250514", 10000, 5000);
    
    // claude-opus: $15.00 per 1M input, $75.00 per 1M output
    // 10000 tokens input = 0.01M * $15.00 = $0.15
    // 5000 tokens output = 0.005M * $75.00 = $0.375
    // Total = $0.525
    
    try std.testing.expectApproxEqAbs(@as(f64, 0.15), cost.input_cost, 0.000001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.375), cost.output_cost, 0.000001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.525), cost.total_cost, 0.000001);
}

test "calculateCost for unknown model" {
    const cost = calculateCost("unknown-model", 1000, 500);
    
    try std.testing.expectEqual(@as(f64, 0.0), cost.input_cost);
    try std.testing.expectEqual(@as(f64, 0.0), cost.output_cost);
    try std.testing.expectEqual(@as(f64, 0.0), cost.total_cost);
}

test "calculateCost for free model" {
    const cost = calculateCost("gemini-2.0-flash-exp", 10000, 5000);
    
    // Free tier model
    try std.testing.expectEqual(@as(f64, 0.0), cost.input_cost);
    try std.testing.expectEqual(@as(f64, 0.0), cost.output_cost);
    try std.testing.expectEqual(@as(f64, 0.0), cost.total_cost);
}

test "calculateCost with zero tokens" {
    const cost = calculateCost("gpt-4o", 0, 0);
    
    try std.testing.expectEqual(@as(f64, 0.0), cost.input_cost);
    try std.testing.expectEqual(@as(f64, 0.0), cost.output_cost);
    try std.testing.expectEqual(@as(f64, 0.0), cost.total_cost);
}

test "calculateCostFloat with fractional tokens" {
    const cost = calculateCostFloat("gpt-4o", 1500.5, 750.25);
    
    // gpt-4o: $2.50 per 1M input, $10.00 per 1M output
    // 1500.5 tokens input = 0.0015005M * $2.50 = $0.00375125
    // 750.25 tokens output = 0.00075025M * $10.00 = $0.0075025
    
    try std.testing.expectApproxEqAbs(@as(f64, 0.00375125), cost.input_cost, 0.000001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0075025), cost.output_cost, 0.000001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.01125375), cost.total_cost, 0.000001);
}

test "calculateCost for cheap model" {
    const cost = calculateCost("gpt-4o-mini", 100000, 50000);
    
    // gpt-4o-mini: $0.15 per 1M input, $0.60 per 1M output
    // 100000 tokens input = 0.1M * $0.15 = $0.015
    // 50000 tokens output = 0.05M * $0.60 = $0.03
    // Total = $0.045
    
    try std.testing.expectApproxEqAbs(@as(f64, 0.015), cost.input_cost, 0.000001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.03), cost.output_cost, 0.000001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.045), cost.total_cost, 0.000001);
}

test "CostResult values" {
    const cost = CostResult{
        .input_cost = 0.0025,
        .output_cost = 0.005,
        .total_cost = 0.0075,
    };
    
    try std.testing.expectEqual(@as(f64, 0.0025), cost.input_cost);
    try std.testing.expectEqual(@as(f64, 0.005), cost.output_cost);
    try std.testing.expectEqual(@as(f64, 0.0075), cost.total_cost);
}
