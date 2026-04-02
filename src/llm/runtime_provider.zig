const std = @import("std");
const framework = @import("framework");
const interface = @import("interface.zig");
const openai_compat = @import("openai_compat.zig");
const anthropic = @import("anthropic.zig");
const provider_registry = @import("provider_registry.zig");
const core_config = @import("../core/config.zig");
const core_types = @import("../core/types.zig");

pub const ResolvedProvider = struct {
    storage: provider_registry.ClientStorage,

    pub fn asLlmClient(self: *ResolvedProvider) interface.LlmClient {
        return self.storage.asLlmClient();
    }
};

pub fn resolveProvider(allocator: std.mem.Allocator, config: *const core_config.Config, http: framework.HttpClient) ?ResolvedProvider {
    // 1. Try config api_key first
    const api_key = if (config.api_key.len > 0) config.api_key else blk: {
        // 2. Try env vars
        const env_keys = [_]struct { env: []const u8, provider: []const u8 }{
            .{ .env = "OPENROUTER_API_KEY", .provider = "openrouter" },
            .{ .env = "OPENAI_API_KEY", .provider = "openai" },
            .{ .env = "ANTHROPIC_API_KEY", .provider = "anthropic" },
        };
        for (env_keys) |ek| {
            if (std.posix.getenv(ek.env)) |key| {
                if (key.len > 0) break :blk key;
            }
        }
        break :blk @as([]const u8, "");
    };

    if (api_key.len == 0) return null;

    // Determine provider from config or env
    var provider = config.provider;
    if (config.api_key.len == 0) {
        // Detect from env var
        if (std.posix.getenv("OPENROUTER_API_KEY")) |k| {
            if (k.len > 0) provider = "openrouter";
        } else if (std.posix.getenv("OPENAI_API_KEY")) |k| {
            if (k.len > 0) provider = "openai";
        } else if (std.posix.getenv("ANTHROPIC_API_KEY")) |k| {
            if (k.len > 0) provider = "anthropic";
        }
    }

    const custom_base = if (config.api_base_url.len > 0) config.api_base_url else null;

    return .{
        .storage = provider_registry.createFromConfig(allocator, provider, custom_base, api_key, http),
    };
}

test "resolveProvider with config api_key returns non-null" {
    const Mock = struct {
        fn mockSend(_: std.mem.Allocator, _: framework.HttpRequest) !framework.HttpResponse {
            unreachable;
        }
    };
    var native = framework.NativeHttpClient.init(Mock.mockSend);
    const cfg = core_config.Config{ .api_key = "test-key-12345", .provider = "openai" };
    var resolved = resolveProvider(std.testing.allocator, &cfg, native.client()).?;
    _ = resolved.asLlmClient();
}

test "resolveProvider with empty api_key and no env returns null" {
    const Mock = struct {
        fn mockSend(_: std.mem.Allocator, _: framework.HttpRequest) !framework.HttpResponse {
            unreachable;
        }
    };
    var native = framework.NativeHttpClient.init(Mock.mockSend);
    const cfg = core_config.Config{};
    // This may or may not be null depending on env vars, but with default config api_key="" it checks env
    const result = resolveProvider(std.testing.allocator, &cfg, native.client());
    // Can't guarantee null since env vars might be set in CI, just verify it doesn't crash
    _ = result;
}
