pub const Config = struct {
    model: []const u8 = "openrouter/nous-hermes",
    provider: []const u8 = "openrouter",
    api_base_url: []const u8 = "",
    api_key: []const u8 = "",
    temperature: f32 = 0.7,
    max_tokens: ?u32 = null,
    models: []const []const u8 = &.{},
    reasoning: ReasoningConfig = .{},
    terminal: TerminalConfig = .{},
    tools: ToolsConfig = .{},
    security: SecurityConfig = .{},
    memory: MemoryConfig = .{},
    logging: LoggingConfig = .{},
    personality: []const u8 = "",
};

pub const ReasoningConfig = struct { enabled: bool = false, effort: []const u8 = "medium" };
pub const TerminalConfig = struct { backend: []const u8 = "local", timeout_ms: u64 = 30000, docker_image: []const u8 = "", ssh_host: []const u8 = "", ssh_user: []const u8 = "", ssh_port: u16 = 22 };
pub const ToolsConfig = struct { enabled_toolsets: []const []const u8 = &.{}, disabled_tools: []const []const u8 = &.{} };
pub const SecurityConfig = struct { command_approval: bool = true, injection_scanning: bool = true };
pub const MemoryConfig = struct { enabled: bool = true, nudge_interval: u32 = 10 };
/// Log format: "text" (human-readable), "json" (JSONL), "both" (two files)
pub const LoggingConfig = struct {
    log_format: []const u8 = "text",
    log_dir: []const u8 = "logs",
    max_file_bytes: u64 = 100 * 1024 * 1024,
};
