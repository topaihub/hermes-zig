# Final Design — Complete All 50 Tool Names + Agent/CLI/Gateway/Intelligence Features

## Principle: Understand intent, implement in Zig's way, on framework

- One Zig file per functional domain (not per Python file)
- Each file registers multiple ToolHandlers via comptime makeToolHandler
- All 50 tool names must have independent SCHEMA (LLM sees each as separate tool)
- Use framework effects (HttpClient, ProcessRunner, FileSystem) for I/O
- Use framework logging (RequestTrace, MethodTrace, StepTrace)
- Security checks are pre-exec hooks, not tools

## Files to Create/Modify

### New tool files (9 files → 33 tool names)

| File | Tool Names | Python Source |
|------|-----------|---------------|
| `tools/builtin/browser_actions.zig` | browser_navigate, browser_click, browser_type, browser_scroll, browser_snapshot, browser_back, browser_close, browser_console, browser_press, browser_get_images, browser_vision (11) | tools/browser_tool.py |
| `tools/builtin/homeassistant.zig` | ha_list_entities, ha_get_state, ha_call_service, ha_list_services (4) | tools/homeassistant_tool.py |
| `tools/builtin/honcho.zig` | honcho_context, honcho_profile, honcho_search, honcho_conclude (4) | tools/honcho_tools.py |
| `tools/builtin/skills_ops.zig` | skills_list, skill_view, skill_manage (3) | tools/skills_tool.py + skill_manager_tool.py |
| `tools/builtin/rl_training.zig` | rl_start_training, rl_stop_training, rl_check_status, rl_get_results, rl_list_environments, rl_select_environment, rl_edit_config (7) | tools/rl_training_tool.py |
| `tools/builtin/session_search.zig` | session_search (1) | tools/session_search_tool.py |
| `tools/builtin/mixture_of_agents.zig` | mixture_of_agents (1) | tools/mixture_of_agents_tool.py |
| `tools/builtin/process.zig` | process (1) | tools/process_registry.py |
| `tools/builtin/checkpoint.zig` | checkpoint (1) | tools/checkpoint_manager.py |

### New infra files (6 files)

| File | Purpose |
|------|---------|
| `tools/terminal/process_pool.zig` | Background process tracking (used by process tool) |
| `tools/terminal/persistent_shell.zig` | Persistent shell backend |
| `tools/util.zig` | stripAnsi, fuzzyMatch, parsePatch utilities |
| `security/scanner.zig` | Pre-exec security scanning (tirith) |
| `security/url.zig` | URL safety (SSRF prevention) |
| `security/policy.zig` | Website access policy |

### New intelligence files (2 files)

| File | Purpose |
|------|---------|
| `intelligence/honcho.zig` | Honcho API client for user modeling |
| `intelligence/skills_hub_client.zig` | agentskills.io HTTP client |

### New gateway files (2 files)

| File | Purpose |
|------|---------|
| `interface/gateway/platforms/api_server.zig` | OpenAI-compatible API server |
| `interface/gateway/platforms/telegram_network.zig` | Telegram network layer |

### New CLI files (4 files)

| File | Purpose |
|------|---------|
| `interface/cli/skin.zig` | Theme engine |
| `interface/cli/banner.zig` | Startup banner |
| `interface/cli/status.zig` | Status bar |
| `interface/cli/plugins.zig` | Plugin system |

### Modifications to existing files (10 changes)

| File | Change |
|------|--------|
| `agent/loop.zig` | Add: model fallback, interrupt check, session persistence, parallel tool calls |
| `agent/prompt_builder.zig` | Add: context file injection scanning |
| `llm/openai_compat.zig` | Add: Codex/Responses API mode |
| `llm/interface.zig` | Add: image_url in Message for vision |
| `tools/builtin/browser.zig` | Extend: add Camofox backend option |
| `tools/builtin/tts.zig` | Extend: add NeuTTS synthesis |
| `tools/builtin/voice_mode.zig` | Implement: real voice loop |
| `tools/mcp/client.zig` | Add: OAuth flow |
| `tools/toolsets.zig` | Add: new tool names to presets |
| `tools/builtin/root.zig` | Export all new tools |

### Total: 23 new files + 10 modifications
