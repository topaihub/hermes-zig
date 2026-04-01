# Group A: Missing Tools — Detailed Design

## Architecture Impact Analysis

### 1. No new interfaces needed
All 19 tools use existing `makeToolHandler` comptime pattern. No changes to ToolHandler vtable or ToolRegistry.

### 2. New dependencies required by some tools

| Tool | Needs | From |
|------|-------|------|
| checkpoint_manager | ProcessRunner (git commands) | framework.effects |
| session_search | Database (FTS5 query) | core/search.zig |
| skills_tool, skill_manager | FileSystem (read/write SKILL.md) | std.fs |
| skills_hub, skills_sync | HttpClient (agentskills.io API) | framework.effects |
| honcho_tools | HttpClient (Honcho API) | framework.effects |
| homeassistant_tool | HttpClient (HA REST API) | framework.effects |
| process_registry | ProcessRunner + in-memory state | framework.effects + HashMap |
| mixture_of_agents | LlmClient (multiple calls) | llm/interface.zig |
| tirith_security | FileSystem (check file permissions) | std.fs + std.posix |
| url_safety | Network address parsing | std.net |

### 3. Tools that need references to other modules

Some tools need access to shared state (database, LLM client, etc.). In Python these are passed via `**kwargs`. In Zig, we inject them as struct fields:

```zig
pub const SessionSearchTool = struct {
    db: *core_database.Database,  // injected at init
    pub const SCHEMA = ...;
    pub fn execute(self: *SessionSearchTool, args_json: []const u8, ctx: *const ToolContext) anyerror![]const u8 {
        // use self.db to query
    }
};
```

This is consistent with how BashTool already has a `backend: *TerminalBackend` field.

### 4. Toolset membership

Python tools belong to toolsets. Our toolsets.zig already defines presets. New tools map to:

| Tool | Toolset |
|------|---------|
| checkpoint_manager | default |
| session_search | session_search |
| skills_tool, skill_manager, skills_hub, skills_sync | skills |
| honcho_tools | memory |
| homeassistant_tool | homeassistant |
| process_registry | terminal |
| mixture_of_agents | research |
| tirith_security, url_safety, website_policy | security (not user-invoked, auto-applied) |
| credential_files | terminal |
| browser_camofox* | browser |
| neutts_synth | voice |
| rl_training | research |
| mcp_oauth | mcp |

---

## Tool Designs (each with interface contract)

### A1. CheckpointManagerTool

**Purpose:** Filesystem snapshots via shadow git repo.

```zig
pub const CheckpointManagerTool = struct {
    working_dir: []const u8,

    pub const SCHEMA = ToolSchema{
        .name = "checkpoint",
        .description = "Create, list, or rollback filesystem checkpoints. Auto-creates before file mutations.",
        .parameters_schema =
            \\{"type":"object","properties":{"action":{"type":"string","enum":["create","list","rollback","diff"],"description":"Action to perform"},"checkpoint_id":{"type":"string","description":"Checkpoint ID for rollback/diff"}},"required":["action"]}
    };

    pub fn execute(self: *CheckpointManagerTool, args_json: []const u8, ctx: *const ToolContext) anyerror![]const u8 {
        // create: git -C {working_dir}/.hermes-checkpoints add -A && git commit -m "checkpoint"
        // list: git -C ... log --oneline
        // rollback: git -C ... checkout {id} -- .
        // diff: git -C ... diff {id}
    }
};
```

**Implementation:** Shell out to git via `std.process.Child`. Shadow repo at `{working_dir}/.hermes-checkpoints/`.

### A2. SessionSearchTool

**Purpose:** Search past conversations via FTS5.

```zig
pub const SessionSearchTool = struct {
    db: *core_sqlite.Database,

    pub const SCHEMA = ToolSchema{
        .name = "session_search",
        .description = "Search your long-term memory of past conversations. Returns summarized results from matching sessions.",
        .parameters_schema =
            \\{"type":"object","properties":{"query":{"type":"string","description":"Search query"},"limit":{"type":"integer","description":"Max results (default 3)"}},"required":["query"]}
    };

    pub fn execute(self: *SessionSearchTool, args_json: []const u8, ctx: *const ToolContext) anyerror![]const u8 {
        // Parse query from args
        // Call core_search.searchMessages(self.db, query)
        // Format results as readable text
    }
};
```

### A3. SkillsTool

**Purpose:** List and view skill documents.

```zig
pub const SkillsTool = struct {
    skills_dirs: []const []const u8,  // directories to scan

    pub const SCHEMA = ToolSchema{
        .name = "skills",
        .description = "List available skills or view a specific skill's instructions.",
        .parameters_schema =
            \\{"type":"object","properties":{"action":{"type":"string","enum":["list","view"],"description":"Action"},"skill_name":{"type":"string","description":"Skill name for view action"}},"required":["action"]}
    };
};
```

### A4. SkillManagerTool

```zig
pub const SkillManagerTool = struct {
    skills_dir: []const u8,  // ~/.hermes/skills/

    pub const SCHEMA = ToolSchema{
        .name = "skill_manager",
        .description = "Create, update, or delete skills. Turns successful approaches into reusable procedural knowledge.",
        .parameters_schema =
            \\{"type":"object","properties":{"action":{"type":"string","enum":["create","update","delete"],"description":"Action"},"name":{"type":"string","description":"Skill name"},"content":{"type":"string","description":"SKILL.md content for create/update"}},"required":["action","name"]}
    };
};
```

### A5. SkillsHubTool

```zig
pub const SkillsHubTool = struct {
    hub_url: []const u8 = "https://agentskills.io",

    pub const SCHEMA = ToolSchema{
        .name = "skills_hub",
        .description = "Browse and install skills from the Skills Hub marketplace.",
        .parameters_schema =
            \\{"type":"object","properties":{"action":{"type":"string","enum":["search","install","uninstall"],"description":"Action"},"query":{"type":"string","description":"Search query"},"skill_id":{"type":"string","description":"Skill ID for install/uninstall"}},"required":["action"]}
    };
};
```

### A6-A7. SkillsSyncTool, HonchoTool

Same pattern: struct with config fields, SCHEMA, execute that makes HTTP calls.

### A8. HomeAssistantTool

**Note:** Python has 3 separate HA tools (list_entities, get_state, call_service). In Zig, combine into one tool with action parameter:

```zig
pub const HomeAssistantTool = struct {
    ha_url: []const u8,
    token: []const u8,

    pub const SCHEMA = ToolSchema{
        .name = "homeassistant",
        .description = "Control Home Assistant smart home devices. List entities, get state, or call services.",
        .parameters_schema =
            \\{"type":"object","properties":{"action":{"type":"string","enum":["list_entities","get_state","call_service"],"description":"Action"},"entity_id":{"type":"string","description":"Entity ID"},"domain":{"type":"string","description":"Filter domain for list"},"service":{"type":"string","description":"Service to call"},"data":{"type":"string","description":"JSON data for service call"}},"required":["action"]}
    };
};
```

### A9. ProcessRegistryTool

**Key design decision:** In-memory state. Python uses a module-level dict. In Zig, use a struct field with HashMap:

```zig
pub const ProcessRegistryTool = struct {
    processes: std.StringHashMap(ProcessInfo),
    allocator: std.mem.Allocator,

    pub const ProcessInfo = struct {
        id: []const u8,
        command: []const u8,
        status: enum { running, exited },
        exit_code: ?i32 = null,
        stdout_buffer: std.ArrayListUnmanaged(u8) = .{},
    };

    pub const SCHEMA = ToolSchema{
        .name = "process",
        .description = "Manage background processes. Actions: list, poll, log, wait, kill.",
        .parameters_schema =
            \\{"type":"object","properties":{"action":{"type":"string","enum":["list","poll","log","wait","kill"],"description":"Action"},"session_id":{"type":"string","description":"Process session ID"}},"required":["action"]}
    };
};
```

### A10. MixtureOfAgentsTool

**Design:** Stub for v1. Real implementation needs multiple LlmClient instances.

### A11. TirithSecurityTool

```zig
pub const TirithSecurityTool = struct {
    pub const SCHEMA = ToolSchema{
        .name = "security_scan",
        .description = "Deep security scan of a command before execution.",
        .parameters_schema =
            \\{"type":"object","properties":{"command":{"type":"string","description":"Command to scan"}},"required":["command"]}
    };

    // Patterns: rm -rf /, chmod 777, curl|bash, wget|sh, dd if=, mkfs, :(){ :|:& };:
    // Also check: file permission changes, network exfiltration, credential access
};
```

### A12. UrlSafetyTool

```zig
pub const UrlSafetyTool = struct {
    pub const SCHEMA = ToolSchema{
        .name = "url_safety",
        .description = "Check if a URL is safe to access (blocks private/internal addresses).",
        .parameters_schema =
            \\{"type":"object","properties":{"url":{"type":"string","description":"URL to check"}},"required":["url"]}
    };

    // Check: 127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, ::1, 169.254.0.0/16
    // Parse URL → extract host → resolve to IP → check ranges
};
```

### A13-A19. Remaining tools

All follow the same pattern. browser_camofox, browser_camofox_state, neutts_synth, rl_training, mcp_oauth, website_policy, credential_files — each is a struct with SCHEMA + execute, stubs for external-dependency tools.

---

## Integration Design

### How new tools get registered

In main.zig, after creating ToolRegistry with static built-in tools:

```zig
// Tools that need injected dependencies
var session_search_tool = SessionSearchTool{ .db = &database };
var checkpoint_tool = CheckpointManagerTool{ .working_dir = working_dir };
var process_tool = ProcessRegistryTool.init(allocator);

// Register via makeToolHandler
const additional_tools = [_]ToolHandler{
    makeToolHandler(SessionSearchTool, &session_search_tool),
    makeToolHandler(CheckpointManagerTool, &checkpoint_tool),
    makeToolHandler(ProcessRegistryTool, &process_tool),
    // ... etc
};

// Add to registry's static list (or register as dynamic)
for (additional_tools) |t| {
    try registry.registerDynamic(t);
}
```

### Toolset updates

Update toolsets.zig to include new tool names in appropriate presets.
