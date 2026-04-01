# hermes-zig Implementation Tasks

> **For agentic workers:** Each sub-project is independent and can be assigned to a separate agent session. Use superpowers:subagent-driven-development or superpowers:executing-plans.

**Total: 19 sub-projects, ~120 Zig source files**

---

## Phase 1: Foundation

### SP-1: Project Scaffold + Core Types
**Goal:** Create project with zig-framework dependency and shared type definitions.
**Files:** build.zig, build.zig.zon, src/main.zig, src/core/root.zig, src/core/types.zig
**Tasks:**
- [ ] Create build.zig.zon with framework dependency (vnext branch)
- [ ] Create build.zig with exe + test targets
- [ ] Define Platform enum (15 variants with displayName)
- [ ] Define Role enum, Message struct, ToolCall struct, TokenUsage struct
- [ ] Define SessionSource struct, HermesError error set
- [ ] Verify `zig build test` passes
- [ ] Commit

### SP-2: Configuration System
**Goal:** JSON config loading with env var expansion and SOUL.md persona.
**Files:** src/config/root.zig, types.zig, loader.zig, soul.zig
**Depends on:** SP-1
**Tasks:**
- [ ] Define Config struct (model, provider, api_keys, tools, gateway, cron, security, etc.)
- [ ] Implement JSON loader with std.json.parseFromSlice
- [ ] Implement env var expansion ($VAR and ${VAR} in string values)
- [ ] Implement SOUL.md file loading (read markdown file as system prompt)
- [ ] Create config.example.json
- [ ] Tests + commit

### SP-3: SQLite State Storage
**Goal:** SQLite database for sessions, messages, and full-text search.
**Files:** src/state/root.zig, sqlite.zig, database.zig, search.zig
**Depends on:** SP-1
**Tasks:**
- [ ] Create sqlite.zig with @cImport("sqlite3.h") bindings (open, exec, prepare, step, finalize, close)
- [ ] Create database.zig with schema creation (sessions, messages, memories tables)
- [ ] Implement session CRUD (create, get, list, delete)
- [ ] Implement message append/list for a session
- [ ] Create search.zig with FTS5 virtual table for message search
- [ ] Tests + commit

### SP-4: LLM Client Layer
**Goal:** LlmClient vtable interface with OpenAI-compatible and Anthropic implementations.
**Files:** src/llm/root.zig, interface.zig, openai_compat.zig, anthropic.zig, streaming.zig, provider_registry.zig
**Depends on:** SP-1, SP-2
**Tasks:**
- [ ] Define LlmClient vtable (complete, completeStream, deinit)
- [ ] Define CompletionRequest, CompletionResponse (with Arena), StreamCallback
- [ ] Implement OpenAICompatClient (POST /v1/chat/completions, SSE streaming, tool_calls parsing)
- [ ] Implement AnthropicClient (POST /v1/messages, SSE streaming with event types)
- [ ] Implement SSE parser (data: lines, [DONE] detection)
- [ ] Implement provider_registry (factory from config: provider name → LlmClient)
- [ ] Tests + commit

### SP-5: Tool System Core
**Goal:** ToolHandler vtable, ToolRegistry with static+dynamic, comptime validation.
**Files:** src/tools/root.zig, interface.zig, registry.zig, toolsets.zig
**Depends on:** SP-1
**Tasks:**
- [ ] Define ToolHandler vtable (execute, deinit) + ToolSchema + ToolContext
- [ ] Implement comptime validateToolImpl and makeToolHandler
- [ ] Implement ToolRegistry (static array + dynamic HashMap + RwLock)
- [ ] Implement dispatch (static first, then dynamic)
- [ ] Implement collectSchemas for LLM prompt building
- [ ] Define toolset presets (default, coding, research, etc.)
- [ ] Tests + commit

### SP-6: Terminal Backends
**Goal:** TerminalBackend tagged union with all 6 backends.
**Files:** src/terminal/root.zig, backend.zig, local.zig, docker.zig, ssh.zig, daytona.zig, singularity.zig, modal.zig
**Depends on:** SP-1
**Tasks:**
- [ ] Define ExecResult struct and TerminalBackend tagged union
- [ ] Implement LocalBackend (std.process.Child, stdout/stderr capture, timeout)
- [ ] Implement DockerBackend (docker exec via ProcessRunner)
- [ ] Implement SshBackend (ssh command via ProcessRunner)
- [ ] Implement DaytonaBackend (HTTP API calls via HttpClient)
- [ ] Implement SingularityBackend (singularity exec via ProcessRunner)
- [ ] Implement ModalBackend (HTTP API calls via HttpClient)
- [ ] Implement fromConfig factory
- [ ] Tests + commit

---

## Phase 2: Agent Core

### SP-7: Built-in Tools
**Goal:** Implement all 20+ built-in tools.
**Files:** src/tools/builtin/*.zig (20 files)
**Depends on:** SP-5, SP-6
**Tasks:**
- [ ] bash.zig — terminal command execution via TerminalBackend
- [ ] file_read.zig — read file with line range support
- [ ] file_write.zig — create/overwrite files
- [ ] file_edit.zig — patch-based editing (unified diff parsing)
- [ ] file_tools.zig — ls, find, grep, tree operations
- [ ] web_search.zig — Tavily/DuckDuckGo API integration
- [ ] browser.zig — browser automation (Playwright-style via process)
- [ ] code_execution.zig — Python/JS code execution in sandbox
- [ ] vision.zig — image analysis via LLM vision API
- [ ] todo.zig — todo list CRUD
- [ ] delegate.zig — subagent spawning
- [ ] send_message.zig — cross-platform message sending
- [ ] memory.zig — memory read/write/search
- [ ] clarify.zig — ask user for input
- [ ] image_gen.zig — image generation API
- [ ] transcription.zig — audio transcription (Whisper API)
- [ ] tts.zig — text-to-speech
- [ ] voice_mode.zig — voice conversation mode
- [ ] cronjob.zig — cron job management tool
- [ ] Each tool: SCHEMA constant + execute method + test

### SP-8: MCP Integration
**Goal:** MCP client and server for tool interop.
**Files:** src/tools/mcp/root.zig, client.zig, server.zig, discovery.zig
**Depends on:** SP-5
**Tasks:**
- [ ] Implement MCP client with stdio transport (spawn process, JSON-RPC over stdin/stdout)
- [ ] Implement MCP client with SSE transport (HTTP SSE stream)
- [ ] Implement dynamic tool discovery (tools/list → register in ToolRegistry)
- [ ] Implement MCP server (expose hermes tools via JSON-RPC)
- [ ] Tests + commit

### SP-9: Agent Loop
**Goal:** Core agent orchestration — prompt → LLM → tools → loop.
**Files:** src/agent/root.zig, loop.zig, prompt_builder.zig, context_compressor.zig, prompt_caching.zig, credential_pool.zig
**Depends on:** SP-4, SP-5, SP-3
**Tasks:**
- [ ] Implement AgentLoop.run (message → prompt → complete → tool dispatch → loop)
- [ ] Implement PromptBuilder (system prompt + SOUL.md + tool schemas + history + context files)
- [ ] Implement ContextCompressor (token counting, oldest-first removal, summary compression)
- [ ] Implement PromptCaching (Anthropic cache_control blocks)
- [ ] Implement CredentialPool (multi-key rotation with cooldown)
- [ ] Implement retry/fallback logic (rate limit → next key → fallback model)
- [ ] Tests + commit

### SP-10: CLI Interface
**Goal:** Full terminal UI with multiline editing and streaming.
**Files:** src/cli/root.zig, tui.zig, commands.zig, display.zig, history.zig, setup.zig, auth.zig, profiles.zig, doctor.zig
**Depends on:** SP-9
**Tasks:**
- [ ] Implement TUI (raw terminal mode, multiline input, ANSI rendering)
- [ ] Implement slash commands (/model, /new, /reset, /skills, /tools, /compress, /usage, /undo, /retry)
- [ ] Implement streaming display (delta-by-delta rendering, tool call display)
- [ ] Implement command history (up/down arrow, search)
- [ ] Implement setup wizard (interactive provider/model selection)
- [ ] Implement auth commands (API key add/remove/list)
- [ ] Implement profile management (create, switch, list)
- [ ] Implement doctor (diagnostic checks)
- [ ] Tests + commit

---

## Phase 3: Gateway

### SP-11: Gateway Core
**Goal:** Platform adapter interface, message queue, session routing.
**Files:** src/gateway/root.zig, platform.zig, session.zig, delivery.zig, pairing.zig, hooks.zig
**Depends on:** SP-9
**Tasks:**
- [ ] Define PlatformAdapter vtable (platform, connect, send, set_message_handler, deinit)
- [ ] Implement MessageQueue (Mutex + Condition + ArrayList)
- [ ] Implement session routing (platform + chat_id → session)
- [ ] Implement delivery (message chunking for platform limits, markdown formatting)
- [ ] Implement DM pairing (auth code verification)
- [ ] Implement hooks system (boot.md, custom hooks)
- [ ] Tests + commit

### SP-12: Gateway Platforms (14 platforms)
**Files:** src/gateway/platforms/*.zig (14 files + root.zig)
**Depends on:** SP-11
**Tasks:**
- [ ] telegram.zig — Bot API polling, send/edit/delete, media, groups, threads
- [ ] discord.zig — Bot gateway (WebSocket), slash commands, threads, reactions
- [ ] slack.zig — Events API (HTTP), Web API for sending
- [ ] whatsapp.zig — Cloud API (HTTP webhooks)
- [ ] signal.zig — signal-cli JSON-RPC
- [ ] email.zig — IMAP polling + SMTP sending
- [ ] matrix.zig — Matrix client-server API
- [ ] feishu.zig — Feishu/Lark Bot API
- [ ] dingtalk.zig — DingTalk Bot API
- [ ] wecom.zig — WeCom (企业微信) Bot API
- [ ] homeassistant.zig — HA conversation API
- [ ] sms.zig — Twilio SMS API
- [ ] mattermost.zig — Mattermost Bot API
- [ ] webhook.zig — Generic webhook (HTTP server)
- [ ] Each platform: connect, send, message handler, platform-specific features

---

## Phase 4: Intelligence

### SP-13: Skills System
**Files:** src/skills/root.zig, loader.zig, executor.zig, creator.zig, hub.zig, sync.zig, guard.zig
**Depends on:** SP-5, SP-9
**Tasks:**
- [ ] Implement SKILL.md parser (frontmatter + markdown body)
- [ ] Implement skill executor (inject skill content into prompt)
- [ ] Implement autonomous skill creation (agent creates SKILL.md after complex tasks)
- [ ] Implement Skills Hub client (HTTP API to agentskills.io)
- [ ] Implement skill sync (pull/push skills)
- [ ] Implement skill guard (safety checks before skill execution)
- [ ] Tests + commit

### SP-14: Memory System
**Files:** src/memory/root.zig, persistent.zig, user_model.zig, session_search.zig, nudge.zig
**Depends on:** SP-3, SP-9
**Tasks:**
- [ ] Implement persistent memory (MEMORY.md read/write/append)
- [ ] Implement user modeling (USER.md, Honcho integration via HTTP)
- [ ] Implement session search (FTS5 query across all sessions)
- [ ] Implement memory nudges (periodic prompts to persist important info)
- [ ] Tests + commit

### SP-15: Cron Scheduler
**Files:** src/cron/root.zig, scheduler.zig, jobs.zig
**Depends on:** SP-3, SP-9, SP-11
**Tasks:**
- [ ] Implement job storage (SQLite table: id, cron_expr, command, platform, chat_id)
- [ ] Implement cron expression parser (minute, hour, day, month, weekday)
- [ ] Implement scheduler loop (check jobs every minute, execute due jobs)
- [ ] Implement platform delivery (send job output to configured platform)
- [ ] Tests + commit

---

## Phase 5: Integration

### SP-16: ACP Adapter
**Files:** src/acp/root.zig, server.zig, session.zig, tools.zig
**Depends on:** SP-9, SP-5
**Tasks:**
- [ ] Implement ACP protocol server (HTTP + SSE)
- [ ] Implement ACP session management
- [ ] Implement tool exposure via ACP
- [ ] Implement auth (API key validation)
- [ ] Tests + commit

### SP-17: Security
**Files:** src/security/root.zig, approval.zig, injection.zig, path_safety.zig, env_filter.zig
**Depends on:** SP-5
**Tasks:**
- [ ] Implement command approval system (allowlist patterns, interactive approval)
- [ ] Implement injection scanning (detect prompt injection in tool outputs)
- [ ] Implement path traversal prevention (resolve + check against allowed dirs)
- [ ] Implement env variable filtering (blocklist sensitive vars)
- [ ] Tests + commit

### SP-18: Trajectory & RL
**Files:** src/trajectory/root.zig, format.zig, compressor.zig, batch_runner.zig
**Depends on:** SP-9
**Tasks:**
- [ ] Define trajectory format (JSON: messages + tool_calls + results)
- [ ] Implement trajectory compression (remove redundant turns, summarize)
- [ ] Implement batch runner (run agent on task list, collect trajectories)
- [ ] Tests + commit

### SP-19: Integration & Entry Point
**Files:** src/main.zig (final version)
**Depends on:** All
**Tasks:**
- [ ] Wire all modules in main.zig
- [ ] Implement CLI entry (hermes command)
- [ ] Implement gateway entry (hermes gateway)
- [ ] Implement signal handling (SIGINT/SIGTERM)
- [ ] Implement graceful shutdown
- [ ] Full integration test
- [ ] Commit

---

## Task Assignment Guide for AI Agents

Each sub-project should be assigned as a single task to an AI agent with:

1. **The spec section** from the design doc (copy the relevant SP-N section)
2. **The task list** from this file (copy the relevant SP-N tasks)
3. **Reference files** from hermes-agent Python source (tell agent which Python files to read for logic)
4. **Framework docs** (point to zig-framework-vnext docs for API reference)

### Reference mapping (Python → Zig)

| Sub-Project | Read these Python files |
|-------------|----------------------|
| SP-4 (LLM) | run_agent.py (lines 1-500), agent/auxiliary_client.py, hermes_cli/runtime_provider.py |
| SP-5 (Tools) | tools/registry.py, tools/__init__.py, model_tools.py, toolsets.py |
| SP-6 (Terminal) | tools/environments/*.py |
| SP-7 (Built-in) | tools/terminal_tool.py, tools/file_tools.py, tools/file_operations.py, tools/web_tools.py, tools/browser_tool.py, etc. |
| SP-8 (MCP) | tools/mcp_tool.py |
| SP-9 (Agent) | run_agent.py, agent/prompt_builder.py, agent/context_compressor.py |
| SP-10 (CLI) | cli.py, hermes_cli/main.py, hermes_cli/commands.py |
| SP-11 (Gateway) | gateway/run.py, gateway/session.py, gateway/delivery.py |
| SP-12 (Platforms) | gateway/platforms/*.py |
| SP-13 (Skills) | tools/skills_tool.py, tools/skills_hub.py, tools/skills_guard.py |
| SP-14 (Memory) | tools/memory_tool.py, tools/session_search_tool.py |
| SP-15 (Cron) | cron/scheduler.py, cron/jobs.py |
| SP-17 (Security) | tools/tirith_security.py, tools/approval.py |
