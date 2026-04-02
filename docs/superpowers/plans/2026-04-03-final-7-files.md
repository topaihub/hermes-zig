# Final 7 Missing Files — Requirements, Design, Tasks

---

## 1. agent/display.zig — CLI presentation (spinner, tool preview)

**Python:** agent/display.py (1,084 lines) — spinner animation, kawaii faces, tool call formatting, streaming display.
**Requirement:** Format tool calls and results for CLI display. Show spinner while waiting.
**Design:**
```zig
pub const Spinner = struct {
    frames: []const []const u8 = &.{ "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
    frame_idx: usize = 0,
    pub fn next(self: *Spinner) []const u8
    pub fn clear(stdout: std.fs.File) void  // clear spinner line
};
pub fn formatToolCall(allocator: Allocator, name: []const u8, args: []const u8) ![]u8
// "⚡ terminal(command: \"ls -la\")"
pub fn formatToolResult(allocator: Allocator, name: []const u8, output: []const u8, is_error: bool) ![]u8
// "→ [200 chars] ..." (truncate long output)
pub fn formatStreamDelta(stdout: std.fs.File, content: []const u8) void
// Write content directly, handle partial lines
```
**Tasks:**
- [ ] Create src/agent/display.zig with Spinner, formatToolCall, formatToolResult, formatStreamDelta
- [ ] Spinner: cycle through braille frames, clear with \r + spaces
- [ ] formatToolCall: parse args JSON, show key=value pairs
- [ ] formatToolResult: truncate to 500 chars, show [error] prefix if is_error
- [ ] Test: formatToolCall produces expected format
- [ ] Update agent/root.zig exports

## 2. interface/cli/checklist.zig — Interactive multi-select

**Python:** hermes_cli/checklist.py (140 lines) — curses-based multi-select, text fallback.
**Requirement:** Show a list of items with checkboxes, user toggles with space, confirms with enter.
**Design:**
```zig
pub const ChecklistItem = struct { label: []const u8, checked: bool = false };
pub fn runChecklist(allocator: Allocator, title: []const u8, items: []ChecklistItem, stdout: std.fs.File, stdin: std.fs.File) !void {
    // Text-based fallback (no curses in Zig):
    // Display numbered list with [x] or [ ]
    // User types number to toggle, 'done' to confirm
}
```
**Tasks:**
- [ ] Create src/interface/cli/checklist.zig
- [ ] Text-based UI: show numbered items with checkboxes
- [ ] Toggle by number, confirm with empty line
- [ ] Test: ChecklistItem struct init

## 3. interface/cli/claw.zig — OpenClaw migration

**Python:** hermes_cli/claw.py (568 lines) — migrate from ~/.openclaw to ~/.hermes.
**Requirement:** Detect OpenClaw install, copy config/memories/skills.
**Design:**
```zig
pub fn handleClawCommand(allocator: Allocator, args: []const u8, stdout: std.fs.File) !void {
    // "migrate" → detect ~/.openclaw, copy SOUL.md, MEMORY.md, skills/, config
    // "migrate --dry-run" → show what would be copied
    // "cleanup" → archive ~/.openclaw to ~/.openclaw.bak
}
fn detectOpenClaw(allocator: Allocator) !bool  // check if ~/.openclaw exists
fn migrateConfig(allocator: Allocator, dry_run: bool) !void
fn migrateMemories(allocator: Allocator, dry_run: bool) !void
fn migrateSkills(allocator: Allocator, dry_run: bool) !void
```
**Tasks:**
- [ ] Create src/interface/cli/claw.zig
- [ ] detectOpenClaw: check directory exists
- [ ] migrate: copy files with dry-run support
- [ ] cleanup: rename directory
- [ ] Test: detectOpenClaw returns false when dir missing

## 4. interface/cli/codex_models.zig — Codex model discovery

**Python:** hermes_cli/codex_models.py (176 lines) — discover Codex models from API/cache.
**Requirement:** List available Codex/OpenAI models.
**Design:**
```zig
pub const CodexModel = struct { id: []const u8, name: []const u8, context_window: u32 = 128000 };
pub const default_models = [_]CodexModel{
    .{ .id = "gpt-4o", .name = "GPT-4o", .context_window = 128000 },
    .{ .id = "gpt-4o-mini", .name = "GPT-4o Mini", .context_window = 128000 },
    .{ .id = "o1-preview", .name = "O1 Preview", .context_window = 128000 },
    .{ .id = "o3-mini", .name = "O3 Mini", .context_window = 200000 },
};
pub fn listModels() []const CodexModel { return &default_models; }
```
**Tasks:**
- [ ] Create src/interface/cli/codex_models.zig
- [ ] Static model list
- [ ] Test: listModels returns non-empty

## 5. interface/cli/copilot_auth.zig — GitHub Copilot OAuth

**Python:** hermes_cli/copilot_auth.py (294 lines) — OAuth device code flow for Copilot.
**Requirement:** Authenticate with GitHub Copilot API.
**Design:**
```zig
pub const CopilotAuth = struct {
    pub fn isTokenValid(token: []const u8) bool  // check prefix: gho_, github_pat_, ghu_
    pub fn startDeviceFlow(allocator: Allocator) !DeviceFlowResult  // POST to github.com/login/device/code
    pub fn pollForToken(allocator: Allocator, device_code: []const u8) !?[]u8  // poll until user approves
};
pub const DeviceFlowResult = struct { device_code: []const u8, user_code: []const u8, verification_uri: []const u8 };
```
**Tasks:**
- [ ] Create src/interface/cli/copilot_auth.zig
- [ ] isTokenValid: check token prefix
- [ ] startDeviceFlow: HTTP POST stub
- [ ] pollForToken: HTTP POST stub
- [ ] Test: isTokenValid for known prefixes

## 6. interface/cli/curses_ui.zig — Curses UI components

**Python:** hermes_cli/curses_ui.py (172 lines) — curses multi-select with keyboard nav.
**Requirement:** Interactive UI with arrow keys and space to toggle.
**Design:** Since Zig doesn't have curses, implement with raw terminal mode (already have in tui.zig):
```zig
pub fn runInteractiveSelect(allocator: Allocator, items: []const []const u8, stdout: std.fs.File, stdin: std.fs.File) !?usize {
    // Raw mode, show items with > cursor
    // Up/down arrows move cursor, Enter selects, q quits
    // Return selected index or null
}
```
**Tasks:**
- [ ] Create src/interface/cli/curses_ui.zig
- [ ] Raw terminal mode select (reuse tui.zig RawMode)
- [ ] Arrow key navigation, Enter to select
- [ ] Test: struct/function exists

## 7. interface/cli/pairing.zig — DM pairing commands

**Python:** hermes_cli/pairing.py (97 lines) — manage DM pairing codes.
**Requirement:** List/approve/revoke DM pairing for gateway auth.
**Design:**
```zig
pub fn handlePairingCommand(allocator: Allocator, args: []const u8, stdout: std.fs.File) !void {
    // "list" → show pending + approved users
    // "approve {platform} {code}" → approve pairing
    // "revoke {platform} {user_id}" → revoke access
    // "clear-pending" → clear expired codes
}
```
**Tasks:**
- [ ] Create src/interface/cli/pairing.zig
- [ ] Parse subcommands
- [ ] list/approve/revoke/clear-pending handlers (stubs reading from config)
- [ ] Test: parse "approve telegram ABC123"
