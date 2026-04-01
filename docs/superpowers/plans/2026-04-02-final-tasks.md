# Final Task Plan — Complete All Missing Features

> 5 batches, 33 tasks total. Each task is one subagent dispatch.

---

## Batch 1: 9 New Tool Files (33 tool names)

### Task 1.1: browser_actions.zig (11 tools)
- Read tools/browser_tool.py, understand each browser action
- Create 11 tool structs in one file, each with SCHEMA + execute
- browser_navigate: HTTP to browser API, browser_click: click element, etc.
- All stubs returning descriptive messages (real browser needs Playwright/CDP)
- Update builtin/root.zig
- Test: all 11 schema names correct

### Task 1.2: homeassistant.zig (4 tools)
- Read tools/homeassistant_tool.py
- ha_list_entities: GET {ha_url}/api/states, filter by domain/area
- ha_get_state: GET {ha_url}/api/states/{entity_id}
- ha_call_service: POST {ha_url}/api/services/{domain}/{service}
- ha_list_services: GET {ha_url}/api/services
- All use HttpClient with Bearer token
- Test: schema names

### Task 1.3: honcho.zig (4 tools)
- Read tools/honcho_tools.py
- honcho_context: GET user turn context from Honcho API
- honcho_profile: GET user profile/model
- honcho_search: search user history
- honcho_conclude: end conversation context
- All use HttpClient
- Test: schema names

### Task 1.4: skills_ops.zig (3 tools)
- Read tools/skills_tool.py + skill_manager_tool.py
- skills_list: scan skill dirs, return name+description list
- skill_view: read SKILL.md content
- skill_manage: create/update/delete SKILL.md files
- Use std.fs for file I/O
- Test: schema names

### Task 1.5: rl_training.zig (7 tools)
- Read tools/rl_training_tool.py
- All 7 tools are stubs (RL training needs Tinker-Atropos)
- Each returns descriptive message about what it would do
- Test: schema names

### Task 1.6: session_search.zig (1 tool)
- Read tools/session_search_tool.py
- Uses core/search.zig FTS5
- Format results with session metadata
- Test: schema name

### Task 1.7: mixture_of_agents.zig (1 tool)
- Read tools/mixture_of_agents_tool.py
- Stub: returns description of MoA methodology
- Test: schema name

### Task 1.8: process.zig (1 tool)
- Read tools/process_registry.py
- Wraps ProcessPool (created in Task 2.1)
- list/poll/log/kill actions
- Test: schema name

### Task 1.9: checkpoint.zig (1 tool)
- Read tools/checkpoint_manager.py
- Shell out to git for snapshots
- create/list/rollback/diff actions
- Test: schema name

---

## Batch 2: 6 Infra Files

### Task 2.1: tools/terminal/process_pool.zig
- ProcessPool: spawn background process, track stdout, poll status, kill
- HashMap of session_id → ProcessInfo
- Test: init

### Task 2.2: tools/terminal/persistent_shell.zig
- PersistentShellBackend: spawn shell once, keep pipes open
- Add to TerminalBackend tagged union
- Test: init

### Task 2.3: tools/util.zig
- stripAnsi: remove ESC[ sequences
- fuzzyMatch: substring + distance scoring
- parsePatch: unified diff hunk parsing
- Test: each function

### Task 2.4: security/scanner.zig + url.zig + policy.zig
- scanner: preExecScan with dangerous command patterns
- url: isPrivateAddress for SSRF prevention
- policy: checkWebsitePolicy against rules
- Test: each function

### Task 2.5: intelligence/honcho.zig + skills_hub_client.zig
- HonchoClient: HTTP to Honcho API
- SkillsHubClient: HTTP to agentskills.io
- Test: init

### Task 2.6: gateway/platforms/api_server.zig + telegram_network.zig
- ApiServerAdapter: OpenAI-compatible HTTP server
- TelegramNetwork: HTTP wrapper for Bot API
- Test: platform names

---

## Batch 3: 10 Agent/LLM Modifications

### Task 3.1: agent/loop.zig enhancements
- Model fallback on error
- Interrupt flag check before LLM call
- Session persistence (appendMessage after each turn)
- Parallel tool calls (std.Thread per tool call)

### Task 3.2: agent/prompt_builder.zig enhancement
- Scan context files for injection patterns before including

### Task 3.3: llm/ enhancements
- openai_compat.zig: add Responses API mode (POST /v1/responses)
- interface.zig: add image_url field to Message for vision

---

## Batch 4: 4 CLI Files

### Task 4.1: cli/skin.zig + banner.zig + status.zig + plugins.zig
- skin: load theme JSON, apply colors
- banner: ASCII art on startup
- status: bottom bar with model + tokens
- plugins: scan plugin dir, load configs

---

## Batch 5: Existing File Extensions

### Task 5.1: Extend browser.zig, tts.zig, voice_mode.zig, mcp/client.zig
- browser: add Camofox backend option
- tts: add NeuTTS
- voice_mode: real voice loop skeleton
- mcp: OAuth flow

### Task 5.2: toolsets.zig + builtin/root.zig
- Add all new tool names to toolset presets
- Export all new tools from root.zig

### Task 5.3: Final verification
- Run full test suite
- Run gap analysis again
- Verify all 50 tool names present
