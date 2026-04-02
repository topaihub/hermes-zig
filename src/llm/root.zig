pub const interface = @import("interface.zig");
pub const streaming = @import("streaming.zig");
pub const openai_compat = @import("openai_compat.zig");
pub const anthropic = @import("anthropic.zig");
pub const provider_registry = @import("provider_registry.zig");
pub const runtime_provider = @import("runtime_provider.zig");

// Re-export key types
pub const LlmClient = interface.LlmClient;
pub const CompletionRequest = interface.CompletionRequest;
pub const CompletionResponse = interface.CompletionResponse;
pub const StreamCallback = interface.StreamCallback;
pub const ToolSchema = interface.ToolSchema;
pub const OpenAICompatClient = openai_compat.OpenAICompatClient;
pub const AnthropicClient = anthropic.AnthropicClient;
pub const createFromConfig = provider_registry.createFromConfig;
pub const ClientStorage = provider_registry.ClientStorage;
pub const resolveProvider = runtime_provider.resolveProvider;
pub const ResolvedProvider = runtime_provider.ResolvedProvider;

comptime {
    @import("std").testing.refAllDecls(@This());
}
