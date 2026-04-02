# Design Review: hermes-zig vs nullclaw Patterns

## nullclaw Architecture (230K lines, 255 files, production Zig AI agent)

nullclaw is the reference implementation for how a Zig AI agent should be structured. Key patterns we should adopt:

---

## 1. Tool Interface: vtable functions, not stored fields

**nullclaw:**
```zig
pub const Tool = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    pub const VTable = struct {
        execute: *const fn (ptr: *anyopaque, allocator: Allocator, args: JsonObjectMap) anyerror!ToolResult,
        name: *const fn (ptr: *anyopaque) []const u8,
        description: *const fn (ptr: *anyopaque) []const u8,
        parameters_json: *const fn (ptr: *anyopaque) []const u8,
    };
};
```

**hermes-zig (current):**
```zig
pub const ToolHandler = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    schema: ToolSchema,  // ← stored as field, not vtable
};
```

**Issue:** Our design stores schema as a field on the vtable wrapper. nullclaw puts name/description/parameters_json as vtable functions. This is more flexible — a tool can dynamically change its schema.

**Action:** Keep our current design (schema as field is fine for static tools, and our comptime makeToolHandler pattern depends on it). But note: for MCP dynamic tools, we may need vtable-based schema.

---

## 2. Tool execute takes pre-parsed JSON, not raw string

**nullclaw:** `execute(allocator, args: JsonObjectMap)` — args already parsed
**hermes-zig:** `execute(args_json: []const u8, ctx: *ToolContext)` — raw JSON string

**Issue:** Our tools each parse JSON internally, duplicating parsing logic. nullclaw parses once in the dispatcher, passes pre-parsed map to tools.

**Action for all tool designs:** Update ToolHandler interface to take `std.json.ObjectMap` instead of `[]const u8`. Update all 50 tools. This is a breaking change but aligns with nullclaw's proven pattern.

**Revised interface:**
```zig
pub const ToolHandler = struct {
    pub const VTable = struct {
        execute: *const fn (ptr: *anyopaque, allocator: Allocator, args: std.json.ObjectMap) anyerror!ToolResult,
        // ...
    };
};
pub const ToolResult = struct {
    output: []const u8,
    is_error: bool = false,
};
```

---

## 3. Channel (Gateway) has rich vtable with streaming

**nullclaw Channel vtable includes:**
- send (with attachments, choices, streaming stages)
- edit_message
- send_typing
- format_message
- get_display_name
- supports_streaming

**hermes-zig PlatformAdapter vtable:**
- platform, connect, send, setMessageHandler, deinit (minimal)

**Action:** Enrich PlatformAdapter vtable for real implementations:
```zig
pub const VTable = struct {
    platform: ...,
    connect: ...,
    send: ...,
    edit_message: ?*const fn (...) anyerror!void = null,
    send_typing: ?*const fn (...) anyerror!void = null,
    send_image: ?*const fn (...) anyerror!void = null,
    send_document: ?*const fn (...) anyerror!void = null,
    format_message: ?*const fn (...) []const u8 = null,
    supports_streaming: *const fn (...) bool,
    deinit: ...,
};
```

---

## 4. Memory has vtable interface with multiple backends

**nullclaw:**
```zig
// Memory vtable: store, recall, get, list, forget, count
// Backends: SQLite (FTS5), Markdown (file-based), None (no-op)
// Selected at runtime via config
```

**hermes-zig:** Memory is file-based only (MEMORY.md read/write).

**Action:** Add Memory vtable interface:
```zig
pub const Memory = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    pub const VTable = struct {
        store: *const fn (...) anyerror!void,
        recall: *const fn (...) anyerror![]MemoryEntry,
        forget: *const fn (...) anyerror!void,
        count: *const fn (...) anyerror!u64,
    };
};
// Backends: SqliteMemory, MarkdownMemory, NoneMemory
```

---

## 5. Security is comprehensive

**nullclaw security/ (13 files):**
- audit.zig — audit trail
- bubblewrap.zig — bubblewrap sandbox
- docker.zig — docker sandbox
- firejail.zig — firejail sandbox
- landlock.zig — Linux landlock
- sandbox.zig — sandbox orchestration
- secrets.zig — secret detection/redaction
- policy.zig — autonomy levels (full, supervised, restricted)
- pairing.zig — DM pairing
- tracker.zig — action tracking
- detect.zig — threat detection

**hermes-zig security/ (5 files):** approval, injection, path_safety, env_filter, scanner

**Action:** Add to security designs:
- Autonomy levels (full/supervised/restricted) — controls what tools can do without approval
- Sandbox support (at least document the interface for future bubblewrap/docker/firejail)
- Audit trail — log all tool executions for review
- Secret detection in tool outputs (not just inputs)

---

## 6. Provider is per-module, not vtable

**nullclaw:** Each provider (anthropic.zig, openai.zig, gemini.zig) is a separate module with its own types. A `factory.zig` creates the right one from config. No shared vtable — each provider has different capabilities.

**hermes-zig:** LlmClient vtable with complete/completeStream.

**Assessment:** Our vtable approach is fine for hermes-zig's use case (simpler than nullclaw). nullclaw's approach gives more flexibility for provider-specific features but adds complexity.

**Action:** Keep our LlmClient vtable but add provider-specific extensions where needed (e.g., Anthropic cache_control).

---

## 7. Bootstrap/Config pattern

**nullclaw:** Has a `bootstrap/` module with provider pattern — config can come from file, memory, or null (testing). Clean separation of config loading from config usage.

**Action:** Our config loading is adequate but should add:
- Config validation (check required fields)
- Config migration (handle old format gracefully)

---

## Summary of Design Changes Needed

| Area | Change | Priority |
|------|--------|----------|
| Tool execute signature | Change from `[]const u8` to `std.json.ObjectMap` | HIGH |
| Tool result type | Add `ToolResult` struct with output + is_error | HIGH |
| Channel vtable | Add edit_message, send_typing, send_image, supports_streaming | MEDIUM |
| Memory vtable | Add Memory interface with SQLite/Markdown/None backends | MEDIUM |
| Security | Add autonomy levels, audit trail, sandbox interface | MEDIUM |
| Provider | Keep vtable, add Anthropic-specific extensions | LOW |
| Config | Add validation, migration | LOW |

These changes should be applied BEFORE implementing the 76 remaining tasks, as they affect the interfaces that all tools/channels/memory implementations depend on.
