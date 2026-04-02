# Complete Gap Analysis — hermes-zig vs hermes-agent

## Audit Date: 2026-04-03

This is the definitive gap analysis. Every Python module checked against Zig implementation.

---

## Summary

| Category | Python | Zig Implemented | Zig Stub | Zig Missing | Coverage |
|----------|--------|----------------|----------|-------------|----------|
| Agent module | 19 files | 6 | 0 | 13 | 32% |
| CLI module | 36 files | 8 | 0 | 28 | 22% |
| Tools | 58 files | 19 real + 15 stub | 15 | 24 | 33% |
| Gateway platforms | 16 files | 16 (all stubs) | 16 | 0 | 100% (stubs) |
| Terminal backends | 7 files | 3 real + 4 stub | 4 | 0 | 100% (stubs) |
| Cron | 2 files | 1 real | 0 | 1 | 50% |
| Honcho | 3 files | 1 stub | 1 | 2 | 33% |
| ACP | 8 files | 1 stub | 1 | 7 | 13% |
| Environments/RL | 22 files | 1 stub | 1 | 21 | 5% |
| Bundled skills | 74 skills | 0 | 0 | 74 | 0% |
| Top-level modules | 12 files | 2 | 0 | 10 | 17% |

**Overall: ~25% real implementation, ~15% stubs, ~60% missing**

---

## A. Agent Module — 13 Missing

| # | Python File | Lines | Purpose | Priority |
|---|------------|-------|---------|----------|
| 1 | anthropic_adapter.py | 1,290 | Anthropic-specific message formatting, tool_use blocks, cache control | HIGH |
| 2 | auxiliary_client.py | 1,960 | Secondary LLM calls (summarization, title gen, vision) | HIGH |
| 3 | context_references.py | 400 | Parse @file references in messages, inject file contents | MEDIUM |
| 4 | copilot_acp_client.py | 390 | GitHub Copilot ACP integration | LOW |
| 5 | insights.py | 860 | Usage analytics, cost tracking, session insights | MEDIUM |
| 6 | model_metadata.py | 900 | Model capabilities, context window sizes, pricing | HIGH |
| 7 | models_dev.py | 140 | Development/experimental model configs | LOW |
| 8 | redact.py | 170 | Redact sensitive info (API keys, passwords) from logs | HIGH |
| 9 | skill_commands.py | 270 | Slash commands for skill management (/skills install, etc.) | MEDIUM |
| 10 | skill_utils.py | 240 | Skill file parsing utilities, frontmatter extraction | MEDIUM |
| 11 | smart_model_routing.py | 150 | Auto-select model based on task complexity | LOW |
| 12 | title_generator.py | 110 | Generate conversation titles via LLM | LOW |
| 13 | usage_pricing.py | 600 | Token cost calculation per model | MEDIUM |

## B. CLI Module — 28 Missing

| # | Python File | Lines | Purpose | Priority |
|---|------------|-------|---------|----------|
| 1 | auth_commands.py | 410 | CLI auth subcommands (add/remove/list keys) | HIGH |
| 2 | callbacks.py | 240 | Streaming callback handlers for CLI display | HIGH |
| 3 | checklist.py | 130 | Interactive checklist UI component | LOW |
| 4 | claw.py | 520 | OpenClaw migration tool | LOW |
| 5 | clipboard.py | 310 | Clipboard read/write (image paste) | MEDIUM |
| 6 | codex_models.py | 150 | Codex/OpenAI model definitions | LOW |
| 7 | colors.py | 24 | ANSI color constants | HIGH (trivial) |
| 8 | config.py | 2,130 | Config file management, env loading, managed mode | HIGH |
| 9 | copilot_auth.py | 250 | GitHub Copilot OAuth flow | LOW |
| 10 | cron.py | 240 | CLI cron subcommands | MEDIUM |
| 11 | curses_ui.py | 170 | Curses-based UI components | LOW |
| 12 | default_soul.py | 17 | Default SOUL.md content | HIGH (trivial) |
| 13 | env_loader.py | 40 | .env file loading | HIGH (trivial) |
| 14 | gateway.py | 2,120 | CLI gateway subcommands (setup, start, stop) | HIGH |
| 15 | main.py | 5,160 | Main CLI entry, argument parsing, session management | HIGH |
| 16 | mcp_config.py | 560 | MCP server configuration management | MEDIUM |
| 17 | model_switch.py | 200 | Runtime model switching logic | MEDIUM |
| 18 | models.py | 1,090 | Model listing, selection, validation | HIGH |
| 19 | pairing.py | 90 | DM pairing for gateway auth | LOW |
| 20 | plugins_cmd.py | 500 | Plugin management CLI commands | LOW |
| 21 | runtime_provider.py | 660 | Runtime LLM provider resolution | HIGH |
| 22 | skills_config.py | 150 | Skills configuration management | MEDIUM |
| 23 | skills_hub.py | 1,140 | Skills Hub CLI commands | MEDIUM |
| 24 | skin_engine.py | 720 | Theme/skin system | LOW |
| 25 | tools_config.py | 1,690 | Tool enable/disable configuration | MEDIUM |
| 26 | uninstall.py | 290 | Uninstall hermes | LOW |
| 27 | webhook.py | 190 | Webhook CLI commands | LOW |
| 28 | model_switch.py | 200 | Model switching at runtime | MEDIUM |

## C. Tools — 15 Stubs + 24 Missing Utility Files

### 15 Stub tools (have SCHEMA but return placeholder):
browser_actions(11), checkpoint, delegate, homeassistant(4), honcho(4), image_gen, mixture_of_agents, process, rl_training(7), send_message, session_search, transcription, tts, vision, web_search

### 24 Missing utility/infra files:
ansi_strip, approval(UI), browser_camofox, browser_camofox_state, credential_files, debug_helpers, env_passthrough, file_operations(advanced), fuzzy_match, homeassistant_tool(HA-specific), honcho_tools(full), interrupt, mcp_oauth, mcp_tool(full), mixture_of_agents_tool(full), neutts_synth, openrouter_client, patch_parser, process_registry(full), registry(Python), rl_training_tool(full), session_search_tool(full), skills_guard(full), tirith_security(full), url_safety(full), website_policy(full)

## D. Other Missing

| Category | Missing Items |
|----------|--------------|
| Honcho integration | client.py (HTTP client), session.py (session management), cli.py (CLI commands) |
| ACP adapter | auth.py, entry.py, events.py, permissions.py, session.py, tools.py (7 files) |
| Environments/RL | agent_loop.py, agentic_opd_env.py, hermes_base_env.py, web_research_env.py, tool_context.py, patches.py, 12 tool_call_parsers, 3 benchmark envs |
| Bundled skills | 74 SKILL.md files across 26 categories |
| Top-level | model_tools.py, toolset_distributions.py, trajectory_compressor.py, hermes_state.py(full), hermes_constants.py(full), hermes_time.py, utils.py, mini_swe_runner.py, mcp_serve.py, rl_cli.py |
| Session persistence | Agent loop doesn't fully persist conversations to SQLite |
| Real LLM integration | Agent loop has mock-ready code but not tested with real API calls |

---

## Prioritized Implementation Plan

### Phase 1: Make it actually work (HIGH priority)

**Goal:** User can chat with an LLM through hermes-zig CLI.

1. **Session persistence** — Agent loop stores all turns in SQLite
2. **Real LLM calls** — Wire OpenAICompatClient to actually call API with user's key
3. **Streaming display** — Show LLM response as it streams
4. **model_metadata** — Context window sizes so compressor works
5. **redact** — Don't log API keys
6. **colors/default_soul/env_loader** — Trivial but needed for basic operation
7. **runtime_provider** — Resolve provider from config at startup
8. **callbacks** — Streaming callbacks for CLI display

**Tasks:** 15 tasks, ~8 files to create/modify

### Phase 2: Core tools working (HIGH priority)

**Goal:** Agent can use tools (terminal, files, web search).

9. **web_search** — Real DuckDuckGo API call
10. **session_search** — Wire to SQLite FTS5
11. **checkpoint** — Git-based snapshots
12. **process** — Background process management
13. **vision** — Send images to LLM
14. **delegate** — Subagent spawning

**Tasks:** 12 tasks, ~6 files

### Phase 3: Full CLI experience (MEDIUM priority)

**Goal:** All CLI commands work, gateway can start.

15. **config.py equivalent** — Full config management
16. **models.py equivalent** — Model listing/validation
17. **gateway.py equivalent** — Gateway CLI commands
18. **auth_commands** — Key management CLI
19. **tools_config** — Tool enable/disable
20. **mcp_config** — MCP server config
21. **insights/usage_pricing** — Cost tracking

**Tasks:** 14 tasks, ~7 files

### Phase 4: Advanced features (MEDIUM priority)

22. **anthropic_adapter** — Anthropic-specific formatting
23. **auxiliary_client** — Secondary LLM calls
24. **context_references** — @file injection
25. **skill_commands/skill_utils** — Skill CLI
26. **smart_model_routing** — Auto model selection
27. **title_generator** — Conversation titles
28. **homeassistant/honcho/tts/transcription/image_gen** — External API tools

**Tasks:** 15 tasks, ~10 files

### Phase 5: Ecosystem (LOW priority)

29. **ACP adapter** — Full editor integration
30. **Honcho integration** — Full user modeling
31. **Environments/RL** — Benchmark framework
32. **74 bundled skills** — Copy SKILL.md files
33. **Browser automation** — CDP/Playwright
34. **OpenClaw migration** — claw.py
35. **Skin engine** — Theming
36. **Plugin system** — Full plugin loading

**Tasks:** 20 tasks, ~15 files

---

## Total Remaining Work

| Phase | Files | Estimated Tasks |
|-------|-------|----------------|
| Phase 1 | ~8 | 15 |
| Phase 2 | ~6 | 12 |
| Phase 3 | ~7 | 14 |
| Phase 4 | ~10 | 15 |
| Phase 5 | ~15 | 20 |
| **Total** | **~46 files** | **76 tasks** |
