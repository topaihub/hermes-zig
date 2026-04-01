# hermes-zig — Hermes Agent Zig Rewrite Master Design

## Overview

Rewrite [hermes-agent](https://github.com/nousresearch/hermes-agent) (Python, 156K lines) in Zig using [zig-framework](https://github.com/topaihub/zig-framework.git) (`codex/framework-tooling-runtime-vnext` branch) as the application runtime foundation.

Goal: full feature parity — Agent loop, 40+ tools, 14 messaging platforms, 6 terminal backends, skills system, memory, cron, ACP, RL environments.

## Design Principles (from zig特性设计.md)

1. **Isolate change points** — vtable for runtime-determined types (LLM providers, tools, platforms), tagged union for compile-time-known variants (terminal backends)
2. **Compile-time safety** — comptime validation of tool interfaces, exhaustive switch on tagged unions
3. **Deployment simplicity** — single static binary, zero runtime dependencies, Zig cross-compilation
4. **Arena allocator pattern** — per-request arena for LLM responses, one-shot deallocation

## zig-framework Reuse Map

| Framework Module | Usage in hermes-zig |
|-----------------|-------------------|
| `runtime.AppContext` | Root dependency assembly |
| `core.Logger` + `observability` | RequestTrace, MethodTrace, StepTrace, structured logging |
| `effects.HttpClient` | LLM API calls, platform API calls |
| `effects.ProcessRunner` | Terminal tool execution (local backend) |
| `effects.FileSystem` | File tools, config loading, skill I/O |
| `effects.Clock` | Cron scheduling, timeouts |
| `effects.EnvProvider` | Environment variable access |
| `tooling.ToolRegistry` + `ToolRunner` | Tool registration and dispatch |
| `workflow.WorkflowRunner` | Multi-step tool orchestration |
| `agentkit.ProviderRegistry` | LLM provider registration |
| `config.ConfigStore` | Configuration management |
| `app.CommandDispatcher` | CLI command dispatch |
| `contracts.Envelope` | Structured API responses |

## Core Architecture (from zig设计.md)

### Four Core Interfaces

```
LlmClient (vtable)          — LLM provider abstraction
  ├── OpenAICompatClient     — OpenRouter, OpenAI, Nous Portal, z.ai, Kimi, MiniMax
  └── AnthropicClient        — Anthropic native API

ToolHandler (vtable)         — Tool execution abstraction
  ├── Static tools           — comptime registered (bash, file_read, file_write, etc.)
  └── Dynamic tools          — runtime registered (MCP tools, skill-backed tools)

TerminalBackend (tagged union) — Execution environment
  ├── .local                 — Local shell
  ├── .docker                — Docker container
  ├── .ssh                   — SSH remote
  ├── .daytona               — Daytona serverless
  ├── .singularity           — Singularity container
  └── .modal                 — Modal serverless

PlatformAdapter (vtable)     — Messaging platform abstraction
  ├── TelegramAdapter
  ├── DiscordAdapter
  ├── SlackAdapter
  ├── WhatsAppAdapter
  ├── SignalAdapter
  ├── EmailAdapter
  ├── MatrixAdapter
  ├── FeishuAdapter
  ├── DingtalkAdapter
  ├── WecomAdapter
  ├── HomeAssistantAdapter
  ├── SmsAdapter
  ├── MattermostAdapter
  └── WebhookAdapter
```

### Data Flow

```
Platform/CLI → IncomingMessage → MessageQueue
  → AgentLoop (LlmClient.complete → ToolHandler.dispatch → loop)
  → OutgoingMessage → Platform/CLI
```

## Sub-Project Decomposition

| # | Sub-Project | Files | Description |
|---|-------------|-------|-------------|
| 1 | Project scaffold + core types | 5 | build.zig, framework dep, core types (Message, Role, Platform, ToolCall, TokenUsage, HermesError) |
| 2 | Configuration system | 5 | JSON config loading, env var expansion, SOUL.md loading |
| 3 | SQLite state storage | 4 | @cImport sqlite3, session CRUD, message history, FTS5 search |
| 4 | LLM client layer | 6 | LlmClient vtable, OpenAICompatClient, AnthropicClient, streaming (SSE + callback), provider registry |
| 5 | Tool system core | 8 | ToolHandler vtable, ToolRegistry (static + dynamic), ToolContext, comptime validation, tool schema |
| 6 | Terminal backends | 8 | TerminalBackend tagged union, Local, Docker, SSH, Daytona, Singularity, Modal |
| 7 | Built-in tools | 20 | bash, file_read, file_write, file_edit, web_search, browser, code_execution, vision, todo, delegate, send_message, etc. |
| 8 | MCP integration | 4 | MCP client (stdio + SSE), dynamic tool registration, MCP server (expose tools) |
| 9 | Agent loop | 6 | AIAgent core loop, prompt builder, context compressor, prompt caching, retry/fallback |
| 10 | CLI interface | 8 | TUI with multiline editing, slash commands, streaming display, history, interrupt |
| 11 | Gateway core | 6 | PlatformAdapter vtable, MessageQueue, session routing, delivery, pairing, hooks |
| 12 | Gateway platforms | 14 | Telegram, Discord, Slack, WhatsApp, Signal, Email, Matrix, Feishu, Dingtalk, Wecom, HA, SMS, Mattermost, Webhook |
| 13 | Skills system | 6 | Skill loading (SKILL.md), skill execution, skill creation, Skills Hub client, skill sync, skill guard |
| 14 | Memory system | 4 | Persistent memory (MEMORY.md), user modeling, session search (FTS5), memory nudges |
| 15 | Cron scheduler | 3 | Job storage, scheduler loop, platform delivery |
| 16 | ACP adapter | 4 | ACP server, session management, tool exposure, auth |
| 17 | Security | 4 | Command approval, injection scanning, path traversal prevention, env filtering, credential files |
| 18 | Trajectory & RL | 4 | Trajectory format, compression, batch runner, Atropos environments |
| 19 | Integration & entry | 3 | main.zig entry, signal handling, graceful shutdown |

**Total: ~120 files estimated**

## Implementation Order

```
Phase 1 (Foundation):     1 → 2 → 3 → 4 → 5 → 6
Phase 2 (Agent Core):     7 → 8 → 9 → 10
Phase 3 (Gateway):        11 → 12
Phase 4 (Intelligence):   13 → 14 → 15
Phase 5 (Integration):    16 → 17 → 18 → 19
```

## Module Design Details

### SP-1: Core Types

```zig
// src/core/types.zig
pub const Platform = enum { telegram, discord, slack, whatsapp, signal, email, matrix, feishu, dingtalk, wecom, homeassistant, sms, mattermost, webhook, cli };
pub const Role = enum { system, user, assistant, tool };
pub const Message = struct { role: Role, content: []const u8, tool_call_id: ?[]const u8 = null, name: ?[]const u8 = null };
pub const ToolCall = struct { id: []const u8, name: []const u8, arguments: []const u8 };
pub const TokenUsage = struct { prompt_tokens: u32, completion_tokens: u32, total_tokens: u32 };
pub const SessionSource = struct { platform: Platform, chat_id: []const u8, user_id: ?[]const u8 = null };
```

### SP-3: SQLite Storage

```zig
// src/state/sqlite.zig — @cImport("sqlite3.h")
const c = @cImport({ @cInclude("sqlite3.h"); });
pub const Database = struct {
    db: *c.sqlite3,
    pub fn open(path: []const u8) !Database
    pub fn exec(self: *Database, sql: []const u8) !void
    pub fn close(self: *Database) void
};
```

### SP-4: LLM Client (from zig特性设计.md)

```zig
// src/llm/interface.zig
pub const LlmClient = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    pub const VTable = struct {
        complete: *const fn (ptr: *anyopaque, req: CompletionRequest) anyerror!CompletionResponse,
        completeStream: *const fn (ptr: *anyopaque, req: CompletionRequest, callback: StreamCallback) anyerror!CompletionResponse,
        deinit: *const fn (ptr: *anyopaque) void,
    };
};
pub const CompletionResponse = struct {
    content: ?[]const u8,
    tool_calls: ?[]ToolCall,
    usage: TokenUsage,
    arena: std.heap.ArenaAllocator, // one-shot deallocation
};
pub const StreamCallback = struct {
    ctx: *anyopaque,
    on_delta: *const fn (ctx: *anyopaque, content: []const u8, done: bool) void,
};
```

### SP-5: Tool System (from zig特性设计.md)

```zig
// src/tools/interface.zig
pub const ToolHandler = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    schema: ToolSchema,
    pub const VTable = struct {
        execute: *const fn (ptr: *anyopaque, args: std.json.Value, ctx: *const ToolContext) anyerror![]const u8,
        deinit: *const fn (ptr: *anyopaque) void,
    };
};
// comptime helper: auto-generate vtable from struct with SCHEMA + execute
pub fn makeToolHandler(comptime T: type, instance: *T) ToolHandler { ... }
// Registry: static (comptime, no lock) + dynamic (runtime, RwLock)
pub const ToolRegistry = struct {
    static: []const ToolHandler,
    dynamic: std.StringHashMap(ToolHandler),
    rwlock: std.Thread.RwLock,
};
```

### SP-6: Terminal Backend (from zig特性设计.md)

```zig
// src/terminal/backend.zig
pub const TerminalBackend = union(enum) {
    local: LocalBackend,
    docker: DockerBackend,
    ssh: SshBackend,
    daytona: DaytonaBackend,
    singularity: SingularityBackend,
    modal: ModalBackend,
    pub fn execute(self: *TerminalBackend, allocator: std.mem.Allocator, cmd: []const u8, cwd: ?[]const u8, timeout_ms: ?u64) anyerror!ExecResult { ... }
};
```

### SP-9: Agent Loop

```zig
// src/agent/loop.zig
pub const AgentLoop = struct {
    llm: LlmClient,
    tools: *ToolRegistry,
    state: *StateDatabase,
    config: *Config,
    pub fn run(self: *AgentLoop, session: *Session, input: Message) !Message {
        // 1. Build prompt (system + history + tools schema)
        // 2. Call LLM
        // 3. If tool_calls: execute tools, append results, goto 2
        // 4. Return assistant message
    }
};
```

### SP-11: Gateway (from zig特性设计.md)

```zig
// src/gateway/platform.zig
pub const PlatformAdapter = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    pub const VTable = struct {
        platform: *const fn (ptr: *anyopaque) Platform,
        connect: *const fn (ptr: *anyopaque) anyerror!void,
        send: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, chat_id: []const u8, content: []const u8) anyerror!SendResult,
        set_message_handler: *const fn (ptr: *anyopaque, handler: MessageHandler) void,
        deinit: *const fn (ptr: *anyopaque) void,
    };
};
// MessageQueue: platform thread → agent thread
pub const MessageQueue = struct {
    mutex: std.Thread.Mutex,
    cond: std.Thread.Condition,
    items: std.ArrayList(IncomingMessage),
};
```

## File Structure

```
hermes-zig/
├── build.zig
├── build.zig.zon
├── AGENTS.md
├── config.example.json
├── src/
│   ├── main.zig
│   ├── core/
│   │   ├── root.zig
│   │   └── types.zig              # Platform, Role, Message, ToolCall, TokenUsage, SessionSource, HermesError
│   ├── config/
│   │   ├── root.zig
│   │   ├── types.zig              # Full config struct
│   │   ├── loader.zig             # JSON loading + env expansion
│   │   └── soul.zig               # SOUL.md persona loading
│   ├── state/
│   │   ├── root.zig
│   │   ├── sqlite.zig             # SQLite C bindings
│   │   ├── database.zig           # Session/message CRUD
│   │   └── search.zig             # FTS5 full-text search
│   ├── llm/
│   │   ├── root.zig
│   │   ├── interface.zig          # LlmClient vtable, CompletionRequest/Response, StreamCallback
│   │   ├── openai_compat.zig      # OpenAI-compatible client (OpenRouter, OpenAI, Nous, z.ai, Kimi, MiniMax)
│   │   ├── anthropic.zig          # Anthropic native client
│   │   ├── streaming.zig          # SSE parser, stream accumulator
│   │   └── provider_registry.zig  # Provider factory from config
│   ├── tools/
│   │   ├── root.zig
│   │   ├── interface.zig          # ToolHandler vtable, ToolSchema, ToolContext, makeToolHandler
│   │   ├── registry.zig           # ToolRegistry (static + dynamic)
│   │   ├── toolsets.zig           # Tool groupings and presets
│   │   ├── builtin/
│   │   │   ├── root.zig
│   │   │   ├── bash.zig           # Terminal command execution
│   │   │   ├── file_read.zig      # Read file contents
│   │   │   ├── file_write.zig     # Write/create files
│   │   │   ├── file_edit.zig      # Patch-based file editing
│   │   │   ├── file_tools.zig     # ls, find, grep, tree
│   │   │   ├── web_search.zig     # Web search (Tavily, DuckDuckGo)
│   │   │   ├── browser.zig        # Browser automation
│   │   │   ├── code_execution.zig # Python/JS code execution
│   │   │   ├── vision.zig         # Image analysis
│   │   │   ├── todo.zig           # Todo list management
│   │   │   ├── delegate.zig       # Subagent delegation
│   │   │   ├── send_message.zig   # Cross-platform messaging
│   │   │   ├── memory.zig         # Memory read/write
│   │   │   ├── clarify.zig        # Ask user for clarification
│   │   │   ├── image_gen.zig      # Image generation
│   │   │   ├── transcription.zig  # Audio transcription
│   │   │   ├── tts.zig            # Text-to-speech
│   │   │   ├── voice_mode.zig     # Voice conversation mode
│   │   │   └── cronjob.zig        # Cron job management
│   │   └── mcp/
│   │       ├── root.zig
│   │       ├── client.zig         # MCP client (stdio + SSE transport)
│   │       ├── server.zig         # MCP server (expose tools)
│   │       └── discovery.zig      # Dynamic tool registration from MCP
│   ├── terminal/
│   │   ├── root.zig
│   │   ├── backend.zig            # TerminalBackend tagged union
│   │   ├── local.zig
│   │   ├── docker.zig
│   │   ├── ssh.zig
│   │   ├── daytona.zig
│   │   ├── singularity.zig
│   │   └── modal.zig
│   ├── agent/
│   │   ├── root.zig
│   │   ├── loop.zig               # AIAgent core loop
│   │   ├── prompt_builder.zig     # System prompt + tool schemas + history assembly
│   │   ├── context_compressor.zig # Context window management
│   │   ├── prompt_caching.zig     # Prompt caching for Anthropic
│   │   └── credential_pool.zig    # Multi-key rotation
│   ├── cli/
│   │   ├── root.zig
│   │   ├── tui.zig                # Terminal UI (raw mode, multiline, streaming)
│   │   ├── commands.zig           # Slash commands (/model, /new, /skills, /tools, etc.)
│   │   ├── display.zig            # Streaming output display, tool call rendering
│   │   ├── history.zig            # Command history
│   │   ├── setup.zig              # Setup wizard
│   │   ├── auth.zig               # Auth commands (API key management)
│   │   ├── profiles.zig           # Profile management
│   │   └── doctor.zig             # Diagnostic tool
│   ├── gateway/
│   │   ├── root.zig
│   │   ├── platform.zig           # PlatformAdapter vtable, MessageHandler, MessageQueue
│   │   ├── session.zig            # Session routing and management
│   │   ├── delivery.zig           # Message delivery (chunking, formatting)
│   │   ├── pairing.zig            # DM pairing for auth
│   │   ├── hooks.zig              # Gateway hooks system
│   │   └── platforms/
│   │       ├── root.zig
│   │       ├── telegram.zig
│   │       ├── discord.zig
│   │       ├── slack.zig
│   │       ├── whatsapp.zig
│   │       ├── signal.zig
│   │       ├── email.zig
│   │       ├── matrix.zig
│   │       ├── feishu.zig
│   │       ├── dingtalk.zig
│   │       ├── wecom.zig
│   │       ├── homeassistant.zig
│   │       ├── sms.zig
│   │       ├── mattermost.zig
│   │       └── webhook.zig
│   ├── skills/
│   │   ├── root.zig
│   │   ├── loader.zig             # SKILL.md parsing
│   │   ├── executor.zig           # Skill execution
│   │   ├── creator.zig            # Autonomous skill creation
│   │   ├── hub.zig                # Skills Hub client
│   │   ├── sync.zig               # Skill sync
│   │   └── guard.zig              # Skill safety guard
│   ├── memory/
│   │   ├── root.zig
│   │   ├── persistent.zig         # MEMORY.md read/write
│   │   ├── user_model.zig         # User modeling (Honcho integration)
│   │   ├── session_search.zig     # FTS5 session search
│   │   └── nudge.zig              # Memory persistence nudges
│   ├── cron/
│   │   ├── root.zig
│   │   ├── scheduler.zig          # Cron scheduler loop
│   │   └── jobs.zig               # Job storage and execution
│   ├── acp/
│   │   ├── root.zig
│   │   ├── server.zig             # ACP protocol server
│   │   ├── session.zig            # ACP session management
│   │   └── tools.zig              # ACP tool exposure
│   ├── security/
│   │   ├── root.zig
│   │   ├── approval.zig           # Command approval system
│   │   ├── injection.zig          # Injection scanning
│   │   ├── path_safety.zig        # Path traversal prevention
│   │   └── env_filter.zig         # Environment variable filtering
│   └── trajectory/
│       ├── root.zig
│       ├── format.zig             # Trajectory data format
│       ├── compressor.zig         # Trajectory compression
│       └── batch_runner.zig       # Batch trajectory generation
```

## Key Design Decisions

1. **LlmClient uses Arena allocator** — each completion response owns an arena; caller calls `response.deinit()` to free everything at once
2. **ToolRegistry split** — static tools (comptime array, no lock) + dynamic tools (HashMap + RwLock) for MCP
3. **TerminalBackend is tagged union** — 6 variants, exhaustive switch, compiler enforces handling all backends
4. **PlatformAdapter runs in dedicated thread** — communicates with agent via MessageQueue (Mutex + Condition)
5. **SQLite via @cImport** — zero FFI wrapper overhead, direct C API calls
6. **JSON config** — std.json parsing, no YAML dependency
7. **Framework integration** — AppContext for logging/events, effects for I/O, tooling for tool dispatch, agentkit for providers
