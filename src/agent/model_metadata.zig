const std = @import("std");

/// Model metadata information
pub const ModelInfo = struct {
    name: []const u8,
    provider: []const u8,
    context_window: u32,
    max_output: u32,
    supports_streaming: bool,
    supports_tools: bool,
    input_cost_per_1m: f64, // USD per 1M tokens
    output_cost_per_1m: f64,
};

/// Static model metadata database
pub const MODELS = [_]ModelInfo{
    // OpenAI GPT-4o
    .{
        .name = "gpt-4o",
        .provider = "openai",
        .context_window = 128000,
        .max_output = 16384,
        .supports_streaming = true,
        .supports_tools = true,
        .input_cost_per_1m = 2.50,
        .output_cost_per_1m = 10.00,
    },
    .{
        .name = "gpt-4o-mini",
        .provider = "openai",
        .context_window = 128000,
        .max_output = 16384,
        .supports_streaming = true,
        .supports_tools = true,
        .input_cost_per_1m = 0.15,
        .output_cost_per_1m = 0.60,
    },
    // Anthropic Claude
    .{
        .name = "claude-opus-4-20250514",
        .provider = "anthropic",
        .context_window = 200000,
        .max_output = 16384,
        .supports_streaming = true,
        .supports_tools = true,
        .input_cost_per_1m = 15.00,
        .output_cost_per_1m = 75.00,
    },
    .{
        .name = "claude-sonnet-4-20250514",
        .provider = "anthropic",
        .context_window = 200000,
        .max_output = 16384,
        .supports_streaming = true,
        .supports_tools = true,
        .input_cost_per_1m = 3.00,
        .output_cost_per_1m = 15.00,
    },
    .{
        .name = "claude-3-5-sonnet-20241022",
        .provider = "anthropic",
        .context_window = 200000,
        .max_output = 8192,
        .supports_streaming = true,
        .supports_tools = true,
        .input_cost_per_1m = 3.00,
        .output_cost_per_1m = 15.00,
    },
    .{
        .name = "claude-3-5-haiku-20241022",
        .provider = "anthropic",
        .context_window = 200000,
        .max_output = 8192,
        .supports_streaming = true,
        .supports_tools = true,
        .input_cost_per_1m = 0.80,
        .output_cost_per_1m = 4.00,
    },
    // Google Gemini
    .{
        .name = "gemini-2.0-flash-exp",
        .provider = "google",
        .context_window = 1048576,
        .max_output = 8192,
        .supports_streaming = true,
        .supports_tools = true,
        .input_cost_per_1m = 0.00, // Free tier
        .output_cost_per_1m = 0.00,
    },
    .{
        .name = "gemini-1.5-pro",
        .provider = "google",
        .context_window = 2097152,
        .max_output = 8192,
        .supports_streaming = true,
        .supports_tools = true,
        .input_cost_per_1m = 1.25,
        .output_cost_per_1m = 5.00,
    },
    .{
        .name = "gemini-1.5-flash",
        .provider = "google",
        .context_window = 1048576,
        .max_output = 8192,
        .supports_streaming = true,
        .supports_tools = true,
        .input_cost_per_1m = 0.075,
        .output_cost_per_1m = 0.30,
    },
    // DeepSeek
    .{
        .name = "deepseek-chat",
        .provider = "deepseek",
        .context_window = 64000,
        .max_output = 8192,
        .supports_streaming = true,
        .supports_tools = true,
        .input_cost_per_1m = 0.14,
        .output_cost_per_1m = 0.28,
    },
    .{
        .name = "deepseek-reasoner",
        .provider = "deepseek",
        .context_window = 64000,
        .max_output = 8192,
        .supports_streaming = true,
        .supports_tools = false,
        .input_cost_per_1m = 0.55,
        .output_cost_per_1m = 2.19,
    },
    // OpenRouter models
    .{
        .name = "anthropic/claude-opus-4-7",
        .provider = "openrouter",
        .context_window = 200000,
        .max_output = 16384,
        .supports_streaming = true,
        .supports_tools = true,
        .input_cost_per_1m = 15.00,
        .output_cost_per_1m = 75.00,
    },
    .{
        .name = "anthropic/claude-sonnet-4-7",
        .provider = "openrouter",
        .context_window = 200000,
        .max_output = 16384,
        .supports_streaming = true,
        .supports_tools = true,
        .input_cost_per_1m = 3.00,
        .output_cost_per_1m = 15.00,
    },
    .{
        .name = "google/gemini-2.5-pro-exp-03-25",
        .provider = "openrouter",
        .context_window = 2097152,
        .max_output = 8192,
        .supports_streaming = true,
        .supports_tools = true,
        .input_cost_per_1m = 0.00,
        .output_cost_per_1m = 0.00,
    },
    .{
        .name = "openai/gpt-4o",
        .provider = "openrouter",
        .context_window = 128000,
        .max_output = 16384,
        .supports_streaming = true,
        .supports_tools = true,
        .input_cost_per_1m = 2.50,
        .output_cost_per_1m = 10.00,
    },
    // Qwen
    .{
        .name = "qwen-max",
        .provider = "qwen",
        .context_window = 32000,
        .max_output = 8192,
        .supports_streaming = true,
        .supports_tools = true,
        .input_cost_per_1m = 0.40,
        .output_cost_per_1m = 1.20,
    },
    .{
        .name = "qwen-plus",
        .provider = "qwen",
        .context_window = 131072,
        .max_output = 8192,
        .supports_streaming = true,
        .supports_tools = true,
        .input_cost_per_1m = 0.08,
        .output_cost_per_1m = 0.24,
    },
    // Mistral
    .{
        .name = "mistral-large-latest",
        .provider = "mistral",
        .context_window = 128000,
        .max_output = 8192,
        .supports_streaming = true,
        .supports_tools = true,
        .input_cost_per_1m = 2.00,
        .output_cost_per_1m = 6.00,
    },
    .{
        .name = "mistral-small-latest",
        .provider = "mistral",
        .context_window = 128000,
        .max_output = 8192,
        .supports_streaming = true,
        .supports_tools = true,
        .input_cost_per_1m = 0.20,
        .output_cost_per_1m = 0.60,
    },
    // xAI Grok
    .{
        .name = "grok-beta",
        .provider = "xai",
        .context_window = 131072,
        .max_output = 8192,
        .supports_streaming = true,
        .supports_tools = true,
        .input_cost_per_1m = 5.00,
        .output_cost_per_1m = 15.00,
    },
};

/// Lookup model metadata by name
pub fn lookup(model_name: []const u8) ?*const ModelInfo {
    for (&MODELS) |*model| {
        if (std.mem.eql(u8, model.name, model_name)) {
            return model;
        }
    }
    return null;
}

/// Get provider from model name (handles openrouter prefix)
pub fn getProvider(model_name: []const u8) []const u8 {
    if (lookup(model_name)) |info| {
        return info.provider;
    }
    // Fallback: extract from name
    if (std.mem.indexOf(u8, model_name, "/")) |idx| {
        return model_name[0..idx];
    }
    return "unknown";
}

// Tests
test "lookup existing model" {
    const info = lookup("gpt-4o");
    try std.testing.expect(info != null);
    try std.testing.expectEqual(@as(u32, 128000), info.?.context_window);
    try std.testing.expectEqualStrings("openai", info.?.provider);
}

test "lookup non-existing model" {
    const info = lookup("non-existent-model");
    try std.testing.expect(info == null);
}

test "lookup claude model" {
    const info = lookup("claude-sonnet-4-20250514");
    try std.testing.expect(info != null);
    try std.testing.expectEqual(@as(u32, 200000), info.?.context_window);
    try std.testing.expect(info.?.supports_tools);
}

test "lookup openrouter model" {
    const info = lookup("anthropic/claude-opus-4-7");
    try std.testing.expect(info != null);
    try std.testing.expectEqualStrings("openrouter", info.?.provider);
}

test "getProvider from known model" {
    const provider = getProvider("gpt-4o");
    try std.testing.expectEqualStrings("openai", provider);
}

test "getProvider from openrouter model" {
    const provider = getProvider("anthropic/claude-opus-4-7");
    try std.testing.expectEqualStrings("openrouter", provider);
}

test "getProvider fallback for unknown model with slash" {
    const provider = getProvider("custom/model-name");
    try std.testing.expectEqualStrings("custom", provider);
}

test "getProvider fallback for unknown model without slash" {
    const provider = getProvider("unknown-model");
    try std.testing.expectEqualStrings("unknown", provider);
}

test "verify pricing data" {
    const gpt4o = lookup("gpt-4o").?;
    try std.testing.expectEqual(@as(f64, 2.50), gpt4o.input_cost_per_1m);
    try std.testing.expectEqual(@as(f64, 10.00), gpt4o.output_cost_per_1m);

    const claude = lookup("claude-opus-4-20250514").?;
    try std.testing.expectEqual(@as(f64, 15.00), claude.input_cost_per_1m);
    try std.testing.expectEqual(@as(f64, 75.00), claude.output_cost_per_1m);
}

test "verify capabilities" {
    const deepseek_chat = lookup("deepseek-chat").?;
    try std.testing.expect(deepseek_chat.supports_streaming);
    try std.testing.expect(deepseek_chat.supports_tools);

    const deepseek_reasoner = lookup("deepseek-reasoner").?;
    try std.testing.expect(deepseek_reasoner.supports_streaming);
    try std.testing.expect(!deepseek_reasoner.supports_tools);
}
