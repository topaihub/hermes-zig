pub const interface = @import("interface.zig");
pub const streaming = @import("streaming.zig");
pub const openai_compat = @import("openai_compat.zig");
pub const anthropic = @import("anthropic.zig");
pub const provider_registry = @import("provider_registry.zig");

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

comptime {
    @import("std").testing.refAllDecls(@This());
}
