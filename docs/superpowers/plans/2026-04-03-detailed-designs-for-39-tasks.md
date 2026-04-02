# Detailed Design for 39 Incomplete Tasks

> Supplements phase1-to-5-complete.md with full design for every one-liner task.

---

## P1.11: core/constants.zig

**Python:** hermes_constants.py — HERMES_HOME, provider URLs, reasoning efforts.
**Design:**
```zig
pub fn getHermesHome(allocator: std.mem.Allocator) ![]u8 {
    return std.process.getEnvVarOwned(allocator, "HERMES_HOME") catch
        try std.fs.path.join(allocator, &.{ std.posix.getenv("HOME") orelse ".", ".hermes" });
}
pub const OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1";
pub const OPENAI_BASE_URL = "https://api.openai.com/v1";
pub const ANTHROPIC_BASE_URL = "https://api.anthropic.com";
pub const NOUS_BASE_URL = "https://inference-api.nousresearch.com/v1";
```
**Tasks:**
- [ ] Create src/core/constants.zig with getHermesHome + all provider URLs
- [ ] Move existing URL constants from types.zig to constants.zig
- [ ] Test: getHermesHome returns non-empty path

## P1.12: core/time_utils.zig

**Python:** hermes_time.py — timezone-aware timestamps, relative time display.
**Design:**
```zig
pub fn nowUnixMs() i64 { return std.time.milliTimestamp(); }
pub fn formatTimestamp(allocator: std.mem.Allocator, unix_ms: i64) ![]u8  // "2026-04-03 00:45:00"
pub fn relativeTime(allocator: std.mem.Allocator, unix_ms: i64) ![]u8    // "5 minutes ago"
```
**Tasks:**
- [ ] Create src/core/time_utils.zig
- [ ] formatTimestamp: epoch ms → "YYYY-MM-DD HH:MM:SS"
- [ ] relativeTime: epoch ms → "N seconds/minutes/hours/days ago"
- [ ] Test: known timestamp → expected string

## P1.13: core/utils.zig

**Python:** utils.py — atomic JSON write, misc helpers.
**Design:**
```zig
pub fn atomicJsonWrite(allocator: std.mem.Allocator, path: []const u8, json: []const u8) !void
// Write to temp file, then rename (atomic on POSIX)
pub fn ensureDir(path: []const u8) !void
pub fn expandHome(allocator: std.mem.Allocator, path: []const u8) ![]u8  // ~ → home dir
```
**Tasks:**
- [ ] Create src/core/utils.zig
- [ ] atomicJsonWrite: write to .tmp, rename
- [ ] expandHome: replace leading ~ with HOME
- [ ] Test: atomicJsonWrite + read back

## P1.14: tools/model_tools.zig

**Python:** model_tools.py — orchestration layer over tool registry.
**Design:**
```zig
pub fn getToolDefinitions(registry: *ToolRegistry, enabled_toolsets: []const []const u8) []ToolSchema
// Collect schemas from registry, filter by toolset membership
pub fn handleToolCall(registry: *ToolRegistry, name: []const u8, args: []const u8, ctx: *const ToolContext) ![]const u8
// Dispatch to registry, wrap errors
```
**Tasks:**
- [ ] Create src/tools/model_tools.zig
- [ ] getToolDefinitions: filter by enabled toolsets
- [ ] handleToolCall: dispatch + error wrapping
- [ ] Test: with mock registry

## P1.15: Integration test

**Tasks:**
- [ ] Create test script that: starts hermes-zig, sends /config, sends /tools, sends /quit
- [ ] Verify no crashes, correct output
- [ ] Document manual test: configure real API key, send message, verify response

---

## P3.9: cli/cron_cmd.zig

**Python:** hermes_cli/cron.py (240 lines) — CLI cron subcommands.
**Design:**
```zig
pub fn handleCronCommand(allocator: std.mem.Allocator, args: []const u8, stdout: std.fs.File) !void {
    // Parse: "add", "list", "remove {id}", "status", "run {id}"
    // add: prompt for schedule + command, save to cron_jobs table
    // list: query cron_jobs, display table
    // remove: delete by id
    // status: show scheduler state
}
```
**Tasks:**
- [ ] Create src/interface/cli/cron_cmd.zig
- [ ] Wire /cron command in main.zig handleCommand
- [ ] add: read schedule + command from stdin, insert into SQLite
- [ ] list: query + format as table
- [ ] remove: delete by id
- [ ] Test: add + list

## P3.10: cli/skills_config.zig

**Python:** hermes_cli/skills_config.py (150 lines) — toggle skills on/off.
**Design:**
```zig
pub fn handleSkillsConfig(allocator: std.mem.Allocator, args: []const u8, stdout: std.fs.File) !void {
    // "disable {name}" → add to config.skills.disabled
    // "enable {name}" → remove from config.skills.disabled
    // "list" → show all skills with enabled/disabled status
}
```
**Tasks:**
- [ ] Create src/interface/cli/skills_config.zig
- [ ] Read/write disabled list in config.json
- [ ] Wire /skills config command
- [ ] Test: disable + enable roundtrip

## P3.11: cli/model_switch.zig

**Python:** hermes_cli/model_switch.py (200 lines) — runtime model switching.
**Design:**
```zig
pub const ModelSwitchResult = struct { provider: []const u8, model: []const u8, base_url: []const u8 };
pub fn parseModelInput(input: []const u8) ModelSwitchResult
// "openai/gpt-4o" → provider=openai, model=gpt-4o
// "gpt-4o" → auto-detect provider from model name
// "anthropic:claude-sonnet-4" → provider=anthropic, model=claude-sonnet-4
pub fn switchModel(allocator: std.mem.Allocator, input: []const u8, config_path: []const u8) !void
// Parse input, update config.json, recreate LlmClient
```
**Tasks:**
- [ ] Create src/interface/cli/model_switch.zig
- [ ] parseModelInput with provider auto-detection
- [ ] switchModel: update config + notify agent loop
- [ ] Test: parse various model input formats

## P3.12: cli/clipboard.zig

**Python:** hermes_cli/clipboard.py (310 lines) — clipboard image extraction.
**Design:**
```zig
pub fn saveClipboardImage(allocator: std.mem.Allocator, dest_path: []const u8) !bool {
    // macOS: osascript -e 'clipboard info' then pngpaste
    // Linux/WSL: wl-paste --type image/png or xclip -selection clipboard -t image/png
    // Windows: powershell Get-Clipboard -Format Image
    // Shell out via std.process.Child, save stdout to dest_path
}
```
**Tasks:**
- [ ] Create src/interface/cli/clipboard.zig
- [ ] Detect platform (builtin.os.tag)
- [ ] macOS: osascript + pngpaste
- [ ] Linux: wl-paste or xclip
- [ ] Windows: powershell
- [ ] Test: function exists, returns false when no image

## P3.13: cli/ansi_colors.zig

**Python:** hermes_cli/colors.py (24 lines) — ANSI color constants.
**Design:** Already have colors in tui.zig. Consolidate into shared module.
**Tasks:**
- [ ] Create src/interface/cli/ansi_colors.zig with all ANSI codes (reset, bold, dim, red, green, yellow, blue, cyan, white, bg variants)
- [ ] Use from tui.zig, display.zig, banner.zig
- [ ] Test: constants are non-empty

## P3.14: cli/main_entry.zig

**Python:** hermes_cli/main.py (5160 lines) — full argument parsing.
**Design:**
```zig
pub const Command = enum { chat, gateway, setup, model, tools, skills, config, cron, doctor, update, version, help };
pub fn parseArgs(allocator: std.mem.Allocator) !ParsedArgs {
    // hermes → chat (default)
    // hermes gateway start/stop/setup → gateway
    // hermes setup → setup
    // hermes model → model
    // etc.
}
```
**Tasks:**
- [ ] Create src/interface/cli/main_entry.zig
- [ ] Parse first arg as subcommand
- [ ] Dispatch to appropriate handler
- [ ] Wire into main.zig replacing current simple logic
- [ ] Test: parse "gateway start", "model", "setup"

---

## P4.7: browser_actions — Playwright CLI

**Python:** tools/browser_tool.py (2057 lines) — 11 browser actions via CDP.
**Design:** Shell out to `npx playwright` or `playwright` CLI. Each action = one CLI call.
```zig
fn executeViaPlaywright(allocator: std.mem.Allocator, action: []const u8, args_json: []const u8) ![]u8 {
    // Build command: playwright {action} --{arg}={value}
    // Execute via std.process.Child
    // Return stdout
    // If playwright not found: return "Install playwright: npm i -g playwright"
}
```
**Tasks:**
- [ ] Check if playwright is available (which playwright)
- [ ] Map each action to playwright CLI command
- [ ] browser_navigate: `playwright open {url}`
- [ ] browser_snapshot: `playwright screenshot {url} {output}`
- [ ] Other actions: return "Requires playwright CDP connection"
- [ ] Test: check availability returns bool

## P4.8: mixture_of_agents — Multi-model

**Python:** tools/mixture_of_agents_tool.py (562 lines) — layered multi-model.
**Design:**
```zig
pub fn execute(self: *MixtureOfAgentsTool, args_json: []const u8, ctx: *const ToolContext) ![]u8 {
    // Parse: prompt, models (comma-separated)
    // For each model: create CompletionRequest, call LlmClient.complete
    // Combine: "Model A said: ...\nModel B said: ...\n\nSynthesis: ..."
    // Final synthesis call with combined context
}
```
Needs `llm_client: *LlmClient` field.
**Tasks:**
- [ ] Add llm_client field to MixtureOfAgentsTool
- [ ] Parse model list from args
- [ ] Sequential calls (parallel in future)
- [ ] Combine responses
- [ ] Test: with mock LLM returning different responses

## P4.9-P4.10: TTS/Transcription extensions

**Design:** Add config fields for alternative backends (NeuTTS, local Whisper).
**Tasks:**
- [ ] P4.9: tts.zig — check config for neutts_url, if set POST to NeuTTS API instead of OpenAI
- [ ] P4.10: transcription.zig — check for local whisper binary, if found use `whisper {audio} --output-format txt`

## P4.11-P4.15: Gateway real implementations

Each platform adapter needs: connect (start polling/WebSocket), send (HTTP POST), message parsing.

### P4.11: Telegram
**Python:** gateway/platforms/telegram.py (2128 lines)
**Design:**
```zig
// connect: spawn thread, loop GET /getUpdates?offset={last+1}&timeout=30
// parse Update JSON: .message.text, .message.chat.id, .message.from.id
// push IncomingMessage to MessageQueue
// send: POST /sendMessage with chat_id + text
```
**Tasks:**
- [ ] Implement getUpdates long polling in connect thread
- [ ] Parse Update JSON for text messages
- [ ] Implement sendMessage POST
- [ ] Handle media (photos, documents) — extract file_id, download via getFile
- [ ] Test: with mock HTTP

### P4.12: Discord
**Python:** gateway/platforms/discord.py (2300 lines)
**Design:**
```zig
// connect: WebSocket to wss://gateway.discord.gg/?v=10&encoding=json
// Handle: HELLO (start heartbeat), IDENTIFY, DISPATCH (MESSAGE_CREATE)
// send: POST /api/v10/channels/{id}/messages
```
**Tasks:**
- [ ] Implement WebSocket connection (use std.net.Stream + TLS)
- [ ] Handle gateway opcodes (HELLO=10, HEARTBEAT=1, IDENTIFY=2, DISPATCH=0)
- [ ] Parse MESSAGE_CREATE events
- [ ] Implement REST send
- [ ] Test: with mock WebSocket

### P4.13: Slack
**Python:** gateway/platforms/slack.py (967 lines)
**Design:**
```zig
// connect: start HTTP server for Events API webhook
// Receive POST /slack/events with event_callback type
// Parse: event.type=message, event.text, event.channel
// send: POST https://slack.com/api/chat.postMessage with Bearer token
```
**Tasks:**
- [ ] HTTP webhook server for events
- [ ] Parse event payloads
- [ ] Implement chat.postMessage
- [ ] Test: with mock HTTP

### P4.14: WhatsApp
**Python:** gateway/platforms/whatsapp.py (809 lines)
**Design:**
```zig
// connect: start HTTP server for webhook verification + message receipt
// GET /webhook?hub.verify_token={token} → return hub.challenge
// POST /webhook with messages[].text.body
// send: POST https://graph.facebook.com/v17.0/{phone_id}/messages
```
**Tasks:**
- [ ] Webhook verification endpoint
- [ ] Parse incoming message JSON
- [ ] Implement send via Graph API
- [ ] Test: with mock HTTP

### P4.15: Webhook (generic)
**Python:** gateway/platforms/webhook.py (616 lines)
**Design:**
```zig
// connect: start HTTP server on configured port
// POST /message with {chat_id, content} → push to MessageQueue
// GET /health → 200 OK
// send: POST to configured callback_url with response
```
**Tasks:**
- [ ] HTTP server with /message and /health endpoints
- [ ] Parse incoming JSON
- [ ] Send response to callback_url
- [ ] Test: with mock HTTP

---

## P5.1-P5.7: ACP Adapter

**Python:** acp_adapter/ (8 files, 1575 lines) — Agent Client Protocol for editor integration.

### P5.1: acp/auth.zig
**Design:** `detectProvider() ?[]const u8` — check env vars for API keys. `hasProvider() bool`.
**Tasks:**
- [ ] Check OPENAI_API_KEY, ANTHROPIC_API_KEY, OPENROUTER_API_KEY env vars
- [ ] Return provider name or null

### P5.2: acp/events.zig
**Design:** SSE event helpers for streaming tool progress to editor.
```zig
pub fn sendUpdate(writer: anytype, event_type: []const u8, data: []const u8) !void
// Write "event: {type}\ndata: {data}\n\n"
pub fn makeToolProgressCallback(...) StreamCallback
pub fn makeThinkingCallback(...) StreamCallback
```
**Tasks:**
- [ ] SSE event formatting
- [ ] Tool progress callback
- [ ] Thinking indicator callback

### P5.3: acp/permissions.zig
**Design:** Tool approval callback for ACP — editor shows approval dialog.
```zig
pub fn makeApprovalCallback(session: *SessionState) ApprovalFn
// Returns function that sends approval request to editor, waits for response
```
**Tasks:**
- [ ] Approval request/response protocol
- [ ] Timeout handling

### P5.4: acp/session.zig
**Design:** ACP session lifecycle.
```zig
pub const SessionState = struct { id: []const u8, cwd: []const u8, messages: std.ArrayList(Message) };
pub const SessionManager = struct {
    pub fn createSession(cwd: []const u8) !*SessionState
    pub fn getSession(id: []const u8) ?*SessionState
    pub fn deleteSession(id: []const u8) void
};
```
**Tasks:**
- [ ] Session CRUD with HashMap storage
- [ ] Session isolation (each has own message history)

### P5.5: acp/tools.zig
**Design:** Expose hermes tools in ACP format.
```zig
pub fn getToolKind(name: []const u8) ToolKind  // read_only, write, dangerous
pub fn buildToolStart(name: []const u8, args: anytype) []u8  // ACP tool_start event
pub fn buildToolComplete(name: []const u8, result: []const u8) []u8  // ACP tool_complete event
```
**Tasks:**
- [ ] Tool kind classification
- [ ] ACP event formatting

### P5.6: acp/entry.zig
**Design:** ACP server entry point.
**Tasks:**
- [ ] Setup logging
- [ ] Load env
- [ ] Start ACP HTTP server

### P5.7: acp/server.zig (extend existing)
**Tasks:**
- [ ] POST /sessions → create session
- [ ] POST /sessions/{id}/messages → run agent, stream response via SSE
- [ ] DELETE /sessions/{id} → end session
- [ ] GET /tools → list tools in ACP format

---

## P5.8-P5.10: Honcho Integration

### P5.8: intelligence/honcho_client.zig
**Design:**
```zig
pub const HonchoClient = struct {
    base_url: []const u8, api_key: []const u8, allocator: std.mem.Allocator,
    pub fn getUserContext(self, user_id: []const u8) ![]u8  // GET /users/{id}/context
    pub fn updateProfile(self, user_id: []const u8, data: []const u8) !void  // POST /users/{id}/profile
    pub fn searchHistory(self, user_id: []const u8, query: []const u8) ![]u8  // POST /users/{id}/search
};
```
**Tasks:**
- [ ] HTTP client with auth header
- [ ] 3 API endpoints
- [ ] Test: with mock HTTP

### P5.9: intelligence/honcho_session.zig
**Design:** Per-session Honcho context injection.
**Tasks:**
- [ ] At session start: fetch user context from Honcho
- [ ] Inject into system prompt
- [ ] At session end: update user profile with conversation summary

### P5.10: intelligence/honcho_cli.zig
**Design:** CLI commands for Honcho.
**Tasks:**
- [ ] hermes honcho status — show connection status
- [ ] hermes honcho profile — show user profile
- [ ] hermes honcho reset — clear user data

---

## P5.11-P5.13: Environments/RL

### P5.11: environments/base_env.zig
**Design:**
```zig
pub const BaseEnv = struct {
    ptr: *anyopaque, vtable: *const VTable,
    pub const VTable = struct {
        reset: *const fn (ptr: *anyopaque) anyerror!void,
        step: *const fn (ptr: *anyopaque, action: []const u8) anyerror!StepResult,
        getObservation: *const fn (ptr: *anyopaque) anyerror![]const u8,
    };
};
pub const StepResult = struct { observation: []const u8, reward: f64, done: bool };
```
**Tasks:**
- [ ] Define BaseEnv vtable interface
- [ ] StepResult struct
- [ ] Test: interface compiles

### P5.12: environments/agent_loop_env.zig
**Design:** Wrap AgentLoop as an RL environment.
**Tasks:**
- [ ] reset: create new session
- [ ] step: send message to agent, get response
- [ ] Reward: based on task completion

### P5.13: environments/web_research_env.zig
**Design:** Web research environment for RL training.
**Tasks:**
- [ ] Provide research tasks
- [ ] Agent uses web_search + browser tools
- [ ] Evaluate research quality

---

## P5.14: Bundled Skills

**Tasks:**
- [ ] Create skills/ directory in project root
- [ ] Copy 74 SKILL.md files from Python project, organized by category
- [ ] Categories: software-development, research, creative, productivity, github, mlops, etc.
- [ ] Verify skills_list tool can find and list them

---

## P5.15-P5.20: Low Priority

### P5.15: cli/claw.zig — OpenClaw migration
**Design:** Read ~/.openclaw/ config, convert to hermes format, copy memories/skills.
**Tasks:**
- [ ] Detect ~/.openclaw/ directory
- [ ] Parse OpenClaw config.yaml
- [ ] Convert to hermes config.json format
- [ ] Copy SOUL.md, MEMORY.md, skills/

### P5.16: cli/skin_engine.zig — Theme system
**Design:** Load theme JSON, provide color lookup by semantic name (prompt, error, success, tool, etc.).
**Tasks:**
- [ ] Theme struct with semantic color names
- [ ] Load from ~/.hermes/theme.json
- [ ] Default theme embedded
- [ ] Apply to all CLI output

### P5.17: cli/plugins_cmd.zig — Plugin management
**Design:** hermes plugins install/remove/list. Plugins are directories in ~/.hermes/plugins/ with a manifest.json.
**Tasks:**
- [ ] Scan plugins directory
- [ ] Parse manifest.json (name, version, tools, skills)
- [ ] Install: download + extract
- [ ] Remove: delete directory

### P5.18: cli/uninstall.zig
**Design:** Remove hermes installation.
**Tasks:**
- [ ] Remove ~/.hermes/ directory (with confirmation)
- [ ] Remove hermes binary from PATH

### P5.19: mcp_serve.zig — Expose as MCP server
**Design:** Run hermes tools as an MCP server (JSON-RPC over stdin/stdout).
**Tasks:**
- [ ] Implement MCP initialize handshake
- [ ] Implement tools/list → return all tool schemas
- [ ] Implement tools/call → dispatch to tool registry
- [ ] Test: mock MCP client

### P5.20: rl_cli.zig — RL training CLI
**Design:** hermes rl start/stop/status/results commands.
**Tasks:**
- [ ] Parse RL subcommands
- [ ] Delegate to rl_training tools
- [ ] Display training progress
