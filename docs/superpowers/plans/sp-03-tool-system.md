# SP-3: Tool System + Terminal Backends — Detailed Implementation Plan

> **For agentic workers:** Read Python files: tools/registry.py, tools/__init__.py, toolsets.py, tools/environments/*.py, tools/mcp_tool.py

**Goal:** ToolHandler vtable with comptime validation, ToolRegistry (static+dynamic), TerminalBackend tagged union, MCP client.

**CRITICAL:** `makeToolHandler` comptime pattern is the foundation. Every built-in tool in SP-4 depends on it.

---

## Task 1: Tool Interface + comptime Validation

**Files:** src/tools/root.zig, src/tools/interface.zig

- [ ] Define ToolSchema: name, description, parameters_schema (JSON string)
- [ ] Define ToolContext: session (SessionSource), working_dir, allocator, platform
- [ ] Define ToolHandler vtable: execute (*const fn(ptr, args: std.json.Value, ctx: *const ToolContext) anyerror![]const u8), deinit, schema (stored directly, not via vtable)
- [ ] **CRITICAL:** Implement `validateToolImpl(comptime T: type)`:
  ```zig
  pub fn validateToolImpl(comptime T: type) void {
      comptime {
          if (!@hasDecl(T, "SCHEMA")) @compileError(@typeName(T) ++ " must have pub const SCHEMA: ToolSchema");
          if (!@hasDecl(T, "execute")) @compileError(@typeName(T) ++ " must have pub fn execute(...)");
      }
  }
  ```
- [ ] **CRITICAL:** Implement `makeToolHandler(comptime T: type, instance: *T) ToolHandler` — auto-generate vtable from struct
- [ ] Tests: verify comptime validation works (good struct compiles, bad struct would fail)
- [ ] Commit: `feat(tools): add ToolHandler interface with comptime validation`

## Task 2: Tool Registry

**Files:** src/tools/registry.zig

- [ ] ToolRegistry struct: static ([]const ToolHandler — comptime, no lock), dynamic (StringHashMap(ToolHandler) + RwLock)
- [ ] `init(allocator, comptime builtin_tools: []const ToolHandler)` — static from comptime param
- [ ] `registerDynamic(handler)` — write lock, dupe name, put in map
- [ ] `dispatch(name, args, ctx) ![]const u8` — **static first (no lock), then dynamic (read lock)**. Security: built-ins can't be shadowed.
- [ ] `collectSchemas(allocator) ![]ToolSchema` — gather all schemas for LLM prompt
- [ ] `deinit()` — free dynamic entries
- [ ] Tests: register static + dynamic, dispatch priority, collectSchemas
- [ ] Commit: `feat(tools): add ToolRegistry with static/dynamic split`

## Task 3: Toolsets

**Files:** src/tools/toolsets.zig

- [ ] Define toolset presets as string arrays:
  - default: bash, file_read, file_write, file_edit, file_tools, web_search, todo, memory
  - coding: default + code_execution + delegate
  - research: default + web_search + browser + vision
  - creative: default + image_gen + tts + voice_mode
  - all: every tool
- [ ] `resolveToolset(name) []const []const u8` — return tool names for a preset
- [ ] Tests: resolve each preset
- [ ] Commit: `feat(tools): add toolset presets`

## Task 4: Terminal Backend (Tagged Union)

**Files:** src/tools/terminal/root.zig, backend.zig, local.zig, docker.zig, ssh.zig, daytona.zig, singularity.zig, modal.zig

- [ ] Define ExecResult: stdout, stderr, exit_code, allocator, `deinit()`, `isSuccess()`
- [ ] Define TerminalBackend tagged union:
  ```zig
  pub const TerminalBackend = union(enum) {
      local: LocalBackend,
      docker: DockerBackend,
      ssh: SshBackend,
      daytona: DaytonaBackend,
      singularity: SingularityBackend,
      modal: ModalBackend,
      pub fn execute(self, allocator, cmd, cwd, timeout_ms) !ExecResult { switch exhaustive }
      pub fn cleanup(self) !void { switch exhaustive }
  };
  ```
- [ ] LocalBackend: std.process.Child, pipe stdout/stderr, wait with timeout
- [ ] DockerBackend: `docker exec {container} sh -c {cmd}` via ProcessRunner
- [ ] SshBackend: `ssh {user}@{host} -p {port} {cmd}` via ProcessRunner
- [ ] DaytonaBackend: HTTP POST to Daytona API via HttpClient
- [ ] SingularityBackend: `singularity exec {image} sh -c {cmd}` via ProcessRunner
- [ ] ModalBackend: HTTP POST to Modal API via HttpClient
- [ ] `fromConfig(allocator, config) !TerminalBackend` — factory from TerminalConfig
- [ ] Tests: LocalBackend execute `echo hello`, verify stdout
- [ ] Commit: `feat(tools): add TerminalBackend tagged union with 6 backends`

## Task 5: MCP Client

**Files:** src/tools/mcp/root.zig, client.zig, discovery.zig, server.zig

- [ ] MCP client stdio transport: spawn process, write JSON-RPC to stdin, read from stdout
- [ ] Implement initialize handshake, tools/list, tools/call
- [ ] discovery.zig: call tools/list → for each tool, create ToolHandler wrapper → registerDynamic
- [ ] server.zig: expose hermes tools as MCP server (JSON-RPC over stdin/stdout)
- [ ] Tests: mock MCP server process, verify tool discovery
- [ ] Commit: `feat(tools): add MCP client with dynamic tool discovery`
