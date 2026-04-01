const std = @import("std");
const framework = @import("framework");
const interface = @import("interface.zig");
const openai_compat = @import("openai_compat.zig");
const anthropic = @import("anthropic.zig");
const core_types = @import("../core/types.zig");

pub const ProviderType = enum { openai_compat, anthropic };

pub fn detectProviderType(provider: []const u8) ProviderType {
    if (std.mem.eql(u8, provider, "anthropic")) return .anthropic;
    return .openai_compat;
}

pub fn resolveBaseUrl(provider: []const u8, custom_base_url: ?[]const u8) []const u8 {
    if (std.mem.eql(u8, provider, "openrouter")) return core_types.OPENROUTER_BASE_URL;
    if (std.mem.eql(u8, provider, "openai")) return core_types.OPENAI_BASE_URL;
    if (std.mem.eql(u8, provider, "nous")) return core_types.NOUS_API_BASE_URL;
    if (std.mem.eql(u8, provider, "anthropic")) return core_types.ANTHROPIC_BASE_URL;
    return custom_base_url orelse core_types.OPENROUTER_BASE_URL;
}

pub const ClientStorage = union(ProviderType) {
    openai_compat: openai_compat.OpenAICompatClient,
    anthropic: anthropic.AnthropicClient,

    pub fn asLlmClient(self: *ClientStorage) interface.LlmClient {
        return switch (self.*) {
            .openai_compat => |*c| c.asLlmClient(),
            .anthropic => |*c| c.asLlmClient(),
        };
    }
};

pub fn createFromConfig(
    allocator: std.mem.Allocator,
    provider: []const u8,
    custom_base_url: ?[]const u8,
    api_key: []const u8,
    http: framework.HttpClient,
) ClientStorage {
    const ptype = detectProviderType(provider);
    return switch (ptype) {
        .openai_compat => .{ .openai_compat = openai_compat.OpenAICompatClient.init(
            allocator,
            resolveBaseUrl(provider, custom_base_url),
            api_key,
            http,
        ) },
        .anthropic => .{ .anthropic = anthropic.AnthropicClient.init(allocator, api_key, http) },
    };
}

test "provider registry creates correct client type" {
    const Mock = struct {
        fn mockSend(_: std.mem.Allocator, _: framework.HttpRequest) !framework.HttpResponse {
            unreachable;
        }
    };
    var native = framework.NativeHttpClient.init(Mock.mockSend);
    const http = native.client();

    const oai = createFromConfig(std.testing.allocator, "openai", null, "key", http);
    try std.testing.expectEqual(ProviderType.openai_compat, std.meta.activeTag(oai));

    const anth = createFromConfig(std.testing.allocator, "anthropic", null, "key", http);
    try std.testing.expectEqual(ProviderType.anthropic, std.meta.activeTag(anth));

    const or_client = createFromConfig(std.testing.allocator, "openrouter", null, "key", http);
    try std.testing.expectEqual(ProviderType.openai_compat, std.meta.activeTag(or_client));
    try std.testing.expectEqualStrings(core_types.OPENROUTER_BASE_URL, or_client.openai_compat.base_url);

    const nous = createFromConfig(std.testing.allocator, "nous", null, "key", http);
    try std.testing.expectEqualStrings(core_types.NOUS_API_BASE_URL, nous.openai_compat.base_url);

    const custom = createFromConfig(std.testing.allocator, "custom", "https://my.api/v1", "key", http);
    try std.testing.expectEqualStrings("https://my.api/v1", custom.openai_compat.base_url);
}
