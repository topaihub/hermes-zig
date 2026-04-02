# Interface Refactoring Tasks (Pre-requisite for Phase 1-5)

> These tasks MUST be completed BEFORE any Phase 1-5 work, because they change the core interfaces that all implementations depend on.
> Based on nullclaw review (2026-04-03-nullclaw-review.md).

---

## Task R1: Refactor ToolHandler — JsonObjectMap + ToolResult

**Current:**
```zig
execute: *const fn (ptr: *anyopaque, args_json: []const u8, ctx: *const ToolContext) anyerror![]const u8
```

**New (nullclaw pattern):**
```zig
pub const ToolResult = struct {
    output: []const u8,
    is_error: bool = false,
    allocator: std.mem.Allocator,
    pub fn deinit(self: *ToolResult) void { self.allocator.free(self.output); }
};

execute: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult
```

**Why:** Pre-parsed args eliminates duplicate JSON parsing in every tool. ToolResult distinguishes tool errors from system errors.

**Files to change:**
- [ ] src/tools/interface.zig — change ToolHandler.VTable.execute signature, add ToolResult, add JSON helper functions (getString, getBool, getInt from nullclaw pattern)
- [ ] src/tools/interface.zig — update makeToolHandler comptime to match new signature
- [ ] src/tools/registry.zig — parse JSON once in dispatch(), pass ObjectMap to tool
- [ ] src/tools/builtin/*.zig — update ALL 28 tool files: change execute signature, remove internal JSON parsing, use helper functions
- [ ] src/api handlers — update any code that calls tool.execute
- [ ] Tests: verify all tools compile with new signature

**JSON helper functions (from nullclaw):**
```zig
pub fn getString(args: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    const val = args.get(key) orelse return null;
    return switch (val) { .string => |s| s, else => null };
}
pub fn getBool(args: std.json.ObjectMap, key: []const u8) ?bool {
    const val = args.get(key) orelse return null;
    return switch (val) { .bool => |b| b, else => null };
}
pub fn getInt(args: std.json.ObjectMap, key: []const u8) ?i64 {
    const val = args.get(key) orelse return null;
    return switch (val) { .integer => |i| i, else => null };
}
```

---

## Task R2: Enrich PlatformAdapter vtable

**Current:**
```zig
pub const VTable = struct {
    platform: ..., connect: ..., send: ..., set_message_handler: ..., deinit: ...
};
```

**New (nullclaw Channel pattern):**
```zig
pub const VTable = struct {
    platform: *const fn (ptr: *anyopaque) Platform,
    connect: *const fn (ptr: *anyopaque) anyerror!void,
    disconnect: *const fn (ptr: *anyopaque) void,
    send: *const fn (ptr: *anyopaque, allocator: Allocator, target: []const u8, content: []const u8, reply_to: ?[]const u8) anyerror!SendResult,
    edit_message: ?*const fn (ptr: *anyopaque, allocator: Allocator, target: []const u8, message_id: []const u8, content: []const u8) anyerror!void = null,
    send_typing: ?*const fn (ptr: *anyopaque, target: []const u8) anyerror!void = null,
    send_image: ?*const fn (ptr: *anyopaque, allocator: Allocator, target: []const u8, image_path: []const u8, caption: ?[]const u8) anyerror!SendResult = null,
    send_document: ?*const fn (ptr: *anyopaque, allocator: Allocator, target: []const u8, doc_path: []const u8, caption: ?[]const u8) anyerror!SendResult = null,
    supports_streaming: *const fn (ptr: *anyopaque) bool,
    format_message: ?*const fn (ptr: *anyopaque, content: []const u8) []const u8 = null,
    set_message_handler: *const fn (ptr: *anyopaque, handler: MessageHandler) void,
    deinit: *const fn (ptr: *anyopaque) void,
};
```

**Files to change:**
- [ ] src/interface/gateway/platform.zig — update VTable, add convenience methods on PlatformAdapter
- [ ] src/interface/gateway/platforms/*.zig — update all 16 adapters to include new vtable fields (null for unimplemented)
- [ ] Tests: verify all adapters compile

---

## Task R3: Add Memory vtable interface

**New module (nullclaw pattern):**

```zig
// src/intelligence/memory_interface.zig
pub const MemoryEntry = struct {
    key: []const u8,
    content: []const u8,
    category: []const u8 = "general",
    timestamp: i64 = 0,
};

pub const Memory = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        store: *const fn (ptr: *anyopaque, allocator: Allocator, key: []const u8, content: []const u8, category: []const u8) anyerror!void,
        recall: *const fn (ptr: *anyopaque, allocator: Allocator, query: []const u8, limit: u32) anyerror![]MemoryEntry,
        get: *const fn (ptr: *anyopaque, allocator: Allocator, key: []const u8) anyerror!?MemoryEntry,
        forget: *const fn (ptr: *anyopaque, allocator: Allocator, key: []const u8) anyerror!void,
        count: *const fn (ptr: *anyopaque) anyerror!u64,
        deinit: *const fn (ptr: *anyopaque) void,
    };
};

// Backends:
// SqliteMemory — uses core/sqlite.zig with FTS5
// MarkdownMemory — reads/writes MEMORY.md file
// NoneMemory — no-op (for testing or disabled memory)
```

**Files to create/change:**
- [ ] Create src/intelligence/memory_interface.zig with Memory vtable + MemoryEntry
- [ ] Create src/intelligence/memory_sqlite.zig implementing Memory via SQLite FTS5
- [ ] Create src/intelligence/memory_markdown.zig implementing Memory via MEMORY.md file
- [ ] Create src/intelligence/memory_none.zig — no-op implementation
- [ ] Update src/intelligence/root.zig exports
- [ ] Update memory_tool.zig to use Memory vtable instead of direct file I/O
- [ ] Tests: each backend stores + recalls

---

## Task R4: Add Security autonomy levels + audit

**New (nullclaw pattern):**

```zig
// src/security/policy.zig
pub const AutonomyLevel = enum {
    full,        // all tools auto-approved
    supervised,  // dangerous tools need approval, safe tools auto-approved
    restricted,  // all tools need approval

    pub fn requiresApproval(self: AutonomyLevel, tool_name: []const u8) bool {
        return switch (self) {
            .full => false,
            .restricted => true,
            .supervised => isDangerousTool(tool_name),
        };
    }
};

fn isDangerousTool(name: []const u8) bool {
    const dangerous = [_][]const u8{ "terminal", "write_file", "patch", "execute_code", "delegate_task" };
    for (dangerous) |d| { if (std.mem.eql(u8, name, d)) return true; }
    return false;
}

// src/security/audit.zig
pub const AuditEntry = struct {
    timestamp: i64,
    tool_name: []const u8,
    args_summary: []const u8,
    result_summary: []const u8,
    approved: bool,
};

pub const AuditTrail = struct {
    entries: std.ArrayListUnmanaged(AuditEntry) = .empty,
    pub fn log(self: *AuditTrail, allocator: Allocator, entry: AuditEntry) !void
    pub fn recent(self: *AuditTrail, limit: u32) []const AuditEntry
};
```

**Files to create/change:**
- [ ] Create src/security/policy.zig with AutonomyLevel enum
- [ ] Create src/security/audit.zig with AuditTrail
- [ ] Update src/security/root.zig exports
- [ ] Update agent/loop.zig: before tool execution, check autonomy level, log to audit trail
- [ ] Add autonomy_level to Config: `security: { autonomy: "supervised" }`
- [ ] Tests: autonomy level checks, audit logging

---

## Task R5: Update all Phase 1-5 tasks to use new interfaces

After R1-R4 are done, update the task descriptions:

- [ ] All tool tasks (P2.1-P2.12, P4.7-P4.10): use `std.json.ObjectMap` args + `ToolResult` return
- [ ] All gateway tasks (P4.11-P4.15): use enriched PlatformAdapter vtable
- [ ] All memory tasks (P1.10, P2.2, P5.8-P5.10): use Memory vtable
- [ ] All security-related tasks: respect AutonomyLevel, log to AuditTrail

---

## Execution Order

```
R1 (Tool interface refactor)     — FIRST, breaks all tools
R2 (Channel vtable enrich)       — can parallel with R1
R3 (Memory vtable)               — can parallel with R1
R4 (Security autonomy + audit)   — can parallel with R1
R5 (Update task descriptions)    — after R1-R4

Then proceed to Phase 1 → Phase 5
```
