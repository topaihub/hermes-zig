const std = @import("std");
const Config = @import("types.zig").Config;
const ProviderEntry = @import("types.zig").ProviderEntry;

pub const ValidationError = error{
    MissingDefaultProvider,
    MissingDefaultModel,
    InvalidDefaultProvider,
    InvalidTemperature,
    InvalidMaxTokens,
    NoProviders,
    DuplicateProviderName,
    MissingProviderName,
    MissingApiKey,
    InvalidBaseUrl,
    InvalidApiMode,
};

/// Validate configuration
pub fn validateConfig(config: *const Config) ValidationError!void {
    // Validate default provider
    if (config.default_provider.len == 0) {
        return error.MissingDefaultProvider;
    }
    
    // Validate default model
    if (config.default_model.len == 0) {
        return error.MissingDefaultModel;
    }
    
    // Validate temperature (0.0 - 2.0)
    if (config.temperature < 0.0 or config.temperature > 2.0) {
        return error.InvalidTemperature;
    }
    
    // Validate max_tokens (1 - 1000000) if specified
    if (config.max_tokens) |max_tokens| {
        if (max_tokens < 1 or max_tokens > 1000000) {
            return error.InvalidMaxTokens;
        }
    }
    
    // Validate providers
    if (config.providers.len == 0) {
        return error.NoProviders;
    }
    
    // Check if default provider exists
    var found_default = false;
    for (config.providers) |provider| {
        if (std.mem.eql(u8, provider.name, config.default_provider)) {
            found_default = true;
            break;
        }
    }
    if (!found_default) {
        return error.InvalidDefaultProvider;
    }
    
    // Validate each provider
    for (config.providers) |provider| {
        try validateProvider(&provider);
    }
    
    // Check for duplicate provider names
    for (config.providers, 0..) |provider1, i| {
        for (config.providers[i + 1..]) |provider2| {
            if (std.mem.eql(u8, provider1.name, provider2.name)) {
                return error.DuplicateProviderName;
            }
        }
    }
}

/// Validate provider entry
fn validateProvider(provider: *const ProviderEntry) ValidationError!void {
    // Validate name
    if (provider.name.len == 0) {
        return error.MissingProviderName;
    }
    
    // Validate API key (required for non-local providers)
    if (provider.api_key == null or provider.api_key.?.len == 0) {
        // Check if it's a local provider (localhost or 127.0.0.1)
        if (provider.base_url) |url| {
            if (!isLocalUrl(url)) {
                return error.MissingApiKey;
            }
        } else {
            return error.MissingApiKey;
        }
    }
    
    // Validate base URL if provided
    if (provider.base_url) |url| {
        if (!isValidUrl(url)) {
            return error.InvalidBaseUrl;
        }
    }
    
    // Validate API mode
    if (provider.api_mode == .invalid) {
        return error.InvalidApiMode;
    }
}

/// Check if URL is local
fn isLocalUrl(url: []const u8) bool {
    return std.mem.indexOf(u8, url, "localhost") != null or
           std.mem.indexOf(u8, url, "127.0.0.1") != null or
           std.mem.indexOf(u8, url, "::1") != null;
}

/// Validate URL format
fn isValidUrl(url: []const u8) bool {
    // Must start with http:// or https://
    if (!std.mem.startsWith(u8, url, "http://") and 
        !std.mem.startsWith(u8, url, "https://")) {
        return false;
    }
    
    // Must have at least one character after protocol
    const min_len = "https://".len + 1;
    if (url.len < min_len) {
        return false;
    }
    
    return true;
}

// ============================================================================
// Tests
// ============================================================================

test "validateConfig - valid config" {
    const allocator = std.testing.allocator;
    
    const providers = try allocator.alloc(ProviderEntry, 1);
    defer allocator.free(providers);
    
    providers[0] = ProviderEntry{
        .name = "anthropic",
        .api_key = "test-key",
        .base_url = "https://api.anthropic.com",
        .api_mode = .chat_completions,
    };
    
    const config = Config{
        .default_provider = "anthropic",
        .default_model = "claude-3-5-sonnet",
        .temperature = 0.7,
        .max_tokens = 4096,
        .providers = providers,
    };
    
    try validateConfig(&config);
}

test "validateConfig - missing default provider" {
    const allocator = std.testing.allocator;
    
    const providers = try allocator.alloc(ProviderEntry, 1);
    defer allocator.free(providers);
    
    providers[0] = ProviderEntry{
        .name = "anthropic",
        .api_key = "test-key",
        .base_url = "https://api.anthropic.com",
        .api_mode = .chat_completions,
    };
    
    const config = Config{
        .default_provider = "", // Empty - should fail
        .default_model = "claude-3-5-sonnet",
        .temperature = 0.7,
        .max_tokens = 4096,
        .providers = providers,
    };
    
    try std.testing.expectError(error.MissingDefaultProvider, validateConfig(&config));
}

test "validateConfig - invalid temperature" {
    const allocator = std.testing.allocator;
    
    const providers = try allocator.alloc(ProviderEntry, 1);
    defer allocator.free(providers);
    
    providers[0] = ProviderEntry{
        .name = "anthropic",
        .api_key = "test-key",
        .base_url = "https://api.anthropic.com",
        .api_mode = .chat_completions,
    };
    
    const config = Config{
        .default_provider = "anthropic",
        .default_model = "claude-3-5-sonnet",
        .temperature = 3.0, // Invalid
        .max_tokens = 4096,
        .providers = providers,
    };
    
    try std.testing.expectError(error.InvalidTemperature, validateConfig(&config));
}

test "validateConfig - no providers" {
    const allocator = std.testing.allocator;
    
    const providers = try allocator.alloc(ProviderEntry, 0);
    defer allocator.free(providers);
    
    const config = Config{
        .default_provider = "anthropic",
        .default_model = "claude-3-5-sonnet",
        .temperature = 0.7,
        .max_tokens = 4096,
        .providers = providers,
    };
    
    try std.testing.expectError(error.NoProviders, validateConfig(&config));
}

test "validateConfig - invalid default provider" {
    const allocator = std.testing.allocator;
    
    const providers = try allocator.alloc(ProviderEntry, 1);
    defer allocator.free(providers);
    
    providers[0] = ProviderEntry{
        .name = "anthropic",
        .api_key = "test-key",
        .base_url = "https://api.anthropic.com",
        .api_mode = .chat_completions,
    };
    
    const config = Config{
        .default_provider = "openai", // Not in providers
        .default_model = "claude-3-5-sonnet",
        .temperature = 0.7,
        .max_tokens = 4096,
        .providers = providers,
    };
    
    try std.testing.expectError(error.InvalidDefaultProvider, validateConfig(&config));
}

test "isValidUrl - valid URLs" {
    try std.testing.expect(isValidUrl("https://api.anthropic.com"));
    try std.testing.expect(isValidUrl("http://localhost:8080"));
    try std.testing.expect(isValidUrl("https://example.com/path"));
}

test "isValidUrl - invalid URLs" {
    try std.testing.expect(!isValidUrl("ftp://example.com"));
    try std.testing.expect(!isValidUrl("https://"));
    try std.testing.expect(!isValidUrl("not-a-url"));
}

test "isLocalUrl" {
    try std.testing.expect(isLocalUrl("http://localhost:8080"));
    try std.testing.expect(isLocalUrl("http://127.0.0.1:8080"));
    try std.testing.expect(isLocalUrl("http://[::1]:8080"));
    try std.testing.expect(!isLocalUrl("https://api.anthropic.com"));
}
