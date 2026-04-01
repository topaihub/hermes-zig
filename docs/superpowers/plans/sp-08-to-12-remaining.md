# SP-8: ACP Adapter — Detailed Implementation Plan

> **For agentic workers:** Read Python files: acp_adapter/*.py

**Goal:** Agent Client Protocol server for editor integration.

---

## Task 1: ACP Server

**Files:** src/interface/acp/root.zig, server.zig, session.zig, tools.zig

- [ ] ACP protocol: HTTP server with SSE for streaming
- [ ] Endpoints:
  - POST /sessions — create session
  - POST /sessions/{id}/messages — send message, get response (SSE stream)
  - GET /sessions/{id} — get session info
  - DELETE /sessions/{id} — end session
  - GET /tools — list available tools
  - POST /tools/{name}/execute — execute tool directly
- [ ] session.zig: Map ACP sessions to AgentLoop sessions
- [ ] tools.zig: Expose ToolRegistry tools via ACP tool listing format
- [ ] Auth: API key in Authorization header
- [ ] Use the HTTP server from zig-proxy-api pattern (or framework's effects)
- [ ] Tests: create session, send message, verify response format
- [ ] Commit: `feat(acp): add ACP adapter for editor integration`


# SP-9: Skills + Memory + Cron — Detailed Implementation Plan

> **For agentic workers:** Read Python files: tools/skills_tool.py, tools/skills_hub.py, tools/skills_guard.py, tools/memory_tool.py, tools/session_search_tool.py, cron/scheduler.py, cron/jobs.py

**Goal:** Intelligence layer — skills system, persistent memory, cron scheduler.

---

## Task 1: Skills Loader + Executor

**Files:** src/intelligence/root.zig, skills_loader.zig, skills_executor.zig

- [ ] skills_loader.zig: Parse SKILL.md files
  - Read file, split frontmatter (between `---` markers) from body
  - Parse frontmatter as key-value pairs (name, description, trigger conditions)
  - Return SkillDefinition: name, description, conditions, body (markdown)
- [ ] Scan skills directories: ~/.hermes/skills/, project ./skills/
- [ ] Build skills index: list of (name, description, conditions) for prompt injection
- [ ] skills_executor.zig: When agent decides to use a skill, inject skill body into system prompt for next turn
- [ ] Tests: parse SKILL.md, build index
- [ ] Commit: `feat(intelligence): add skills loader and executor`

## Task 2: Skills Creator + Hub + Sync + Guard

**Files:** src/intelligence/skills_creator.zig, skills_hub.zig, skills_sync.zig, skills_guard.zig

- [ ] skills_creator.zig: After complex multi-step task, agent creates SKILL.md summarizing the procedure. Write to ~/.hermes/skills/
- [ ] skills_hub.zig: HTTP client to agentskills.io — list skills, download skill, upload skill
- [ ] skills_sync.zig: Pull new skills from hub, push local skills
- [ ] skills_guard.zig: Before executing a skill, check for dangerous patterns (shell commands, file deletions, network access). Warn or block.
- [ ] Tests for each
- [ ] Commit: `feat(intelligence): add skills creator, hub, sync, guard`

## Task 3: Persistent Memory

**Files:** src/intelligence/memory_persistent.zig, user_model.zig, session_search.zig, memory_nudge.zig

- [ ] memory_persistent.zig: Read/write/append MEMORY.md in ~/.hermes/. Sections: ## Facts, ## Preferences, ## Projects
- [ ] user_model.zig: Read/write USER.md. Optional Honcho integration (HTTP API to honcho server for dialectic user modeling)
- [ ] session_search.zig: FTS5 search across all sessions in SQLite. Return ranked results with snippets.
- [ ] memory_nudge.zig: Every N turns, inject a subtle prompt asking agent to persist important information from the conversation. Configurable interval.
- [ ] Tests: memory CRUD, search, nudge trigger
- [ ] Commit: `feat(intelligence): add persistent memory and session search`

## Task 4: Cron Scheduler

**Files:** src/intelligence/cron_scheduler.zig, cron_jobs.zig

- [ ] cron_jobs.zig: SQLite table for jobs (id, cron_expression, command, platform, chat_id, last_run, next_run, enabled)
  - CRUD operations
  - Cron expression parser: `minute hour day month weekday` with * and ranges
  - `nextRunTime(expression, after) i64` — calculate next execution time
- [ ] cron_scheduler.zig: Scheduler loop
  - Check every 60 seconds for due jobs
  - For each due job: create temporary session, run AgentLoop with job command, deliver result to configured platform
  - Update last_run, calculate next_run
- [ ] Run scheduler in dedicated thread
- [ ] Tests: cron expression parsing, next run calculation, job CRUD
- [ ] Commit: `feat(intelligence): add cron scheduler`


# SP-10: Security — Detailed Implementation Plan

> **For agentic workers:** Read Python files: tools/tirith_security.py, tools/approval.py, tools/env_passthrough.py

**Goal:** Command approval, injection scanning, path safety, env filtering.

---

## Task 1: Security Module

**Files:** src/security/root.zig, approval.zig, injection.zig, path_safety.zig, env_filter.zig

- [ ] approval.zig: Command approval system
  - Allowlist patterns (glob matching): `["git *", "npm *", "cargo *"]`
  - `checkApproval(command, patterns) ApprovalResult` — .allowed, .needs_approval, .denied
  - Interactive approval: prompt user (CLI) or send approval request (gateway)
  - Approval cache: remember approved commands for session duration
- [ ] injection.zig: Prompt injection detection
  - Scan tool outputs for injection patterns (from Python's _CONTEXT_THREAT_PATTERNS):
    - `ignore previous instructions`
    - `system prompt override`
    - `disregard your rules`
    - Hidden HTML comments with instructions
    - Invisible Unicode characters (zero-width spaces)
  - `scanForInjection(text) ?InjectionAlert` — return alert with pattern name and location
- [ ] path_safety.zig: Path traversal prevention
  - `resolveSafePath(base_dir, requested_path) ![]const u8` — resolve to absolute, verify it's under base_dir
  - Reject `..` traversal, symlink escape, null bytes
- [ ] env_filter.zig: Environment variable filtering
  - Blocklist: PASSWORD, SECRET, TOKEN, KEY, CREDENTIAL, API_KEY, PRIVATE_KEY
  - `filterEnv(env_map) filtered_map` — remove blocklisted vars
  - `isSensitiveKey(key) bool`
- [ ] Tests: approval patterns, injection detection, path traversal rejection, env filtering
- [ ] Commit: `feat(security): add approval, injection scanning, path safety, env filtering`


# SP-11: Trajectory & RL — Detailed Implementation Plan

> **For agentic workers:** Read Python files: trajectory_compressor.py, batch_runner.py, environments/*.py

**Goal:** Trajectory format, compression, batch runner for RL training data generation.

---

## Task 1: Trajectory System

**Files:** src/agent/trajectory/root.zig, format.zig, compressor.zig, batch_runner.zig

- [ ] format.zig: Trajectory data format
  ```zig
  pub const Trajectory = struct {
      session_id: []const u8,
      model: []const u8,
      turns: []Turn,
      metadata: TrajectoryMetadata,
  };
  pub const Turn = struct {
      role: Role,
      content: []const u8,
      tool_calls: ?[]ToolCall = null,
      tool_results: ?[]ToolResult = null,
      timestamp: i64,
  };
  pub const TrajectoryMetadata = struct {
      total_tokens: u32,
      total_turns: u32,
      tools_used: []const []const u8,
      duration_seconds: u32,
      success: bool,
  };
  ```
  - Serialize to JSON, deserialize from JSON
- [ ] compressor.zig: Trajectory compression
  - Remove consecutive assistant messages with no tool calls (merge into one)
  - Remove tool call arguments that are very long (truncate to N chars)
  - Remove system messages (they're reconstructible from config)
  - `compress(trajectory) Trajectory` — return compressed copy
- [ ] batch_runner.zig: Batch trajectory generation
  - Read task list from JSONL file (one task per line: {"prompt": "...", "expected": "..."})
  - For each task: create session, run AgentLoop, collect trajectory, save to output JSONL
  - Parallel execution: run N tasks concurrently using thread pool
  - `runBatch(tasks_path, output_path, concurrency) !BatchResult`
- [ ] Tests: trajectory serialization, compression, batch runner with mock agent
- [ ] Commit: `feat(agent): add trajectory format, compression, batch runner`


# SP-12: Integration & Entry Point — Detailed Implementation Plan

**Goal:** Wire everything together, CLI and gateway entry points, signal handling.

---

## Task 1: Final main.zig

**Files:** src/main.zig (complete rewrite)

- [ ] Parse CLI args: `hermes` (CLI mode), `hermes gateway` (gateway mode), `hermes setup`, `hermes model`, `hermes tools`, `hermes doctor`, `hermes update`, `hermes claw migrate`
- [ ] Common init:
  1. Load config from ~/.hermes/config.json
  2. Init framework AppContext (logger, observer, event bus)
  3. Open SQLite database
  4. Create LlmClient from provider registry
  5. Create TerminalBackend from config
  6. Create ToolRegistry (static built-in tools + MCP dynamic discovery)
  7. Create AgentLoop
  8. Init security module
- [ ] CLI mode: create TUI, run interactive loop
- [ ] Gateway mode: create GatewayRunner, start platform threads, run agent loop
- [ ] Signal handling: SIGINT/SIGTERM → set shutdown flag → graceful stop
- [ ] Logging: RequestTrace at entry, MethodTrace in agent loop, StepTrace on LLM/tool calls
- [ ] Tests: arg parsing, init sequence
- [ ] Commit: `feat: complete integration entry point`
