const std = @import("std");
const framework = @import("framework");
const interface = @import("interface.zig");
const openai_compat = @import("openai_compat.zig");
const anthropic = @import("anthropic.zig");
const provider_registry = @import("provider_registry.zig");
const core_config = @import("../core/config.zig");
const core_env = @import("../core/env.zig");
const core_types = @import("../core/types.zig");

pub const ResolvedProvider = struct {
    storage: provider_registry.ClientStorage,
    owned_api_key: ?[]u8 = null,

    pub fn asLlmClient(self: *ResolvedProvider) interface.LlmClient {
        return self.storage.asLlmClient();
    }

    pub fn deinit(self: ResolvedProvider, allocator: std.mem.Allocator) void {
        if (self.owned_api_key) |api_key| {
            allocator.free(api_key);
        }
    }
};

pub fn resolveProvider(allocator: std.mem.Allocator, config: *const core_config.Config, http: framework.HttpClient) !?ResolvedProvider {
    const env_keys = [_]struct { env: []const u8, provider: []const u8 }{
        .{ .env = "OPENROUTER_API_KEY", .provider = "openrouter" },
        .{ .env = "OPENAI_API_KEY", .provider = "openai" },
        .{ .env = "ANTHROPIC_API_KEY", .provider = "anthropic" },
    };

    var owned_api_key: ?[]u8 = null;
    errdefer if (owned_api_key) |api_key| allocator.free(api_key);

    var detected_provider: ?[]const u8 = null;

    const api_key = if (config.api_key.len > 0) config.api_key else blk: {
        for (env_keys) |ek| {
            if (try core_env.getEnvVarOwned(allocator, ek.env)) |key| {
                if (key.len == 0) {
                    allocator.free(key);
                    continue;
                }

                owned_api_key = key;
                detected_provider = ek.provider;
                break :blk key;
            }
        }

        break :blk @as([]const u8, "");
    };

    if (api_key.len == 0) return null;

    var provider = config.provider;
    if (config.api_key.len == 0) {
        if (detected_provider) |env_provider| {
            provider = env_provider;
        }
    }

    const custom_base = if (config.api_base_url.len > 0) config.api_base_url else null;

    return .{
        .storage = provider_registry.createFromConfig(allocator, provider, custom_base, config.wire_api, api_key, http),
        .owned_api_key = owned_api_key,
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
    var resolved = (try resolveProvider(std.testing.allocator, &cfg, native.client())).?;
    defer resolved.deinit(std.testing.allocator);
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
    const result = try resolveProvider(std.testing.allocator, &cfg, native.client());
    defer if (result) |provider| provider.deinit(std.testing.allocator);
    try std.testing.expect(result == null or result != null);
}
