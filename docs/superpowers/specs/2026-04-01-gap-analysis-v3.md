# Gap Analysis & Completion Plan (v3)

## Root Cause

The original brainstorming phase did not enumerate Python source files one-by-one. The design said "20+ tools" instead of listing all 47. This caused 30% of features to be missed.

## Precise Gap List

### Missing Tools (19 user-facing)

| # | Python File | Zig File | Description |
|---|------------|----------|-------------|
| 1 | browser_camofox.py | builtin/browser_camofox.zig | Anti-fingerprint browser automation |
| 2 | browser_camofox_state.py | builtin/browser_camofox_state.zig | Browser state persistence |
| 3 | checkpoint_manager.py | builtin/checkpoint_manager.zig | Workspace snapshot/rollback |
| 4 | credential_files.py | builtin/credential_files.zig | Credential file management |
| 5 | homeassistant_tool.py | builtin/homeassistant_tool.zig | Home Assistant device control |
| 6 | honcho_tools.py | builtin/honcho_tools.zig | Honcho memory integration |
| 7 | mcp_oauth.py | mcp/oauth.zig | MCP server OAuth flow |
| 8 | mixture_of_agents_tool.py | builtin/mixture_of_agents.zig | Multi-model orchestration |
| 9 | neutts_synth.py | builtin/neutts_synth.zig | NeuTTS voice synthesis |
| 10 | process_registry.py | builtin/process_registry.zig | Background process tracking |
| 11 | rl_training_tool.py | builtin/rl_training.zig | RL training data collection |
| 12 | session_search_tool.py | builtin/session_search.zig | Search past sessions |
| 13 | skill_manager_tool.py | builtin/skill_manager.zig | Install/uninstall skills |
| 14 | skills_hub.py | builtin/skills_hub.zig | Skills Hub marketplace |
| 15 | skills_sync.py | builtin/skills_sync.zig | Skill synchronization |
| 16 | skills_tool.py | builtin/skills_tool.zig | Skill execution |
| 17 | tirith_security.py | builtin/tirith_security.zig | Deep security scanning |
| 18 | url_safety.py | builtin/url_safety.zig | URL safety checking |
| 19 | website_policy.py | builtin/website_policy.zig | Website access rules |

### Missing Utility Modules (8 infra)

| # | Python File | Zig Location | Description |
|---|------------|-------------|-------------|
| 1 | ansi_strip.py | tools/util/ansi.zig | ANSI escape stripping |
| 2 | debug_helpers.py | tools/util/debug.zig | Debug utilities |
| 3 | env_passthrough.py | tools/util/env.zig | Env var forwarding to tools |
| 4 | fuzzy_match.py | tools/util/fuzzy.zig | Fuzzy string matching |
| 5 | interrupt.py | agent/interrupt.zig | Interrupt signal handling |
| 6 | openrouter_client.py | llm/openrouter.zig | OpenRouter-specific client |
| 7 | patch_parser.py | tools/util/patch.zig | Unified diff parser |
| 8 | file_operations.py | (merge into file_edit) | Advanced file operations |

### Missing Gateway (2)

| # | Python File | Zig File | Description |
|---|------------|----------|-------------|
| 1 | api_server.py | gateway/platforms/api_server.zig | OpenAI-compatible API server |
| 2 | telegram_network.py | gateway/platforms/telegram_network.zig | Telegram network layer |

### Missing Terminal Backend (1)

| # | Python File | Zig File | Description |
|---|------------|----------|-------------|
| 1 | persistent_shell.py | terminal/persistent_shell.zig | Persistent shell sessions |

### Missing Agent Features (10)

| # | Feature | Location | Description |
|---|---------|----------|-------------|
| 1 | Model fallback | agent/loop.zig | Retry with fallback model on failure |
| 2 | Honcho integration | intelligence/honcho.zig | User modeling via Honcho API |
| 3 | Codex/Responses mode | llm/codex_mode.zig | OpenAI Responses API support |
| 4 | Vision messages | llm/vision.zig | Multimodal message construction |
| 5 | Reasoning wiring | agent/loop.zig | Wire reasoning effort to LLM calls |
| 6 | Interrupt wiring | agent/loop.zig | Check interrupt flag during LLM call |
| 7 | Session persistence | agent/loop.zig | Save messages to SQLite after each turn |
| 8 | Context file scan | agent/prompt_builder.zig | Injection detection in context files |
| 9 | Parallel tool calls | agent/loop.zig | Execute multiple tool calls concurrently |
| 10 | Background review | agent/loop.zig | Background task for reviewing agent work |

### Missing CLI Features (6)

| # | Feature | Location | Description |
|---|---------|----------|-------------|
| 1 | Tab completion | cli/tui.zig | Command and path completion |
| 2 | Skin engine | cli/skin.zig | Theming system |
| 3 | Banner | cli/banner.zig | Startup banner display |
| 4 | Status bar | cli/status.zig | Bottom status bar |
| 5 | Runtime model switch | cli/commands.zig | /model actually switches |
| 6 | Plugin system | cli/plugins.zig | Plugin loading |

### Missing Intelligence Features (5)

| # | Feature | Location | Description |
|---|---------|----------|-------------|
| 1 | Skills creator | intelligence/skills_creator.zig | Autonomous skill creation |
| 2 | Skills execution | intelligence/skills_executor.zig | Inject skill into prompt |
| 3 | Skills Hub client | intelligence/skills_hub_client.zig | agentskills.io HTTP client |
| 4 | User modeling | intelligence/user_model.zig | Honcho dialectic modeling |
| 5 | 74 bundled skills | skills/ directory | Bundled SKILL.md files |

## Total Missing Items: 51

- 19 user-facing tools
- 8 utility modules
- 2 gateway platforms
- 1 terminal backend
- 10 agent features
- 6 CLI features
- 5 intelligence features
