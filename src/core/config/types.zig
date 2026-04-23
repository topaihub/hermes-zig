//! Configuration types for hermes-zig
//!
//! Simplified from nullclaw's config_types.zig for Personal Agent use case.
//! Focus on multi-model support, personality system, and gateway integration.

const std = @import("std");

// ── Constants ──────────────────────────────────────────────────────

/// Default context token budget for agent context management
pub const DEFAULT_AGENT_TOKEN_LIMIT: u64 = 200_000;

/// Default generation cap when model metadata doesn't define max output
pub const DEFAULT_MODEL_MAX_TOKENS: u32 = 8192;

// ── Core Configuration ─────────────────────────────────────────────

/// Main configuration structure
pub const Config = struct {
    /// LLM providers configuration
    providers: []const ProviderEntry = &.{},
    
    /// Default provider to use
    default_provider: []const u8 = "anthropic",
    
    /// Default model to use
    default_model: []const u8 = "claude-3-5-sonnet-20241022",
    
    /// Temperature for LLM generation (0.0 - 2.0)
    temperature: f32 = 0.7,
    
    /// Maximum tokens for generation
    max_tokens: ?u32 = null,
    
    /// Tools configuration
    tools: ToolsConfig = .{},
    
    /// Security configuration
    security: SecurityConfig = .{},
    
    /// Memory configuration
    memory: MemoryConfig = .{},
    
    /// Gateway configuration
    gateway: GatewayConfig = .{},
    
    /// Personality system configuration
    personality: PersonalityConfig = .{},
    
    /// Scenario routing configuration
    routing: RoutingConfig = .{},
};

// ── Provider Configuration ─────────────────────────────────────────

/// Provider entry for multi-model support
/// Adapted from nullclaw/src/config_types.zig
pub const ProviderEntry = struct {
    /// API mode for OpenAI-compatible providers
    pub const ApiMode = enum {
        chat_completions,
        responses,
        invalid,
        
        pub fn parse(raw: []const u8) ApiMode {
            if (std.mem.eql(u8, raw, "chat_completions")) return .chat_completions;
            if (std.mem.eql(u8, raw, "responses")) return .responses;
            return .invalid;
        }
        
        pub fn toSlice(self: ApiMode) []const u8 {
            return switch (self) {
                .chat_completions => "chat_completions",
                .responses => "responses",
                .invalid => "invalid",
            };
        }
    };
    
    /// Provider name (e.g., "anthropic", "openai", "moonshot")
    name: []const u8,
    
    /// API key for authentication
    api_key: ?[]const u8 = null,
    
    /// Base URL for API endpoint
    base_url: ?[]const u8 = null,
    
    /// Whether this provider supports native tool calls
    native_tools: bool = true,
    
    /// API mode (chat_completions or responses)
    api_mode: ApiMode = .chat_completions,
    
    /// User-Agent header for HTTP requests
    user_agent: ?[]const u8 = null,
    
    /// Maximum streaming prompt bytes (null = no limit)
    max_streaming_prompt_bytes: ?usize = null,
};

/// Model fallback entry for error recovery
pub const ModelFallbackEntry = struct {
    /// Primary model
    primary: []const u8,
    
    /// Fallback model if primary fails
    fallback: []const u8,
    
    /// Provider for fallback model
    fallback_provider: ?[]const u8 = null,
};

// ── Tools Configuration ────────────────────────────────────────────

pub const ToolsConfig = struct {
    /// Enabled tool sets
    enabled_toolsets: []const []const u8 = &.{},
    
    /// Disabled individual tools
    disabled_tools: []const []const u8 = &.{},
    
    /// Tool execution timeout (milliseconds)
    timeout_ms: u64 = 30000,
};

// ── Security Configuration ─────────────────────────────────────────

pub const SecurityConfig = struct {
    /// Autonomy level for command execution
    autonomy_level: AutonomyLevel = .supervised,
    
    /// Enable command approval for high-risk operations
    command_approval: bool = true,
    
    /// Enable injection scanning
    injection_scanning: bool = true,
    
    /// Enable path safety checks
    path_safety: bool = true,
    
    /// Enable audit logging
    audit_logging: bool = true,
    
    /// Audit log file path
    audit_log_path: []const u8 = "~/.hermes/audit.log",
};

/// Autonomy level for agent operations
pub const AutonomyLevel = enum {
    /// All tools execute without approval
    full,
    
    /// High-risk tools require approval
    supervised,
    
    /// All tools require approval
    restricted,
};

// ── Memory Configuration ───────────────────────────────────────────

pub const MemoryConfig = struct {
    /// Enable memory system
    enabled: bool = true,
    
    /// Memory backend ("sqlite", "markdown", "none")
    backend: []const u8 = "sqlite",
    
    /// SQLite database path
    sqlite_path: []const u8 = "~/.hermes/memory.db",
    
    /// Markdown memory directory
    markdown_dir: []const u8 = "~/.hermes/memory",
    
    /// Enable response caching
    cache_enabled: bool = true,
    
    /// Cache size (number of entries)
    cache_size: u32 = 1000,
    
    /// Memory nudge interval (number of messages)
    nudge_interval: u32 = 10,
};

// ── Gateway Configuration ──────────────────────────────────────────

pub const GatewayConfig = struct {
    /// Enable gateway server
    enabled: bool = true,
    
    /// Gateway listen address
    listen_addr: []const u8 = "127.0.0.1",
    
    /// Gateway listen port
    listen_port: u16 = 8318,
    
    /// Enable Bearer token authentication
    auth_enabled: bool = true,
    
    /// Bearer token (if null, generate random token)
    auth_token: ?[]const u8 = null,
    
    /// Enable rate limiting
    rate_limit_enabled: bool = true,
    
    /// Rate limit: max requests per window
    rate_limit_max_requests: u32 = 60,
    
    /// Rate limit: window size (seconds)
    rate_limit_window_secs: u64 = 60,
    
    /// Request timeout (seconds)
    request_timeout_secs: u64 = 30,
    
    /// Maximum request body size (bytes)
    max_body_size: usize = 65_536,
    
    /// Enable WebSocket for real-time sync
    websocket_enabled: bool = true,
};

// ── Personality Configuration ──────────────────────────────────────

pub const PersonalityConfig = struct {
    /// Enable personality system
    enabled: bool = true,
    
    /// Personality configuration file path
    config_path: []const u8 = "~/.hermes/personalities.yaml",
    
    /// Default personality ID
    default_personality: []const u8 = "default",
    
    /// Enable personality memory isolation
    memory_isolation: bool = true,
};

// ── Routing Configuration ──────────────────────────────────────────

pub const RoutingConfig = struct {
    /// Enable scenario-based routing
    enabled: bool = true,
    
    /// Routing rules configuration file
    rules_path: []const u8 = "~/.hermes/routing.yaml",
    
    /// Routing rules
    rules: []const RoutingRule = &.{},
};

/// Routing rule for scenario-based model selection
pub const RoutingRule = struct {
    /// Scenario type
    scenario: Scenario,
    
    /// Provider to use for this scenario
    provider: []const u8,
    
    /// Model to use for this scenario
    model: []const u8,
    
    /// Fallback model if primary fails
    fallback: ?[]const u8 = null,
};

/// Scenario types for routing
pub const Scenario = enum {
    /// Writing and content creation
    writing,
    
    /// Tool calling and execution
    tool_calling,
    
    /// Deep reasoning and analysis
    reasoning,
    
    /// Casual conversation (high-frequency, lightweight)
    casual,
};

// ── Validation Functions ───────────────────────────────────────────

/// Validate provider base URL
pub fn isValidBaseUrl(raw: []const u8) bool {
    const trimmed = std.mem.trim(u8, raw, " \t\r\n");
    if (trimmed.len == 0) return false;
    if (std.mem.indexOfAny(u8, trimmed, " \t\r\n?#") != null) return false;
    
    const uri = std.Uri.parse(trimmed) catch return false;
    if (uri.query != null or uri.fragment != null) return false;
    
    const is_https = std.ascii.eqlIgnoreCase(uri.scheme, "https");
    const is_http = std.ascii.eqlIgnoreCase(uri.scheme, "http");
    if (!is_https and !is_http) return false;
    
    // For hermes (personal use), allow HTTP for localhost
    if (is_http) {
        const host = uri.host orelse return false;
        const host_str = switch (host) {
            .raw => |h| h,
            .percent_encoded => |h| h,
        };
        if (!isLocalHost(host_str)) return false;
    }
    
    return true;
}

/// Check if host is localhost
fn isLocalHost(host: []const u8) bool {
    return std.mem.eql(u8, host, "localhost") or
           std.mem.eql(u8, host, "127.0.0.1") or
           std.mem.eql(u8, host, "::1") or
           std.mem.eql(u8, host, "[::1]");
}

// ── Tests ──────────────────────────────────────────────────────────

test "ProviderEntry.ApiMode.parse" {
    try std.testing.expectEqual(ProviderEntry.ApiMode.chat_completions, ProviderEntry.ApiMode.parse("chat_completions"));
    try std.testing.expectEqual(ProviderEntry.ApiMode.responses, ProviderEntry.ApiMode.parse("responses"));
    try std.testing.expectEqual(ProviderEntry.ApiMode.invalid, ProviderEntry.ApiMode.parse("unknown"));
}

test "ProviderEntry.ApiMode.toSlice" {
    try std.testing.expectEqualStrings("chat_completions", ProviderEntry.ApiMode.chat_completions.toSlice());
    try std.testing.expectEqualStrings("responses", ProviderEntry.ApiMode.responses.toSlice());
    try std.testing.expectEqualStrings("invalid", ProviderEntry.ApiMode.invalid.toSlice());
}

test "isValidBaseUrl - valid HTTPS" {
    try std.testing.expect(isValidBaseUrl("https://api.anthropic.com"));
    try std.testing.expect(isValidBaseUrl("https://api.openai.com/v1"));
}

test "isValidBaseUrl - valid localhost HTTP" {
    try std.testing.expect(isValidBaseUrl("http://localhost:8080"));
    try std.testing.expect(isValidBaseUrl("http://127.0.0.1:3000"));
}

test "isValidBaseUrl - invalid" {
    try std.testing.expect(!isValidBaseUrl(""));
    try std.testing.expect(!isValidBaseUrl("not a url"));
    try std.testing.expect(!isValidBaseUrl("http://example.com")); // HTTP for non-localhost
    try std.testing.expect(!isValidBaseUrl("https://api.com?query=1")); // Has query
}

test "isLocalHost" {
    try std.testing.expect(isLocalHost("localhost"));
    try std.testing.expect(isLocalHost("127.0.0.1"));
    try std.testing.expect(isLocalHost("::1"));
    try std.testing.expect(isLocalHost("[::1]"));
    try std.testing.expect(!isLocalHost("example.com"));
}

test "Config default values" {
    const config = Config{};
    try std.testing.expectEqualStrings("anthropic", config.default_provider);
    try std.testing.expectEqual(@as(f32, 0.7), config.temperature);
    try std.testing.expect(config.tools.timeout_ms == 30000);
    try std.testing.expect(config.security.command_approval);
    try std.testing.expect(config.memory.enabled);
    try std.testing.expect(config.gateway.enabled);
    try std.testing.expect(config.personality.enabled);
    try std.testing.expect(config.routing.enabled);
}

test "AutonomyLevel enum" {
    const full: AutonomyLevel = .full;
    const supervised: AutonomyLevel = .supervised;
    const restricted: AutonomyLevel = .restricted;
    
    try std.testing.expect(full != supervised);
    try std.testing.expect(supervised != restricted);
}

test "Scenario enum" {
    const writing: Scenario = .writing;
    const tool_calling: Scenario = .tool_calling;
    const reasoning: Scenario = .reasoning;
    const casual: Scenario = .casual;
    
    try std.testing.expect(writing != tool_calling);
    try std.testing.expect(reasoning != casual);
}
