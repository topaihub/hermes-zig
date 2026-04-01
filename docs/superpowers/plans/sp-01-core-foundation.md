# SP-1: Core Foundation — Detailed Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans.

**Goal:** Project scaffold with zig-framework dependency, core types, JSON config, SQLite state storage.

**Architecture:** Single `core/` module as the "vocabulary layer" — all other modules depend on it, it depends on nobody except framework.

**Tech Stack:** Zig 0.15.2, zig-framework (vnext), std.json, SQLite via @cImport

---

## Task 1: Project Scaffold

**Files:** build.zig.zon, build.zig, src/main.zig, .gitignore

- [ ] Fetch framework dependency hash: `zig fetch https://github.com/topaihub/zig-framework/archive/refs/heads/codex/framework-tooling-runtime-vnext.tar.gz`
- [ ] Create build.zig.zon with framework dep + hash + fingerprint
- [ ] Create build.zig: framework module import, exe target, test target, run step
- [ ] Create src/main.zig with framework import test
- [ ] Create .gitignore (.zig-cache/, zig-out/, *.o)
- [ ] `zig build test` passes
- [ ] Commit: `feat: project scaffold with zig-framework dependency`

## Task 2: Core Types

**Files:** src/core/types.zig, src/core/root.zig

- [ ] Define Platform enum (15 variants: telegram, discord, slack, whatsapp, signal, email, matrix, feishu, dingtalk, wecom, homeassistant, sms, mattermost, webhook, cli) with `displayName()` method
- [ ] Define Role enum (system, user, assistant, tool)
- [ ] Define Message struct (role, content, tool_call_id, name — all []const u8 with defaults)
- [ ] Define ToolCall struct (id, name, arguments — raw JSON string for lazy parsing)
- [ ] Define TokenUsage struct (prompt_tokens, completion_tokens, total_tokens — u32)
- [ ] Define SessionSource struct (platform, chat_id, user_id, thread_id, platform_metadata — all optional except platform and chat_id)
- [ ] Define HermesError error set (LlmApiError, LlmRateLimited, LlmContextTooLong, ToolNotFound, ToolExecutionFailed, ToolTimeout, GatewayConnectionFailed, SecurityInjectionDetected, ConfigParseError, etc.)
- [ ] Define reasoning effort: `pub const VALID_REASONING_EFFORTS = [_][]const u8{ "xhigh", "high", "medium", "low", "minimal" };`
- [ ] Define provider URLs as constants (OPENROUTER_BASE_URL, NOUS_API_BASE_URL, etc.)
- [ ] Create root.zig with exports + refAllDecls test
- [ ] Update main.zig: `pub const core = @import("core/root.zig");`
- [ ] Tests: Platform.displayName, Role values, Message defaults, SessionSource construction
- [ ] Commit: `feat(core): add core type definitions`

## Task 3: Configuration

**Files:** src/core/config.zig, src/core/config_loader.zig, src/core/soul.zig

- [ ] Define Config struct matching hermes-agent's cli-config.yaml structure:
  ```zig
  pub const Config = struct {
      model: []const u8 = "openrouter/nous-hermes",
      provider: []const u8 = "openrouter",
      api_base_url: []const u8 = "",
      temperature: f32 = 0.7,
      max_tokens: ?u32 = null,
      reasoning: ?ReasoningConfig = null,
      terminal: TerminalConfig = .{},
      tools: ToolsConfig = .{},
      gateway: GatewayConfig = .{},
      cron: CronConfig = .{},
      security: SecurityConfig = .{},
      memory: MemoryConfig = .{},
      skills: SkillsConfig = .{},
      personality: []const u8 = "",
      context_files: []const []const u8 = &.{},
  };
  ```
- [ ] Define sub-configs: TerminalConfig (backend, timeout, docker_image, ssh_host, etc.), ToolsConfig (enabled_toolsets, disabled_tools, approval_patterns), GatewayConfig (platforms map), SecurityConfig (command_approval, injection_scanning), MemoryConfig (enabled, nudge_interval), SkillsConfig (auto_create, hub_url), ReasoningConfig (enabled, effort), CronConfig (enabled, jobs)
- [ ] Implement config_loader.zig: `loadFromFile(path, allocator) !LoadedConfig`, `loadFromString(json, allocator) !LoadedConfig`
- [ ] Implement env var expansion: scan all string fields for `$VAR` and `${VAR}`, replace with `std.process.getEnvVarOwned`
- [ ] Implement soul.zig: `loadSoul(allocator, hermes_home) ![]u8` — read SOUL.md from hermes_home, return content or default persona
- [ ] Implement `getHermesHome() []const u8` — read HERMES_HOME env var, fallback to ~/.hermes
- [ ] Tests: config defaults, JSON parsing, env expansion, soul loading
- [ ] Commit: `feat(core): add configuration and SOUL.md loading`

## Task 4: SQLite State Storage

**Files:** src/core/sqlite.zig, src/core/database.zig, src/core/search.zig

- [ ] sqlite.zig: @cImport sqlite3.h, wrap core functions:
  ```zig
  const c = @cImport({ @cInclude("sqlite3.h"); });
  pub const Database = struct {
      db: *c.sqlite3,
      pub fn open(path: [*:0]const u8) !Database
      pub fn exec(self: *Database, sql: [*:0]const u8) !void
      pub fn prepare(self: *Database, sql: [*:0]const u8) !Statement
      pub fn close(self: *Database) void
  };
  pub const Statement = struct {
      stmt: *c.sqlite3_stmt,
      pub fn step(self: *Statement) !StepResult
      pub fn bindText(self: *Statement, idx: c_int, text: []const u8) !void
      pub fn bindInt(self: *Statement, idx: c_int, val: i64) !void
      pub fn columnText(self: *Statement, idx: c_int) ?[]const u8
      pub fn columnInt(self: *Statement, idx: c_int) i64
      pub fn reset(self: *Statement) !void
      pub fn finalize(self: *Statement) void
  };
  ```
- [ ] database.zig: Schema creation (sessions + messages tables matching Python's SCHEMA_SQL), WAL mode enable
  - `createSession(id, source, model) !void`
  - `getSession(id) !?Session`
  - `listSessions(source, limit) ![]Session`
  - `appendMessage(session_id, role, content, tool_call_id, tool_calls_json) !void`
  - `getMessages(session_id, limit) ![]StoredMessage`
  - `deleteSession(id) !void`
  - `updateSessionStats(id, message_count, tool_call_count, input_tokens, output_tokens) !void`
- [ ] search.zig: FTS5 virtual table creation, `searchMessages(query, limit) ![]SearchResult`
- [ ] NOTE: build.zig needs to link sqlite3: `exe.linkSystemLibrary("sqlite3"); exe.linkLibC();`
- [ ] Tests: open/close, create session, append messages, search
- [ ] Commit: `feat(core): add SQLite state storage with FTS5 search`

## Task 5: Wire Core into Main

**Files:** src/main.zig (update)

- [ ] Update main.zig to: load config from ~/.hermes/config.json, init SQLite database, log startup
- [ ] Commit: `feat(core): wire core module into main entry point`
