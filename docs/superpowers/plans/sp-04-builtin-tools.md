# SP-4: Built-in Tools — Detailed Implementation Plan

> **For agentic workers:** Read Python files in tools/ directory. Each tool MUST use `makeToolHandler` comptime pattern.

**Goal:** 20+ built-in tools, all using comptime SCHEMA + execute pattern.

**PATTERN (every tool follows this):**
```zig
pub const MyTool = struct {
    // dependencies injected at init
    backend: *TerminalBackend,  // or whatever this tool needs

    pub const SCHEMA = ToolSchema{
        .name = "my_tool",
        .description = "What this tool does",
        .parameters_schema = \\{"type":"object","properties":{...},"required":[...]}
    };

    pub fn execute(self: *MyTool, args: std.json.Value, ctx: *const ToolContext) anyerror![]const u8 {
        // parse args, do work, return result string
    }
};
// Registration: makeToolHandler(MyTool, &instance)
```

---

## Task 1: Terminal Tools (bash)

**Files:** src/tools/builtin/root.zig, src/tools/builtin/bash.zig

- [ ] BashTool: execute command via TerminalBackend, return stdout/stderr
- [ ] Schema: `{"command": string, "timeout": ?integer}`
- [ ] Parse args.object.get("command"), call backend.execute()
- [ ] Format result: success → stdout, failure → exit code + stdout + stderr
- [ ] Test: execute `echo hello`, verify output
- [ ] Commit: `feat(tools): add bash tool`

## Task 2: File Tools

**Files:** src/tools/builtin/file_read.zig, file_write.zig, file_edit.zig, file_tools.zig

- [ ] file_read: Read file with optional start_line/end_line. Schema: `{"path": string, "start_line": ?int, "end_line": ?int}`
- [ ] file_write: Create/overwrite file, create parent dirs. Schema: `{"path": string, "content": string}`
- [ ] file_edit: Apply unified diff patch. Schema: `{"path": string, "diff": string}`. Parse unified diff format, apply hunks.
- [ ] file_tools: ls (list dir), find (glob pattern), grep (regex search), tree (recursive listing). Schema: `{"operation": enum, "path": string, "pattern": ?string}`
- [ ] All use ctx.working_dir as base path, security: resolve and check path doesn't escape working_dir
- [ ] Tests for each
- [ ] Commit: `feat(tools): add file tools (read, write, edit, ls/find/grep/tree)`

## Task 3: Web Tools

**Files:** src/tools/builtin/web_search.zig, browser.zig

- [ ] web_search: HTTP call to Tavily API or DuckDuckGo. Schema: `{"query": string, "num_results": ?int}`
- [ ] browser: Spawn headless browser process, navigate, extract content. Schema: `{"url": string, "action": enum(navigate,click,type,screenshot)}`
- [ ] Tests with mock HTTP
- [ ] Commit: `feat(tools): add web search and browser tools`

## Task 4: Code + Vision Tools

**Files:** src/tools/builtin/code_execution.zig, vision.zig

- [ ] code_execution: Execute Python/JS code in sandbox via TerminalBackend. Schema: `{"language": enum(python,javascript), "code": string}`
- [ ] vision: Send image to LLM vision API (base64 encode). Schema: `{"image_path": string, "prompt": string}`. Needs LlmClient reference.
- [ ] Tests
- [ ] Commit: `feat(tools): add code execution and vision tools`

## Task 5: Communication Tools

**Files:** src/tools/builtin/todo.zig, delegate.zig, send_message.zig, clarify.zig, memory_tool.zig

- [ ] todo: CRUD todo items in SQLite. Schema: `{"action": enum(add,list,complete,delete), "text": ?string, "id": ?int}`
- [ ] delegate: Spawn subagent in new thread with isolated context. Schema: `{"task": string, "model": ?string}`
- [ ] send_message: Send message to platform via gateway. Schema: `{"platform": string, "chat_id": string, "content": string}`
- [ ] clarify: Ask user for input (return special marker that agent loop handles). Schema: `{"question": string}`
- [ ] memory_tool: Read/write/search persistent memory. Schema: `{"action": enum(read,write,search), "key": ?string, "content": ?string, "query": ?string}`
- [ ] Tests
- [ ] Commit: `feat(tools): add communication and memory tools`

## Task 6: Media Tools

**Files:** src/tools/builtin/image_gen.zig, transcription.zig, tts.zig, voice_mode.zig, cronjob.zig

- [ ] image_gen: Call image generation API (DALL-E/Stable Diffusion). Schema: `{"prompt": string, "size": ?string}`
- [ ] transcription: Call Whisper API with audio file. Schema: `{"audio_path": string}`
- [ ] tts: Call TTS API, save audio file. Schema: `{"text": string, "voice": ?string}`
- [ ] voice_mode: Continuous voice loop (transcribe → LLM → TTS → play). Schema: `{"action": enum(start,stop)}`
- [ ] cronjob: CRUD cron jobs in SQLite. Schema: `{"action": enum(add,list,delete), "schedule": ?string, "command": ?string}`
- [ ] Tests
- [ ] Commit: `feat(tools): add media and cron tools`
