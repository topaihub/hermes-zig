pub const loop = @import("loop.zig");
pub const prompt_builder = @import("prompt_builder.zig");
pub const context_compressor = @import("context_compressor.zig");
pub const credential_pool = @import("credential_pool.zig");
pub const prompt_caching = @import("prompt_caching.zig");
pub const trajectory = @import("trajectory/root.zig");
pub const redact = @import("redact.zig");
pub const model_metadata = @import("model_metadata.zig");
pub const usage_pricing = @import("usage_pricing.zig");
pub const callbacks = @import("callbacks.zig");

// Re-export key types
pub const AgentLoop = loop.AgentLoop;
pub const RunResult = loop.RunResult;
pub const CredentialPool = credential_pool.CredentialPool;
pub const buildSystemPrompt = prompt_builder.buildSystemPrompt;
pub const compress = context_compressor.compress;
pub const CacheHint = prompt_caching.CacheHint;
pub const identifyCacheableMessages = prompt_caching.identifyCacheableMessages;
pub const Trajectory = trajectory.Trajectory;
pub const ModelInfo = model_metadata.ModelInfo;
pub const CostResult = usage_pricing.CostResult;
pub const CliStreamCallback = callbacks.CliStreamCallback;

comptime {
    @import("std").testing.refAllDecls(@This());
}
