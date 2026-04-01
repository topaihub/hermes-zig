# hermes-zig — Design Review & Corrections

## Review Summary

The initial design was too close to a Python-to-Zig translation. This document captures corrections based on the two Zig design documents (zig设计.md and zig特性设计.md) to ensure the implementation follows "Zig's way" rather than mechanically mapping Python modules.

## Correction 1: Module Structure — Fewer, Larger Modules

**Problem:** 15 top-level modules mirrors Python's directory structure. zig特性设计.md says: "把所有核心类型放在一个根模块，而不是拆成13个独立编译单元"

**Before (Python-style):**
```
src/core/ src/config/ src/state/ src/llm/ src/tools/ src/terminal/
src/agent/ src/cli/ src/gateway/ src/skills/ src/memory/ src/cron/
src/acp/ src/security/ src/trajectory/
```

**After (Zig-style, 7 domains):**
```
src/
├── core/           # "词汇表" — types, config, state, errors (everyone depends on it, it depends on nobody)
├── llm/            # LLM client abstraction (isolated change point)
├── tools/          # Tool system + terminal backends + MCP (tool domain)
├── agent/          # Agent loop + prompt + compression (core domain)
├── interface/      # CLI + Gateway + ACP (entry points — all adapters)
├── intelligence/   # Skills + Memory + Cron (learning & automation)
└── security/       # Approval, injection, path safety (cross-cutting)
```

**Rationale:** Zig's `@import` is file-level, not crate-level. Fewer top-level modules means simpler `build.zig`, clearer dependency direction, and less boilerplate `root.zig` files.

## Correction 2: Platform — Enum Now, Tagged Union Ready

**Problem:** Design used plain enum. zig特性设计.md says Platform should be tagged union for future metadata.

**Fix:** Keep enum for now (no metadata yet), but add `platform_metadata` to SessionSource:

```zig
pub const Platform = enum {
    telegram, discord, slack, whatsapp, signal, email, matrix,
    feishu, dingtalk, wecom, homeassistant, sms, mattermost, webhook, cli,

    pub fn displayName(self: Platform) []const u8 { ... }
};

pub const SessionSource = struct {
    platform: Platform,
    chat_id: []const u8,
    user_id: ?[]const u8 = null,
    thread_id: ?[]const u8 = null,
    platform_metadata: ?[]const u8 = null, // future: JSON blob for platform-specific data
};
```

When a platform needs metadata (e.g., Discord guild_id), upgrade Platform to tagged union without breaking SessionSource consumers.

## Correction 3: comptime Tool Validation is THE Core Pattern

**Problem:** `makeToolHandler` was mentioned but not emphasized as the foundational pattern.

**Fix:** Every built-in tool MUST use this pattern:

```zig
// This is the ONLY way to create a built-in tool.
// The comptime check ensures you can't forget SCHEMA or execute.
pub const BashTool = struct {
    pub const SCHEMA = ToolSchema{
        .name = "bash",
        .description = "Execute a bash command",
        .parameters_schema = \\{"type":"object","properties":{"command":{"type":"string"}},"required":["command"]}
    };

    pub fn execute(self: *BashTool, args: std.json.Value, ctx: *const ToolContext) anyerror![]const u8 {
        // ...
    }
};

// Registration: one line, zero boilerplate
var bash = BashTool{ .backend = &terminal_backend };
const handler = makeToolHandler(BashTool, &bash);
registry.registerStatic(handler);
```

If a struct is missing SCHEMA or execute, it fails at **compile time** — not at runtime like Python's missing method errors.

## Correction 4: Arena Allocator for LLM Responses is Mandatory

**Problem:** Arena pattern mentioned but not enforced in tasks.

**Fix:** CompletionResponse MUST own an ArenaAllocator:

```zig
pub const CompletionResponse = struct {
    content: ?[]const u8,
    tool_calls: ?[]ToolCall,
    usage: TokenUsage,
    arena: std.heap.ArenaAllocator,

    pub fn deinit(self: *CompletionResponse) void {
        self.arena.deinit(); // frees ALL strings, tool calls, everything — one call
    }
};
```

This is not optional. Every LLM client implementation must allocate response data from the arena. The caller calls `response.deinit()` once. No individual string frees. No memory leaks possible.

## Correction 5: Gateway Threading Model

**Problem:** Design didn't explicitly state the threading architecture.

**Fix:** Each PlatformAdapter runs in its own `std.Thread`:

```
Main Thread:  AgentLoop ← reads from MessageQueue
Thread 1:     TelegramAdapter → polls Telegram API → pushes to MessageQueue
Thread 2:     DiscordAdapter → WebSocket connection → pushes to MessageQueue
Thread 3:     SlackAdapter → HTTP events → pushes to MessageQueue
...
```

MessageQueue is the ONLY communication channel between platform threads and the agent thread. No shared mutable state except through the queue.

```zig
pub const MessageQueue = struct {
    mutex: std.Thread.Mutex = .{},
    cond: std.Thread.Condition = .{},
    items: std.ArrayList(IncomingMessage),
    closed: bool = false,

    pub fn push(self: *MessageQueue, msg: IncomingMessage) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.items.append(msg) catch return;
        self.cond.signal();
    }

    pub fn pop(self: *MessageQueue, timeout_ns: ?u64) ?IncomingMessage {
        self.mutex.lock();
        defer self.mutex.unlock();
        while (self.items.items.len == 0 and !self.closed) {
            if (timeout_ns) |t| {
                self.cond.timedWait(&self.mutex, t) catch return null;
            } else {
                self.cond.wait(&self.mutex);
            }
        }
        if (self.items.items.len == 0) return null;
        return self.items.orderedRemove(0);
    }
};
```

## Correction 6: ToolRegistry Dispatch Priority

**Problem:** Static-first dispatch not explicit enough.

**Fix:** Dispatch order is a hard rule:

```zig
pub fn dispatch(self: *ToolRegistry, name: []const u8, args: std.json.Value, ctx: *const ToolContext) anyerror![]const u8 {
    // 1. Static tools: NO LOCK, linear scan (fast for ~20 built-in tools)
    for (self.static) |handler| {
        if (std.mem.eql(u8, handler.schema.name, name)) return handler.execute(args, ctx);
    }
    // 2. Dynamic tools: READ LOCK, HashMap lookup (MCP tools)
    self.rwlock.lockShared();
    const handler = self.dynamic.get(name);
    self.rwlock.unlockShared();
    const h = handler orelse return error.ToolNotFound;
    return h.execute(args, ctx);
}
```

Static tools are ALWAYS checked first. This means built-in tools can never be shadowed by MCP tools with the same name — a security property.

## Revised Sub-Project Decomposition

| # | Sub-Project | Module | Description |
|---|-------------|--------|-------------|
| 1 | Project scaffold + core types | `core/` | build.zig, types, config, SQLite state |
| 2 | LLM client layer | `llm/` | LlmClient vtable, OpenAI-compat, Anthropic, SSE, Arena responses |
| 3 | Tool system + terminal backends | `tools/` | ToolHandler, makeToolHandler, Registry, TerminalBackend union, MCP |
| 4 | Built-in tools | `tools/builtin/` | 20+ tools using makeToolHandler pattern |
| 5 | Agent loop | `agent/` | Core loop, prompt builder, compressor, caching, credential pool |
| 6 | CLI interface | `interface/cli/` | TUI, slash commands, streaming display |
| 7 | Gateway core + platforms | `interface/gateway/` | PlatformAdapter vtable, MessageQueue, 14 platforms in threads |
| 8 | ACP adapter | `interface/acp/` | ACP protocol server |
| 9 | Skills + Memory + Cron | `intelligence/` | Skill system, persistent memory, cron scheduler |
| 10 | Security | `security/` | Approval, injection, path safety |
| 11 | Trajectory & RL | `agent/trajectory/` | Trajectory format, compression, batch runner |
| 12 | Integration & entry | `main.zig` | Wire everything, signal handling, graceful shutdown |

**Reduced from 19 to 12 sub-projects** by merging related modules.

## Revised Implementation Order

```
Phase 1 (Foundation):     SP-1 → SP-2 → SP-3
Phase 2 (Agent):          SP-4 → SP-5 → SP-6
Phase 3 (Interface):      SP-7 → SP-8
Phase 4 (Intelligence):   SP-9 → SP-10 → SP-11
Phase 5 (Ship):           SP-12
```
