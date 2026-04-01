# hermes-zig Revised Implementation Tasks (v2)

> Based on design review corrections. 12 sub-projects (down from 19). Zig-native patterns enforced.

---

## SP-1: Core Foundation
**Module:** `src/core/`
**Goal:** Types, config, SQLite — the "vocabulary" layer that everything depends on.
**Files:** build.zig, build.zig.zon, src/main.zig, src/core/{root,types,config,config_loader,soul,sqlite,database,search}.zig

- [ ] Project scaffold: build.zig.zon with framework dep, build.zig with exe+test
- [ ] `types.zig`: Platform enum (15 variants + displayName), Role, Message, ToolCall, TokenUsage, SessionSource (with platform_metadata), HermesError
- [ ] `config.zig`: Full Config struct (model, provider, api_keys, tools, gateway, cron, security settings)
- [ ] `config_loader.zig`: JSON loading via std.json, env var expansion ($VAR/${VAR})
- [ ] `soul.zig`: SOUL.md file loading as system prompt string
- [ ] `sqlite.zig`: @cImport("sqlite3.h"), Database struct (open/exec/prepare/step/finalize/close)
- [ ] `database.zig`: Schema creation, session CRUD, message append/list
- [ ] `search.zig`: FTS5 virtual table for full-text message search
- [ ] Tests for each file, `zig build test` passes
- [ ] Commit

**Python reference:** hermes_constants.py, hermes_state.py, hermes_cli/config.py

---

## SP-2: LLM Client Layer
**Module:** `src/llm/`
**Goal:** LlmClient vtable with Arena responses, OpenAI-compat + Anthropic clients.
**Files:** src/llm/{root,interface,openai_compat,anthropic,streaming,provider_registry}.zig

- [ ] `interface.zig`: LlmClient vtable (complete, completeStream, deinit), CompletionRequest, CompletionResponse **with ArenaAllocator** (MANDATORY), StreamCallback (fn ptr + anyopaque ctx)
- [ ] `openai_compat.zig`: OpenAICompatClient — POST /v1/chat/completions, parse choices/tool_calls, Arena allocation for all response strings. Covers: OpenRouter, OpenAI, Nous Portal, z.ai, Kimi, MiniMax
- [ ] `anthropic.zig`: AnthropicClient — POST /v1/messages, handle event-stream (message_start, content_block_delta, message_delta, message_stop)
- [ ] `streaming.zig`: SSE line parser (data: prefix, [DONE] detection), stream accumulator
- [ ] `provider_registry.zig`: Factory from config (provider name → LlmClient instance)
- [ ] Tests: mock HTTP responses, verify Arena cleanup, verify streaming
- [ ] Commit

**Python reference:** run_agent.py (lines 1-500), agent/auxiliary_client.py, hermes_cli/runtime_provider.py

---

## SP-3: Tool System + Terminal Backends
**Module:** `src/tools/`
**Goal:** ToolHandler vtable with comptime validation, ToolRegistry (static+dynamic), TerminalBackend tagged union, MCP.
**Files:** src/tools/{root,interface,registry,toolsets}.zig, src/tools/terminal/{root,backend,local,docker,ssh,daytona,singularity,modal}.zig, src/tools/mcp/{root,client,server,discovery}.zig

- [ ] `interface.zig`: ToolHandler vtable, ToolSchema, ToolContext. **CRITICAL:** `validateToolImpl(comptime T)` and `makeToolHandler(comptime T, *T)` — comptime auto-vtable generation
- [ ] `registry.zig`: ToolRegistry with static ([]const ToolHandler, no lock) + dynamic (StringHashMap + RwLock). Dispatch: static first (security: built-ins can't be shadowed)
- [ ] `toolsets.zig`: Tool groupings (default, coding, research, creative, all)
- [ ] `terminal/backend.zig`: TerminalBackend tagged union (local, docker, ssh, daytona, singularity, modal) with exhaustive switch. `fromConfig` factory
- [ ] `terminal/local.zig`: std.process.Child, stdout/stderr capture, timeout
- [ ] `terminal/docker.zig`: docker exec via ProcessRunner
- [ ] `terminal/ssh.zig`: ssh command via ProcessRunner
- [ ] `terminal/daytona.zig`: HTTP API via HttpClient
- [ ] `terminal/singularity.zig`: singularity exec via ProcessRunner
- [ ] `terminal/modal.zig`: HTTP API via HttpClient
- [ ] `mcp/client.zig`: MCP client (stdio transport: spawn process, JSON-RPC over stdin/stdout)
- [ ] `mcp/discovery.zig`: tools/list → registerDynamic into ToolRegistry
- [ ] `mcp/server.zig`: Expose hermes tools via JSON-RPC
- [ ] Tests for each, especially comptime validation (verify compile error on bad tool struct)
- [ ] Commit

**Python reference:** tools/registry.py, tools/__init__.py, toolsets.py, tools/environments/*.py, tools/mcp_tool.py

---

## SP-4: Built-in Tools
**Module:** `src/tools/builtin/`
**Goal:** 20+ tools, ALL using `makeToolHandler` comptime pattern.
**Files:** src/tools/builtin/{root,bash,file_read,file_write,file_edit,file_tools,web_search,browser,code_execution,vision,todo,delegate,send_message,memory_tool,clarify,image_gen,transcription,tts,voice_mode,cronjob}.zig

- [ ] Each tool: `pub const SCHEMA: ToolSchema` + `pub fn execute(self, args, ctx) ![]const u8`
- [ ] `bash.zig`: Execute via TerminalBackend, capture output
- [ ] `file_read.zig`: Read file with optional line range
- [ ] `file_write.zig`: Create/overwrite files with directory creation
- [ ] `file_edit.zig`: Unified diff patch parsing and application
- [ ] `file_tools.zig`: ls, find, grep, tree (via FileSystem effect)
- [ ] `web_search.zig`: Tavily/DuckDuckGo API via HttpClient
- [ ] `browser.zig`: Browser automation (spawn headless browser process)
- [ ] `code_execution.zig`: Python/JS execution in sandbox (via TerminalBackend)
- [ ] `vision.zig`: Image analysis via LLM vision API (base64 encode + send)
- [ ] `todo.zig`: Todo list CRUD (SQLite backed)
- [ ] `delegate.zig`: Spawn subagent (new AgentLoop instance in thread)
- [ ] `send_message.zig`: Cross-platform send via PlatformAdapter
- [ ] `memory_tool.zig`: Memory read/write/search
- [ ] `clarify.zig`: Ask user for input (callback to CLI/gateway)
- [ ] `image_gen.zig`: Image generation API call
- [ ] `transcription.zig`: Whisper API for audio transcription
- [ ] `tts.zig`: Text-to-speech API
- [ ] `voice_mode.zig`: Voice conversation mode (transcribe → LLM → TTS)
- [ ] `cronjob.zig`: Cron job CRUD
- [ ] Tests for each tool
- [ ] Commit

**Python reference:** tools/terminal_tool.py, tools/file_tools.py, tools/file_operations.py, tools/web_tools.py, tools/browser_tool.py, tools/code_execution_tool.py, tools/vision_tools.py, tools/todo_tool.py, tools/delegate_tool.py, tools/send_message_tool.py, tools/memory_tool.py, tools/clarify_tool.py, tools/image_generation_tool.py, tools/transcription_tools.py, tools/tts_tool.py, tools/voice_mode.py, tools/cronjob_tools.py

---

## SP-5: Agent Loop
**Module:** `src/agent/`
**Goal:** Core orchestration — prompt → LLM → tools → loop.
**Files:** src/agent/{root,loop,prompt_builder,context_compressor,prompt_caching,credential_pool}.zig

- [ ] `loop.zig`: AgentLoop.run — build prompt → LlmClient.complete → if tool_calls: dispatch tools, append results, loop → return assistant message. Max iterations guard.
- [ ] `prompt_builder.zig`: Assemble system prompt (SOUL.md + tool schemas + context files + memory) + message history. Token counting for context window management.
- [ ] `context_compressor.zig`: When context exceeds limit — oldest-first removal, or LLM-based summarization of old turns
- [ ] `prompt_caching.zig`: Anthropic cache_control block injection for stable prompt prefixes
- [ ] `credential_pool.zig`: Multi-API-key rotation with per-key cooldown on rate limit
- [ ] Retry/fallback: rate limit → next key → fallback model → error
- [ ] Tests with mock LlmClient
- [ ] Commit

**Python reference:** run_agent.py, agent/prompt_builder.py, agent/context_compressor.py, agent/prompt_caching.py, agent/credential_pool.py

---

## SP-6: CLI Interface
**Module:** `src/interface/cli/`
**Goal:** Full terminal UI.
**Files:** src/interface/cli/{root,tui,commands,display,history,setup,auth,profiles,doctor}.zig

- [ ] `tui.zig`: Raw terminal mode, multiline input (Ctrl+Enter for newline), ANSI rendering, Ctrl+C interrupt
- [ ] `commands.zig`: Slash commands (/model, /new, /reset, /skills, /tools, /compress, /usage, /undo, /retry, /personality, /insights)
- [ ] `display.zig`: Streaming delta display, tool call rendering (name + args + result), spinner
- [ ] `history.zig`: Command history with up/down arrow, persistent across sessions
- [ ] `setup.zig`: Interactive setup wizard (provider selection, API key input, model selection)
- [ ] `auth.zig`: API key management (add, remove, list, test)
- [ ] `profiles.zig`: Profile CRUD (create, switch, list, delete)
- [ ] `doctor.zig`: Diagnostic checks (API connectivity, tool availability, config validation)
- [ ] Commit

**Python reference:** cli.py, hermes_cli/main.py, hermes_cli/commands.py, hermes_cli/setup.py

---

## SP-7: Gateway Core + All Platforms
**Module:** `src/interface/gateway/`
**Goal:** PlatformAdapter vtable, MessageQueue, 14 platforms each in own thread.
**Files:** src/interface/gateway/{root,platform,session,delivery,pairing,hooks}.zig, src/interface/gateway/platforms/{root + 14 platform files}.zig

- [ ] `platform.zig`: PlatformAdapter vtable, IncomingMessage, SendResult, MessageHandler, **MessageQueue (Mutex + Condition)**
- [ ] `session.zig`: Session routing (platform + chat_id → session), session lifecycle
- [ ] `delivery.zig`: Message chunking (platform char limits), markdown→platform formatting
- [ ] `pairing.zig`: DM pairing with auth codes
- [ ] `hooks.zig`: Gateway hooks (boot.md, custom pre/post hooks)
- [ ] Each platform adapter: connect (in own std.Thread), send, message handler, platform-specific features
- [ ] telegram.zig: Bot API long polling, media handling, groups/threads
- [ ] discord.zig: Gateway WebSocket, slash commands, threads, reactions
- [ ] slack.zig: Events API HTTP, Web API sending
- [ ] whatsapp.zig: Cloud API webhooks
- [ ] signal.zig: signal-cli JSON-RPC
- [ ] email.zig: IMAP polling + SMTP sending
- [ ] matrix.zig: Client-server API
- [ ] feishu.zig: Feishu Bot API
- [ ] dingtalk.zig: DingTalk Bot API
- [ ] wecom.zig: WeCom Bot API
- [ ] homeassistant.zig: HA conversation API
- [ ] sms.zig: Twilio API
- [ ] mattermost.zig: Mattermost Bot API
- [ ] webhook.zig: Generic HTTP webhook server
- [ ] Commit

**Python reference:** gateway/run.py, gateway/session.py, gateway/delivery.py, gateway/platforms/*.py

---

## SP-8: ACP Adapter
**Module:** `src/interface/acp/`
**Files:** src/interface/acp/{root,server,session,tools}.zig

- [ ] ACP protocol server (HTTP + SSE)
- [ ] Session management
- [ ] Tool exposure via ACP protocol
- [ ] Auth (API key)
- [ ] Commit

**Python reference:** acp_adapter/*.py

---

## SP-9: Skills + Memory + Cron
**Module:** `src/intelligence/`
**Files:** src/intelligence/{root,skills_loader,skills_executor,skills_creator,skills_hub,skills_sync,skills_guard,memory_persistent,user_model,session_search,memory_nudge,cron_scheduler,cron_jobs}.zig

- [ ] `skills_loader.zig`: Parse SKILL.md (YAML frontmatter + markdown body)
- [ ] `skills_executor.zig`: Inject skill content into agent prompt
- [ ] `skills_creator.zig`: Agent creates SKILL.md after complex tasks
- [ ] `skills_hub.zig`: HTTP client to agentskills.io
- [ ] `skills_sync.zig`: Pull/push skills
- [ ] `skills_guard.zig`: Safety validation before skill execution
- [ ] `memory_persistent.zig`: MEMORY.md read/write/append
- [ ] `user_model.zig`: USER.md + Honcho HTTP integration
- [ ] `session_search.zig`: FTS5 search across sessions
- [ ] `memory_nudge.zig`: Periodic prompts to persist important info
- [ ] `cron_scheduler.zig`: Cron expression parser + scheduler loop
- [ ] `cron_jobs.zig`: Job storage (SQLite) + execution + platform delivery
- [ ] Commit

**Python reference:** tools/skills_tool.py, tools/skills_hub.py, tools/skills_guard.py, tools/memory_tool.py, tools/session_search_tool.py, cron/*.py

---

## SP-10: Security
**Module:** `src/security/`
**Files:** src/security/{root,approval,injection,path_safety,env_filter}.zig

- [ ] `approval.zig`: Command allowlist patterns, interactive approval prompt
- [ ] `injection.zig`: Prompt injection detection in tool outputs
- [ ] `path_safety.zig`: Path traversal prevention (resolve + check)
- [ ] `env_filter.zig`: Blocklist sensitive env vars from tool access
- [ ] Commit

**Python reference:** tools/tirith_security.py, tools/approval.py, tools/env_passthrough.py

---

## SP-11: Trajectory & RL
**Module:** `src/agent/trajectory/`
**Files:** src/agent/trajectory/{root,format,compressor,batch_runner}.zig

- [ ] Trajectory JSON format (messages + tool_calls + results)
- [ ] Trajectory compression (remove redundant, summarize)
- [ ] Batch runner (task list → parallel agent runs → collect trajectories)
- [ ] Commit

**Python reference:** trajectory_compressor.py, batch_runner.py, environments/*.py

---

## SP-12: Integration & Entry Point
**Files:** src/main.zig (final)

- [ ] Wire all modules: core → llm → tools → agent → interface → intelligence → security
- [ ] CLI entry: `hermes` command → TUI
- [ ] Gateway entry: `hermes gateway` → spawn platform threads + agent loop
- [ ] Signal handling (SIGINT/SIGTERM → graceful shutdown)
- [ ] Logging: RequestTrace at CLI/gateway entry, MethodTrace in agent loop, StepTrace on LLM/tool calls
- [ ] Full integration test
- [ ] Commit

---

## AI Agent Assignment Guide

For each SP, provide the agent with:

1. **This task list** (the SP-N section above)
2. **The design spec** (relevant section from design doc)
3. **The design review** (corrections doc — especially comptime tools, Arena, MessageQueue)
4. **Python reference files** (listed under each SP)
5. **Framework API reference** (/tmp/zig-framework-vnext/src/ — especially effects, tooling, agentkit)
6. **AGENTS.md** (coding rules)

The agent should read the Python files to understand WHAT the code does, then implement it in Zig following the patterns in the design docs — NOT by translating Python line-by-line.
