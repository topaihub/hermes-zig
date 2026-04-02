# Phase 1-5 Complete Implementation Plan

> All 76 tasks with requirements, design, and steps.
> Read Python source files listed under each task for intent.

---

## Phase 1: Make It Actually Work (15 tasks)

### P1.1: agent/redact.zig — Sensitive data redaction
**Python:** agent/redact.py (176 lines)
**Intent:** Mask API keys, tokens, passwords in log output.
**Design:** `maskToken(token) []const u8` — show first 4 + last 4 chars, mask middle. `redactText(text) []const u8` — scan for patterns (sk-..., AIza..., Bearer ...) and mask.
**Tasks:**
- [ ] Create src/agent/redact.zig with maskToken and redactText
- [ ] Pattern list: sk-, AIza, Bearer, ghp_, token=, password=, secret=
- [ ] Test: maskToken("sk-1234567890abcdef") → "sk-1...cdef"
- [ ] Update agent/root.zig exports

### P1.2: agent/model_metadata.zig — Model capabilities database
**Python:** agent/model_metadata.py (931 lines)
**Intent:** Know each model's context window, pricing, capabilities (vision, tools, streaming).
**Design:** Comptime struct array of ModelInfo. Lookup by model name.
```zig
pub const ModelInfo = struct { name: []const u8, context_window: u32, supports_vision: bool, supports_tools: bool, input_price_per_mtok: f64, output_price_per_mtok: f64 };
pub fn lookup(model: []const u8) ?ModelInfo
```
**Tasks:**
- [ ] Create src/agent/model_metadata.zig with ModelInfo struct
- [ ] Populate ~20 common models (gpt-4o, claude-sonnet-4, gemini-2.5-pro, etc.)
- [ ] lookup function: linear scan (small list)
- [ ] Test: lookup("gpt-4o") returns correct context window

### P1.3: agent/usage_pricing.zig — Token cost calculation
**Python:** agent/usage_pricing.py (656 lines)
**Intent:** Calculate cost of API calls based on token counts and model pricing.
**Design:** `calculateCost(model, input_tokens, output_tokens) CostResult`. Uses model_metadata for pricing.
**Tasks:**
- [ ] Create src/agent/usage_pricing.zig
- [ ] CostResult: input_cost, output_cost, total_cost (f64)
- [ ] Test: known model + known tokens = expected cost

### P1.4: core/colors.zig — ANSI color constants
**Python:** hermes_cli/colors.py (24 lines)
**Intent:** Shared color constants for CLI output.
**Design:** Already have tui/ansi.zig in interface/cli. Move to core or reuse.
**Tasks:**
- [ ] Verify src/interface/cli/tui.zig or src/tui/ansi.zig has all needed colors
- [ ] If missing, add: dim, underline, strikethrough, bg colors
- [ ] Export from a shared location

### P1.5: core/default_soul.zig — Default persona
**Python:** hermes_cli/default_soul.py (17 lines)
**Intent:** Default SOUL.md content when user hasn't created one.
**Design:** Const string embedded in code.
**Tasks:**
- [ ] Add DEFAULT_SOUL constant to src/core/soul.zig
- [ ] Use in loadSoul when file not found (return default instead of null)
- [ ] Test: loadSoul with no file returns default content

### P1.6: core/env_loader.zig — .env file loading
**Python:** hermes_cli/env_loader.py (40 lines)
**Intent:** Load KEY=VALUE pairs from .env file into environment.
**Design:** Read file line by line, parse KEY=VALUE, call std.process.setenv or store in HashMap.
**Tasks:**
- [ ] Create src/core/env_loader.zig with loadEnvFile(path, allocator) !EnvMap
- [ ] Parse: skip comments (#), trim whitespace, handle quotes
- [ ] Test: parse "API_KEY=sk-123\n# comment\nMODEL=gpt-4o"

### P1.7: agent/callbacks.zig — Streaming display callbacks
**Python:** hermes_cli/callbacks.py (283 lines)
**Intent:** Callbacks that receive LLM streaming deltas and render to terminal.
**Design:** StreamCallback already exists in llm/interface.zig. This creates a CLI-specific callback that writes deltas to stdout with formatting.
**Tasks:**
- [ ] Create src/agent/callbacks.zig with CliStreamCallback
- [ ] on_delta: write content to stdout, handle newlines
- [ ] on_tool_call: display "⚡ Calling {tool_name}..."
- [ ] on_done: write final newline
- [ ] Wire into main.zig chat loop

### P1.8: llm/runtime_provider.zig — Provider resolution from config
**Python:** hermes_cli/runtime_provider.py (696 lines)
**Intent:** At startup, resolve which LLM provider to use based on config + env vars + API key availability.
**Design:** Read config.provider + config.api_key + env vars (OPENROUTER_API_KEY, OPENAI_API_KEY, ANTHROPIC_API_KEY). Create appropriate LlmClient.
**Tasks:**
- [ ] Create src/llm/runtime_provider.zig
- [ ] resolveProvider(config, allocator) !LlmClient
- [ ] Check env vars: OPENROUTER_API_KEY, OPENAI_API_KEY, ANTHROPIC_API_KEY
- [ ] Fallback chain: config.api_key → env var → error
- [ ] Test: with mock env

### P1.9: Wire real LLM calls in main.zig
**Intent:** Connect the agent loop to a real LLM API.
**Tasks:**
- [ ] In main.zig: call runtime_provider.resolveProvider to get LlmClient
- [ ] Pass LlmClient to AgentLoop
- [ ] On user message: call agent.run() with real LLM
- [ ] Display streaming response via CliStreamCallback
- [ ] Handle errors (invalid key, rate limit) gracefully

### P1.10: Session persistence (complete)
**Tasks:** (from session-persistence.md)
- [ ] Extend database.zig with appendToolMessage
- [ ] AgentLoop: persist user messages, assistant messages, tool calls, tool results
- [ ] main.zig: open hermes.db, create session, pass to AgentLoop
- [ ] /new command: new session_id

### P1.11-P1.15: Trivial but needed
- [ ] P1.11: hermes_constants equivalent — move constants to core/constants.zig (HERMES_HOME, provider URLs)
- [ ] P1.12: hermes_time equivalent — time formatting helpers in core/time.zig
- [ ] P1.13: utils equivalent — misc helpers in core/utils.zig
- [ ] P1.14: model_tools equivalent — tool schema collection in tools/model_tools.zig
- [ ] P1.15: Integration test — start hermes-zig, configure with real API key, send message, get response

---

## Phase 2: Core Tools Working (12 tasks)

### P2.1: web_search — Real DuckDuckGo API
**Python:** tools/web_tools.py (1841 lines)
**Tasks:**
- [ ] GET https://api.duckduckgo.com/?q={query}&format=json via HttpClient
- [ ] Parse JSON response: AbstractText, RelatedTopics[].Text, RelatedTopics[].FirstURL
- [ ] Format as readable results
- [ ] Test with mock HTTP

### P2.2: session_search — Wire to SQLite FTS5
**Tasks:**
- [ ] Add db field to SessionSearchTool
- [ ] Call core.search.searchMessages
- [ ] Format results with session metadata
- [ ] Test with in-memory db

### P2.3: checkpoint — Git-based snapshots
**Tasks:**
- [ ] Shell out to git init/add/commit/log/checkout/diff
- [ ] Shadow repo at .hermes-checkpoints/
- [ ] Test: create + list

### P2.4: process — Background process management
**Tasks:**
- [ ] Implement ProcessPool.spawn with std.process.Child
- [ ] Implement poll (read available stdout)
- [ ] Implement kill
- [ ] Wire ProcessTool to ProcessPool

### P2.5: vision — Image analysis via LLM
**Tasks:**
- [ ] Read image, base64 encode
- [ ] Build vision message format
- [ ] Call LlmClient.complete
- [ ] Return description

### P2.6: delegate — Subagent spawning
**Tasks:**
- [ ] Create AgentLoop in std.Thread
- [ ] Pass task as user message
- [ ] Wait for completion
- [ ] Return result

### P2.7: send_message — Cross-platform send
**Tasks:**
- [ ] Lookup platform adapter by name
- [ ] Call adapter.send()
- [ ] Return result

### P2.8: image_gen — DALL-E API
**Tasks:**
- [ ] POST to /v1/images/generations
- [ ] Save image to file
- [ ] Return path

### P2.9: transcription — Whisper API
**Tasks:**
- [ ] POST multipart to /v1/audio/transcriptions
- [ ] Return text

### P2.10: tts — Text-to-speech API
**Tasks:**
- [ ] POST to /v1/audio/speech
- [ ] Save audio file
- [ ] Return path

### P2.11: homeassistant — HA REST API
**Tasks:**
- [ ] Implement 4 HTTP calls (list/state/call/services)
- [ ] Parse JSON responses

### P2.12: honcho — Honcho API
**Tasks:**
- [ ] Implement 4 HTTP calls (context/profile/search/conclude)
- [ ] Parse responses

---

## Phase 3: Full CLI Experience (14 tasks)

### P3.1: cli/config_manager.zig — Config file management
**Python:** hermes_cli/config.py (2207 lines)
**Tasks:**
- [ ] Load/save config.json
- [ ] Load .env file
- [ ] Config validation
- [ ] Managed mode detection
- [ ] CLI: hermes config show/edit/set

### P3.2: cli/models_manager.zig — Model listing and validation
**Python:** hermes_cli/models.py (1242 lines)
**Tasks:**
- [ ] List models from provider API (OpenRouter: GET /models)
- [ ] Validate model name exists
- [ ] Display model info (context window, pricing)
- [ ] CLI: hermes model list/set

### P3.3: cli/gateway_cmd.zig — Gateway CLI commands
**Python:** hermes_cli/gateway.py (2061 lines)
**Tasks:**
- [ ] hermes gateway setup — configure platforms
- [ ] hermes gateway start — start gateway process
- [ ] hermes gateway stop — stop gateway
- [ ] hermes gateway status — show platform status

### P3.4: cli/auth_cmd.zig — Auth CLI commands
**Python:** hermes_cli/auth_commands.py (470 lines)
**Tasks:**
- [ ] hermes auth add {provider} — prompt for API key
- [ ] hermes auth remove {provider}
- [ ] hermes auth list — show masked keys
- [ ] hermes auth test — verify key works

### P3.5: cli/tools_config.zig — Tool configuration
**Python:** hermes_cli/tools_config.py (1641 lines)
**Tasks:**
- [ ] hermes tools list — show all tools with enabled/disabled
- [ ] hermes tools enable/disable {tool}
- [ ] Toolset management
- [ ] Save to config

### P3.6: cli/mcp_config.zig — MCP configuration
**Python:** hermes_cli/mcp_config.py (645 lines)
**Tasks:**
- [ ] hermes mcp add {server}
- [ ] hermes mcp remove {server}
- [ ] hermes mcp list
- [ ] Save to config

### P3.7: agent/insights.zig — Usage analytics
**Python:** agent/insights.py (799 lines)
**Tasks:**
- [ ] Track per-session: tokens, cost, tool calls, duration
- [ ] /insights command: show stats for last N days
- [ ] Aggregate across sessions from SQLite

### P3.8: agent/usage_pricing.zig — Cost tracking (extend P1.3)
**Tasks:**
- [ ] Track cumulative cost per session
- [ ] /usage command shows current session cost
- [ ] Store in session metadata

### P3.9-P3.14: Remaining CLI features
- [ ] P3.9: cli/cron_cmd.zig — hermes cron add/list/remove
- [ ] P3.10: cli/skills_config.zig — hermes skills install/remove/list
- [ ] P3.11: cli/model_switch.zig — runtime model switching (update LlmClient)
- [ ] P3.12: cli/clipboard.zig — paste image from clipboard
- [ ] P3.13: cli/colors.zig — shared ANSI color helpers
- [ ] P3.14: cli/main_entry.zig — full argument parsing (hermes, hermes gateway, hermes setup, etc.)

---

## Phase 4: Advanced Features (15 tasks)

### P4.1: agent/anthropic_adapter.zig
**Python:** agent/anthropic_adapter.py (1321 lines)
**Tasks:**
- [ ] Anthropic-specific message formatting (system as top-level param)
- [ ] tool_use content blocks
- [ ] Cache control injection
- [ ] Adaptive thinking support
- [ ] OAuth token detection

### P4.2: agent/auxiliary_client.zig
**Python:** agent/auxiliary_client.py (1926 lines)
**Tasks:**
- [ ] Secondary LLM client for cheap/fast tasks
- [ ] Title generation
- [ ] Summarization
- [ ] Vision analysis
- [ ] Uses separate API key/model from main client

### P4.3: agent/context_references.zig
**Python:** agent/context_references.py (492 lines)
**Tasks:**
- [ ] Parse @file, @folder, @git references in user messages
- [ ] Expand: read file content, list folder, git diff
- [ ] Inject expanded content into message
- [ ] Path safety: resolve within allowed root

### P4.4: agent/skill_commands.zig + skill_utils.zig
**Python:** agent/skill_commands.py (297) + skill_utils.py (270)
**Tasks:**
- [ ] /skills install {name} — download from hub
- [ ] /skills create — create new skill from conversation
- [ ] Skill frontmatter parsing utilities
- [ ] Skill condition matching (platform, context)

### P4.5: agent/smart_model_routing.zig
**Python:** agent/smart_model_routing.py (198 lines)
**Tasks:**
- [ ] Analyze task complexity (simple question vs code generation vs research)
- [ ] Route to appropriate model (cheap for simple, powerful for complex)
- [ ] Configurable routing rules

### P4.6: agent/title_generator.zig
**Python:** agent/title_generator.py (125 lines)
**Tasks:**
- [ ] After first exchange, generate conversation title via LLM
- [ ] Use cheap model (auxiliary_client)
- [ ] Store title in session metadata

### P4.7-P4.10: External API tools (extend stubs)
- [ ] P4.7: browser_actions — implement via playwright CLI if available
- [ ] P4.8: mixture_of_agents — sequential multi-model calls
- [ ] P4.9: tts with NeuTTS option
- [ ] P4.10: transcription with local Whisper option

### P4.11-P4.15: Gateway real implementations
- [ ] P4.11: telegram — real Bot API polling + send
- [ ] P4.12: discord — real WebSocket gateway + REST send
- [ ] P4.13: slack — real Events API + Web API
- [ ] P4.14: whatsapp — real Cloud API webhooks
- [ ] P4.15: webhook — real HTTP server for generic webhooks

---

## Phase 5: Ecosystem (20 tasks)

### P5.1-P5.7: ACP adapter (7 files)
- [ ] P5.1: acp/auth.zig — API key validation
- [ ] P5.2: acp/events.zig — SSE event streaming
- [ ] P5.3: acp/permissions.zig — tool permission management
- [ ] P5.4: acp/session.zig — ACP session lifecycle
- [ ] P5.5: acp/tools.zig — expose tools via ACP protocol
- [ ] P5.6: acp/entry.zig — ACP entry point
- [ ] P5.7: acp/server.zig — extend existing stub with real HTTP handling

### P5.8-P5.10: Honcho integration
- [ ] P5.8: intelligence/honcho_client.zig — full HTTP client
- [ ] P5.9: intelligence/honcho_session.zig — session-level user modeling
- [ ] P5.10: intelligence/honcho_cli.zig — CLI commands for Honcho

### P5.11-P5.13: Environments/RL
- [ ] P5.11: environments/base_env.zig — base environment interface
- [ ] P5.12: environments/agent_loop_env.zig — agent loop as environment
- [ ] P5.13: environments/web_research_env.zig — web research environment

### P5.14: Bundled skills
- [ ] Copy 74 SKILL.md files from Python project to skills/ directory
- [ ] Organize by category (software-development, research, creative, etc.)

### P5.15-P5.20: Low priority features
- [ ] P5.15: cli/claw.zig — OpenClaw migration
- [ ] P5.16: cli/skin_engine.zig — full theme system
- [ ] P5.17: cli/plugins_cmd.zig — plugin management commands
- [ ] P5.18: cli/uninstall.zig — uninstall command
- [ ] P5.19: mcp_serve.zig — expose hermes as MCP server
- [ ] P5.20: rl_cli.zig — RL training CLI commands

---

## Execution Guide for AI Agents

For each task:
1. Read the Python source file listed
2. Understand the INTENT (what problem it solves)
3. Design in Zig (use framework effects, comptime, tagged unions where appropriate)
4. Implement with tests
5. Wire into main.zig or appropriate module
6. `zig build test` must pass
7. Commit with descriptive message
