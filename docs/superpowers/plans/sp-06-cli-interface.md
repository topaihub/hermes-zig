# SP-6: CLI Interface — Detailed Implementation Plan

> **For agentic workers:** Read Python files: cli.py, hermes_cli/main.py, hermes_cli/commands.py, hermes_cli/setup.py

**Goal:** Full terminal UI with multiline editing, slash commands, streaming display.

---

## Task 1: TUI Core

**Files:** src/interface/cli/root.zig, src/interface/cli/tui.zig

- [ ] Raw terminal mode (disable ICANON + ECHO, set VMIN=0 VTIME=1)
- [ ] Input loop: read bytes, handle special keys (arrows, Ctrl+C, Ctrl+D, Enter, Tab)
- [ ] Multiline input: Shift+Enter or Ctrl+Enter for newline, Enter to submit
- [ ] ANSI rendering: colors, bold, clear line, cursor movement
- [ ] Prompt display: `hermes> ` with optional context usage indicator
- [ ] Interrupt handling: Ctrl+C cancels current LLM call (set flag checked by agent loop)
- [ ] Tests: key parsing, prompt rendering
- [ ] Commit: `feat(cli): add TUI core with raw terminal mode`

## Task 2: Slash Commands

**Files:** src/interface/cli/commands.zig

- [ ] Command parser: detect `/` prefix, split command + args
- [ ] Commands:
  - `/new` / `/reset` — start new session
  - `/model [provider:model]` — switch model
  - `/personality [name]` — set personality
  - `/tools` — list enabled tools
  - `/skills` — list available skills
  - `/compress` — manually compress context
  - `/usage` — show token usage for current session
  - `/undo` — remove last user+assistant turn
  - `/retry` — re-run last user message
  - `/insights [--days N]` — usage insights
  - `/save` / `/load` — session persistence
  - `/help` — show command list
  - `/quit` — exit
- [ ] Tab completion for command names
- [ ] Tests: parse commands, verify dispatch
- [ ] Commit: `feat(cli): add slash commands`

## Task 3: Streaming Display

**Files:** src/interface/cli/display.zig

- [ ] StreamDisplay struct: receives StreamCallback deltas, renders incrementally
- [ ] Text rendering: append delta content to current line, handle newlines
- [ ] Tool call rendering: show tool name + args when tool_call starts, show result when done
- [ ] Spinner: animated dots while waiting for LLM response
- [ ] Markdown rendering: bold (**), code blocks (```), headers (#)
- [ ] Tests: render deltas, verify output
- [ ] Commit: `feat(cli): add streaming display with tool call rendering`

## Task 4: History + Setup + Auth + Profiles + Doctor

**Files:** src/interface/cli/history.zig, setup.zig, auth.zig, profiles.zig, doctor.zig

- [ ] history.zig: Command history with up/down arrows, persistent to ~/.hermes/history
- [ ] setup.zig: Interactive wizard — select provider → enter API key → select model → test connection
- [ ] auth.zig: API key management — add (prompt for key), remove, list (masked), test (make API call)
- [ ] profiles.zig: Profile CRUD — create (copy config), switch (update symlink), list, delete
- [ ] doctor.zig: Diagnostic checks — API connectivity, SQLite writable, tools available, config valid
- [ ] Tests for each
- [ ] Commit: `feat(cli): add history, setup wizard, auth, profiles, doctor`
