# AGENTS.md — hermes-zig

Zig rewrite of [hermes-agent](https://github.com/nousresearch/hermes-agent) using zig-framework (vnext branch).

## Rules

Before writing any code, read the relevant documents:

- **Design Spec**: `docs/superpowers/specs/2026-04-01-hermes-zig-design.md` — architecture, interfaces, module design
- **Task Plan**: `docs/superpowers/plans/2026-04-01-hermes-zig-tasks.md` — all 19 sub-projects with task checklists
- **Logging**: Follow zig-framework logging guide — RequestTrace at entry points, MethodTrace for business methods, StepTrace for external calls
- **Original Source**: `/tmp/hermes-agent/` — Python reference implementation

## Interface Patterns

- **Runtime-determined types** (LLM providers, tools, platforms) → vtable (`*anyopaque` + `*const VTable`)
- **Compile-time-known variants** (terminal backends) → tagged union with exhaustive switch
- **Tool registration** → comptime `makeToolHandler` for static tools, runtime `registerDynamic` for MCP
- **Memory** → Arena allocator for LLM responses, explicit allocator passing everywhere

## Quick Reminders

- Use framework Logger, never `std.debug.print`
- SQLite via `@cImport("sqlite3.h")`, not a Zig wrapper
- JSON config with `std.json`, no YAML
- Each module has `root.zig` with `refAllDecls` test
- Tools must have `pub const SCHEMA: ToolSchema` and `pub fn execute(...)` — validated at comptime
- **Tests: NEVER hardcode `/tmp/` paths.** Use `:memory:` for SQLite, relative paths, or `std.testing.tmpDir()`. Must work on Linux, macOS, and Windows.
