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
pub const context_references = @import("context_references.zig");
pub const title_generator = @import("title_generator.zig");
pub const insights = @import("insights.zig");
pub const smart_model_routing = @import("smart_model_routing.zig");
pub const anthropic_adapter = @import("anthropic_adapter.zig");
pub const auxiliary_client = @import("auxiliary_client.zig");
pub const copilot_acp_client = @import("copilot_acp_client.zig");
pub const models_dev = @import("models_dev.zig");
pub const skill_commands = @import("skill_commands.zig");
pub const skill_utils = @import("skill_utils.zig");

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
pub const Reference = context_references.Reference;
pub const parseReferences = context_references.parseReferences;
pub const SessionInsights = insights.SessionInsights;
pub const suggestModel = smart_model_routing.suggestModel;
pub const generateTitle = title_generator.generateTitle;
pub const getMaxOutput = anthropic_adapter.getMaxOutput;
pub const AuxiliaryClient = auxiliary_client.AuxiliaryClient;
pub const CopilotClient = copilot_acp_client.CopilotClient;
pub const DevModel = models_dev.DevModel;
pub const handleSkillCommand = skill_commands.handleSkillCommand;
pub const parseFrontmatter = skill_utils.parseFrontmatter;

comptime {
    @import("std").testing.refAllDecls(@This());
}
