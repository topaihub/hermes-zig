# Group A Redesign — Zig-Native, Not Python Translation

## Self-Review Findings

The original Group A design was a 1:1 Python file → Zig file translation. This violates the core principle from zig特性设计.md: "先理解原文的设计意图，再问 Zig 会怎么做".

### What Python's 47 tool files actually represent

Analyzing the Python tools by **design intent** (not file count):

| Intent | Python Files | Zig Approach |
|--------|-------------|-------------|
| User-facing tools (LLM can invoke) | ~20 | ToolHandler comptime structs |
| Internal infra (not user-facing) | ~12 | Module functions, not tools |
| Security checks (auto-applied) | ~5 | security/ module hooks |
| Utility functions | ~10 | Inline in consuming modules |

### Reclassification

**Actually user-facing tools (LLM invokes these):**
1. checkpoint (create/rollback snapshots)
2. session_search (search past conversations)
3. skills (list/view/create/manage skills — merge 4 Python files)
4. homeassistant (smart home control)
5. process (background process management)
6. mixture_of_agents (multi-model — stub)

**NOT tools, should be module functions:**
- tirith_security → security/scanner.zig (pre-exec hook)
- url_safety → security/url.zig (called by browser/web tools internally)
- website_policy → security/policy.zig (called by browser/web tools internally)
- credential_files → tools/terminal/credentials.zig (terminal backend infra)
- process_registry → tools/terminal/process_pool.zig (terminal backend infra)
- skills_guard → intelligence/skills_guard.zig (already exists)
- skills_hub, skills_sync → intelligence/ (already exists as module)
- honcho_tools → intelligence/honcho.zig (memory module function)
- ansi_strip → tools/util.zig (utility function)
- patch_parser → tools/util.zig (utility function)
- fuzzy_match → tools/util.zig (utility function)
- debug_helpers → not needed (use framework Logger)
- env_passthrough → tools/terminal/env.zig (terminal infra)
- openrouter_client → not needed (covered by llm/openai_compat.zig)
- interrupt → agent/loop.zig (already has interrupt flag)
- registry → not needed (we have tools/registry.zig)
- browser_camofox, browser_camofox_state → tools/builtin/browser.zig (extend existing)
- neutts_synth → tools/builtin/tts.zig (extend existing)
- mcp_oauth → tools/mcp/oauth.zig (extend existing)
- rl_training → agent/trajectory/ (extend existing)

---

## Revised Design

### New user-facing tools to create (6 files, not 19)

#### 1. checkpoint.zig — Workspace Snapshots

**Intent:** Protect user's files from agent mistakes. Auto-snapshot before mutations, manual rollback.

**Zig design:** Use `std.process.Child` to run git commands. NOT a separate git library — git is universally available and this is the simplest approach.

```zig
pub const CheckpointTool = struct {
    working_dir: []const u8,

    pub const SCHEMA = ToolSchema{
        .name = "checkpoint",
        .description = "Manage workspace checkpoints. Creates automatic snapshots before file changes. Supports rollback.",
        .parameters_schema = \\{"type":"object","properties":{"action":{"type":"string","enum":["create","list","rollback","diff"]},"id":{"type":"string"}},"required":["action"]}
    };

    pub fn execute(self: *CheckpointTool, args_json: []const u8, ctx: *const ToolContext) anyerror![]const u8 {
        // Shell out to git in shadow repo
    }
};
```

#### 2. session_search.zig — Long-Term Recall

**Intent:** Agent can search its own past conversations. This is what makes hermes "self-improving".

**Zig design:** Direct SQLite FTS5 query (no HTTP, no external service). Uses existing core/search.zig.

```zig
pub const SessionSearchTool = struct {
    db: *core_sqlite.Database,

    pub const SCHEMA = ToolSchema{
        .name = "session_search",
        .description = "Search past conversations for relevant context. Your long-term memory.",
        .parameters_schema = \\{"type":"object","properties":{"query":{"type":"string"},"limit":{"type":"integer"}},"required":["query"]}
    };
};
```

#### 3. skills.zig — Unified Skill Management

**Intent:** Python has 4 separate files (skills_tool, skill_manager, skills_hub, skills_sync). In Zig, this is ONE tool with action parameter. The skill system is a single domain.

**Zig design:** Tagged union for action, dispatch internally.

```zig
pub const SkillsTool = struct {
    skills_dirs: []const []const u8,
    hub_url: []const u8 = "https://agentskills.io",

    pub const SCHEMA = ToolSchema{
        .name = "skills",
        .description = "Manage skills — list, view, create, install from hub, sync.",
        .parameters_schema = \\{"type":"object","properties":{"action":{"type":"string","enum":["list","view","create","update","delete","search_hub","install","sync"]},"name":{"type":"string"},"content":{"type":"string"},"query":{"type":"string"}},"required":["action"]}
    };

    pub fn execute(self: *SkillsTool, args_json: []const u8, ctx: *const ToolContext) anyerror![]const u8 {
        // Parse action, dispatch to internal functions
        // list/view → scan dirs, read SKILL.md
        // create/update/delete → file I/O
        // search_hub/install → HTTP to agentskills.io
        // sync → compare local vs remote
    }
};
```

This is more Zig-like: one type, one responsibility (skill domain), exhaustive action handling.

#### 4. homeassistant.zig — Smart Home

**Intent:** Control IoT devices. Python has 3 tools (list, get_state, call_service). Zig: one tool.

```zig
pub const HomeAssistantTool = struct {
    ha_url: []const u8,
    token: []const u8,

    pub const SCHEMA = ToolSchema{
        .name = "homeassistant",
        .description = "Control Home Assistant devices — list entities, get state, call services.",
        .parameters_schema = \\{"type":"object","properties":{"action":{"type":"string","enum":["list","state","call"]},"entity_id":{"type":"string"},"service":{"type":"string"},"data":{"type":"string"}},"required":["action"]}
    };
};
```

#### 5. process.zig — Background Process Management

**Intent:** Track and interact with background processes.

**Zig design:** This tool wraps a ProcessPool (new infra in tools/terminal/). The pool is the infra, the tool is the user interface.

```zig
pub const ProcessTool = struct {
    pool: *ProcessPool,

    pub const SCHEMA = ToolSchema{
        .name = "process",
        .description = "Manage background processes — list, poll output, kill.",
        .parameters_schema = \\{"type":"object","properties":{"action":{"type":"string","enum":["list","poll","log","kill"]},"session_id":{"type":"string"}},"required":["action"]}
    };
};
```

#### 6. mixture_of_agents.zig — Multi-Model (stub)

Stub for v1. Real implementation needs architectural support for multiple LlmClient instances.

### New infra modules (not tools, module functions)

#### tools/terminal/process_pool.zig

```zig
pub const ProcessPool = struct {
    processes: std.StringHashMap(ProcessInfo),
    allocator: std.mem.Allocator,

    pub fn spawn(self: *ProcessPool, cmd: []const u8, cwd: []const u8) ![]const u8  // returns session_id
    pub fn poll(self: *ProcessPool, id: []const u8) !?ProcessStatus
    pub fn getOutput(self: *ProcessPool, id: []const u8) ![]const u8
    pub fn kill(self: *ProcessPool, id: []const u8) !void
};
```

#### tools/terminal/credentials.zig

```zig
pub fn loadCredentialFile(allocator: std.mem.Allocator, name: []const u8) ![]u8
pub fn listCredentials(allocator: std.mem.Allocator) ![][]const u8
```

#### tools/terminal/env.zig

```zig
pub fn buildToolEnv(base_env: []const EnvVar, passthrough: []const []const u8) []EnvVar
```

#### tools/util.zig — Consolidated utilities

```zig
pub fn stripAnsi(input: []const u8) []const u8  // remove ESC[ sequences
pub fn fuzzyMatch(query: []const u8, candidate: []const u8) f32  // 0.0-1.0 score
pub fn parsePatch(diff: []const u8) ![]Hunk  // unified diff parsing
```

#### security/ enhancements (not tools)

```zig
// security/scanner.zig — pre-exec hook, called automatically before tool execution
pub fn preExecScan(command: []const u8) !ScanResult {
    // Check dangerous patterns (rm -rf, chmod 777, curl|bash, etc.)
    // Check URL safety for network commands
    // Check website policy for browser commands
}

// security/url.zig
pub fn isPrivateAddress(host: []const u8) bool
pub fn checkUrlSafety(url: []const u8) !UrlSafetyResult

// security/policy.zig
pub fn checkWebsitePolicy(url: []const u8, policy: []const PolicyRule) bool
```

#### intelligence/ enhancements

```zig
// intelligence/honcho.zig — Honcho API client
pub const HonchoClient = struct {
    base_url: []const u8,
    api_key: []const u8,
    pub fn getUserContext(self: *HonchoClient, user_id: []const u8) ![]u8
    pub fn updateUserModel(self: *HonchoClient, user_id: []const u8, data: []const u8) !void
};

// intelligence/skills_executor.zig — inject skill into prompt (update existing)
pub fn injectSkill(allocator: std.mem.Allocator, system_prompt: []const u8, skill_body: []const u8) ![]u8
```

---

## Summary: 51 items → 6 tools + 8 module enhancements

| Category | Python files | Zig approach | Count |
|----------|-------------|-------------|-------|
| New user tools | 19 Python files | 6 Zig tool structs | 6 |
| Terminal infra | 3 Python files | 3 Zig module files | 3 |
| Security hooks | 3 Python files | 3 functions in security/ | 3 |
| Intelligence | 5 Python files | 2 Zig module files | 2 |
| Utilities | 8 Python files | 1 consolidated util.zig | 1 |
| Agent enhancements | 10 features | Modifications to existing files | 10 |
| CLI enhancements | 6 features | 4 new + 2 modifications | 6 |
| Gateway additions | 3 items | 3 Zig files | 3 |
| Already covered | ~10 Python files | Existing Zig code | 0 |

**Total new files: ~22 (not 51)**

This is the Zig way: fewer files, each with clear responsibility, leveraging comptime and module-level functions instead of creating a class for everything.
