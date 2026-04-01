# Completion Phase — Requirements, Design & Tasks

> This document covers all 51 missing items identified in gap-analysis-v3.md.
> Each item has: Requirement (what), Design (how in Zig), Task (steps).

---

## Group A: Missing Tools (19 user-facing)

### A1. checkpoint_manager.zig
**Requirement:** Transparent filesystem snapshots via shadow git repos. Auto-snapshot before file mutations, rollback to any checkpoint.
**Design:** Use framework ProcessRunner to shell out to `git init/add/commit/checkout`. Store shadow repo in `.hermes-checkpoints/` inside working dir.
**Tasks:**
- [ ] Define CheckpointManagerTool with SCHEMA: action(create/list/rollback/diff), checkpoint_id(?string)
- [ ] execute: create → `git add -A && git commit`, list → `git log --oneline`, rollback → `git checkout`, diff → `git diff`
- [ ] Test: create checkpoint, verify git log shows it

### A2. session_search.zig
**Requirement:** Search past sessions via FTS5, summarize matches using cheap LLM model.
**Design:** Wrap core/search.zig FTS5 search. Format results with session metadata. LLM summarization is optional (skip for v1, return raw snippets).
**Tasks:**
- [ ] Define SessionSearchTool with SCHEMA: query(string), max_results(?int)
- [ ] execute: call core search.searchMessages, format results as text
- [ ] Test: schema name check

### A3. skills_tool.zig
**Requirement:** List and view skill documents. Skills are dirs with SKILL.md.
**Design:** Wrap intelligence/skills_loader. List skills from all skill dirs, view specific skill content.
**Tasks:**
- [ ] Define SkillsTool with SCHEMA: action(list/view), skill_name(?string)
- [ ] execute: list → scan dirs, view → read SKILL.md content
- [ ] Test: schema name check

### A4. skill_manager.zig
**Requirement:** Create, update, delete skills. Write SKILL.md files.
**Design:** File I/O to ~/.hermes/skills/{name}/SKILL.md.
**Tasks:**
- [ ] Define SkillManagerTool with SCHEMA: action(create/update/delete), name(string), content(?string)
- [ ] execute: create → mkdir + write SKILL.md, update → overwrite, delete → rmdir
- [ ] Test: schema name check

### A5. skills_hub.zig
**Requirement:** Browse and install skills from agentskills.io marketplace.
**Design:** HTTP client to agentskills.io API. List → GET /skills, install → download + extract.
**Tasks:**
- [ ] Define SkillsHubTool with SCHEMA: action(search/install/uninstall), query(?string), skill_id(?string)
- [ ] execute: search → HTTP GET, install → download + write files, uninstall → delete dir
- [ ] Test: schema name check

### A6. skills_sync.zig
**Requirement:** Sync local skills with remote (push/pull).
**Design:** HTTP client to agentskills.io. Compare local vs remote versions.
**Tasks:**
- [ ] Define SkillsSyncTool with SCHEMA: action(push/pull/status)
- [ ] execute: stub returning sync status
- [ ] Test: schema name check

### A7. honcho_tools.zig
**Requirement:** Retrieve user context from Honcho API for personalization.
**Design:** HTTP client to Honcho server. GET user profile, GET conversation context.
**Tasks:**
- [ ] Define HonchoTool with SCHEMA: action(get_context/get_profile), user_id(?string)
- [ ] execute: HTTP GET to Honcho API, return JSON response
- [ ] Test: schema name check

### A8. homeassistant_tool.zig
**Requirement:** Control smart home devices via Home Assistant REST API.
**Design:** HTTP client to HA instance. Call services, get states.
**Tasks:**
- [ ] Define HomeAssistantTool with SCHEMA: action(call_service/get_states/get_state), entity_id(?string), service(?string), data(?string)
- [ ] execute: HTTP POST/GET to HA API with Bearer token
- [ ] Test: schema name check

### A9. process_registry.zig
**Requirement:** Track background processes spawned by terminal tool. Rolling output buffer, status polling.
**Design:** In-memory registry (HashMap of process ID → ProcessInfo). ProcessInfo has stdout buffer (ring buffer), status, pid.
**Tasks:**
- [ ] Define ProcessRegistryTool with SCHEMA: action(list/status/logs/kill), process_id(?string)
- [ ] ProcessInfo struct: id, command, status(running/exited), stdout_buffer, exit_code
- [ ] execute: list → return all processes, status → return one, logs → return buffer, kill → send signal
- [ ] Test: schema name check

### A10. mixture_of_agents.zig
**Requirement:** Multi-model orchestration — send same prompt to multiple models, aggregate responses.
**Design:** Takes list of models, calls LLM for each (sequentially for v1), combines responses.
**Tasks:**
- [ ] Define MixtureOfAgentsTool with SCHEMA: prompt(string), models(string — comma-separated)
- [ ] execute: stub returning "MoA requires multiple LLM clients"
- [ ] Test: schema name check

### A11. tirith_security.zig
**Requirement:** Deep pre-execution security scanning. Check commands for dangerous patterns beyond basic approval.
**Design:** Pattern matching against dangerous command patterns (rm -rf /, chmod 777, curl|bash, etc.).
**Tasks:**
- [ ] Define TirithSecurityTool with SCHEMA: command(string)
- [ ] execute: scan command against pattern list, return risk assessment
- [ ] Test: detect "rm -rf /"

### A12. url_safety.zig
**Requirement:** Block requests to private/internal network addresses (SSRF prevention).
**Design:** Parse URL, resolve hostname, check if IP is in private ranges (10.x, 172.16-31.x, 192.168.x, 127.x, ::1).
**Tasks:**
- [ ] Define UrlSafetyTool with SCHEMA: url(string)
- [ ] execute: parse URL, check against private IP ranges, return safe/unsafe
- [ ] Test: block 127.0.0.1, allow google.com

### A13. website_policy.zig
**Requirement:** Website access rules — allowlist/blocklist for URL-capable tools.
**Design:** Pattern matching against configured URL patterns.
**Tasks:**
- [ ] Define WebsitePolicyTool with SCHEMA: url(string), action(check)
- [ ] execute: check URL against policy patterns
- [ ] Test: schema name check

### A14. credential_files.zig
**Requirement:** Manage credential files for remote terminal backends (SSH keys, Docker certs).
**Design:** File I/O to ~/.hermes/credentials/ directory.
**Tasks:**
- [ ] Define CredentialFilesTool with SCHEMA: action(list/add/remove), name(string), path(?string)
- [ ] execute: list → scan dir, add → copy file, remove → delete
- [ ] Test: schema name check

### A15-A19: browser_camofox, browser_camofox_state, neutts_synth, rl_training, mcp_oauth
**Requirement:** Specialized tools with external dependencies.
**Design:** All stubs with descriptive messages (depend on external services).
**Tasks:**
- [ ] Create each with SCHEMA + stub execute returning description of what's needed
- [ ] Test: schema name check for each

---

## Group B: Missing Utility Modules (8)

### B1. tools/util/ansi.zig
**Requirement:** Strip ANSI escape codes from strings.
**Tasks:**
- [ ] `stripAnsi(input) []const u8` — regex-free: scan for ESC[, skip to terminator
- [ ] Test: strip colors from "\\x1b[31mhello\\x1b[0m" → "hello"

### B2. tools/util/patch.zig
**Requirement:** Parse unified diff format for file_edit.
**Tasks:**
- [ ] `parsePatch(diff_text) []Hunk` — parse @@ lines, extract old/new content
- [ ] Test: parse simple diff

### B3. tools/util/fuzzy.zig
**Requirement:** Fuzzy string matching for command/skill name lookup.
**Tasks:**
- [ ] `fuzzyMatch(query, candidates) []Match` — simple substring + Levenshtein distance
- [ ] Test: "brwsr" matches "browser"

### B4-B8: debug, env, interrupt, openrouter, file_operations
**Tasks:**
- [ ] Create each as small utility module
- [ ] Test each

---

## Group C: Missing Gateway (2) + Terminal (1)

### C1. api_server.zig (1336 lines in Python)
**Requirement:** OpenAI-compatible API server — expose hermes as an API endpoint.
**Design:** HTTP server (reuse server pattern from zig-proxy-api) with /v1/chat/completions endpoint that routes to AgentLoop.
**Tasks:**
- [ ] ApiServerAdapter implementing PlatformAdapter vtable
- [ ] HTTP server on configurable port
- [ ] POST /v1/chat/completions → AgentLoop.run → return response
- [ ] SSE streaming support
- [ ] Test: init + platform name

### C2. telegram_network.zig
**Requirement:** Telegram network abstraction layer (HTTP client wrapper for Bot API).
**Tasks:**
- [ ] TelegramNetwork: getUpdates, sendMessage, editMessage via HTTP
- [ ] Test: init

### C3. persistent_shell.zig
**Requirement:** Persistent shell sessions that survive across tool calls.
**Design:** Spawn shell process once, keep stdin/stdout pipes open, send commands and read output.
**Tasks:**
- [ ] PersistentShellBackend: spawn shell, write command + delimiter, read until delimiter
- [ ] Add to TerminalBackend tagged union
- [ ] Test: init

---

## Group D: Missing Agent Features (10)

### D1-D10: Agent loop enhancements
**Tasks:**
- [ ] D1: Model fallback — in loop.zig, catch LlmApiError → try fallback model from config
- [ ] D2: Honcho integration — create intelligence/honcho.zig, HTTP client to Honcho API
- [ ] D3: Codex mode — in llm/, add Responses API support (POST /v1/responses)
- [ ] D4: Vision messages — in llm/interface.zig, add image_url field to Message
- [ ] D5: Reasoning wiring — in loop.zig, pass config.reasoning to CompletionRequest
- [ ] D6: Interrupt wiring — in loop.zig, check interrupt flag before each LLM call
- [ ] D7: Session persistence — in loop.zig, call database.appendMessage after each turn
- [ ] D8: Context file scan — in prompt_builder.zig, call security/injection.scanForInjection on context files
- [ ] D9: Parallel tool calls — in loop.zig, use std.Thread to execute tool calls concurrently
- [ ] D10: Background review — stub, log that review would happen

---

## Group E: Missing CLI Features (6)

### E1-E6: CLI enhancements
**Tasks:**
- [ ] E1: Tab completion — in tui.zig, on Tab key, match partial input against command list
- [ ] E2: Skin engine — create cli/skin.zig, load theme from JSON, apply colors
- [ ] E3: Banner — create cli/banner.zig, ASCII art banner on startup
- [ ] E4: Status bar — create cli/status.zig, bottom line showing model + tokens + session
- [ ] E5: Runtime model switch — in commands.zig, /model command updates config and recreates LlmClient
- [ ] E6: Plugin system — create cli/plugins.zig, scan ~/.hermes/plugins/ for plugin configs

---

## Group F: Missing Intelligence Features (5)

### F1-F5: Intelligence enhancements
**Tasks:**
- [ ] F1: Skills creator — create intelligence/skills_creator.zig, after complex task detect pattern and write SKILL.md
- [ ] F2: Skills execution — update intelligence/skills_executor.zig, inject skill body into system prompt
- [ ] F3: Skills Hub client — create intelligence/skills_hub_client.zig, HTTP to agentskills.io
- [ ] F4: User modeling — create intelligence/user_model.zig, Honcho HTTP integration
- [ ] F5: Bundled skills — create skills/ directory with SKILL.md files (copy from Python project)

---

## Execution Order

```
Batch 1 (Tools):     A1-A19 + B1-B8     (27 items, mostly small files)
Batch 2 (Gateway):   C1-C3              (3 items)
Batch 3 (Agent):     D1-D10             (10 items, modifications to existing files)
Batch 4 (CLI):       E1-E6              (6 items)
Batch 5 (Intel):     F1-F5              (5 items)
```

Total: 51 items across 5 batches.
