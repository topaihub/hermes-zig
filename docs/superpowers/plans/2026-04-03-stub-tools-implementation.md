# Stub Tools → Real Implementation — Requirements, Design, Tasks

## Overview

15 tools currently return stub messages. This document provides requirements, design, and tasks for each, grouped by implementation complexity.

---

## Tier 1: Can implement now (no external API needed)

### 1. session_search — Search past conversations

**Requirement:** Query SQLite FTS5 index across all past sessions. Return matching message snippets with session metadata.

**Design:**
- SessionSearchTool gets `db: *core_sqlite.Database` field (injected at init)
- execute: parse query string → call `core.search.searchMessages(db, query)` → format results
- Prerequisite: Agent loop must persist messages to SQLite (see Agent Loop section below)

**Tasks:**
- [ ] Add `db` field to SessionSearchTool struct
- [ ] In execute: call searchMessages, format as "Session {id} ({date}): ...snippet..."
- [ ] In main.zig: pass database reference when creating SessionSearchTool
- [ ] Test: create in-memory db, insert messages, search, verify results

### 2. checkpoint — Workspace snapshots via git

**Requirement:** Create/list/rollback filesystem snapshots using a shadow git repo.

**Design:**
- CheckpointTool gets `working_dir: []const u8` field
- Shadow repo at `{working_dir}/.hermes-checkpoints/`
- create: `git init` (if needed) → `git add -A` → `git commit -m "checkpoint {timestamp}"`
- list: `git log --oneline`
- rollback: `git checkout {id} -- .`
- diff: `git diff {id}`
- Use `std.process.Child` to shell out to git

**Tasks:**
- [ ] In execute: parse action, shell out to git commands
- [ ] Handle git init on first checkpoint
- [ ] Format git log output for list
- [ ] Test: create checkpoint, list shows it

### 3. process — Background process management

**Requirement:** Track background processes, poll output, kill.

**Design:**
- ProcessTool gets `pool: *tools.terminal.ProcessPool` field
- list: return all tracked processes with status
- poll: return new stdout since last poll
- kill: send SIGTERM via `std.posix.kill` or process handle

**Prerequisite:** tools/terminal/process_pool.zig needs real spawn implementation

**Tasks:**
- [ ] Implement ProcessPool.spawn using std.process.Child with .Pipe stdout
- [ ] Implement ProcessPool.poll — read available bytes from stdout pipe
- [ ] Implement ProcessPool.kill — terminate process
- [ ] Wire ProcessTool.execute to ProcessPool methods
- [ ] Test: spawn `sleep 10`, poll, kill

### 4. delegate — Subagent spawning

**Requirement:** Spawn an isolated agent instance to handle a subtask.

**Design:**
- Create new AgentLoop instance in a std.Thread
- Pass the task as initial user message
- Collect result when thread completes
- Return result to caller

**Tasks:**
- [ ] In execute: create AgentLoop with same LlmClient + ToolRegistry
- [ ] Spawn std.Thread running agent.run() with task message
- [ ] Wait for completion (with timeout)
- [ ] Return agent's response
- [ ] Test: delegate simple task with mock LLM

### 5. send_message — Cross-platform messaging

**Requirement:** Send a message to a specific platform/chat via the gateway.

**Design:**
- SendMessageTool gets reference to gateway PlatformAdapter registry
- execute: find adapter by platform name → call adapter.send(chat_id, content)

**Prerequisite:** Gateway must be running with platform adapters

**Tasks:**
- [ ] Add platform adapter registry reference to SendMessageTool
- [ ] In execute: lookup platform, call send
- [ ] Return send result (message_id) or error
- [ ] Test: with mock adapter

---

## Tier 2: Need external HTTP API calls

### 6. web_search — Web search

**Requirement:** Search the web via Tavily or DuckDuckGo API.

**Design:**
- Use framework.NativeHttpClient
- Tavily: POST https://api.tavily.com/search with API key
- DuckDuckGo: GET https://api.duckduckgo.com/?q={query}&format=json (no key needed)
- Parse JSON response, extract title + snippet + URL

**Tasks:**
- [ ] Implement DuckDuckGo search (no API key required) as default
- [ ] Add Tavily support when api key configured
- [ ] Parse response JSON, format as readable results
- [ ] Test: with mock HTTP

### 7. vision — Image analysis

**Requirement:** Send image to LLM vision API for analysis.

**Design:**
- Read image file, base64 encode
- Build multimodal message with image_url content
- Call LlmClient.complete with vision message

**Tasks:**
- [ ] Read image file from path
- [ ] Base64 encode using std.base64
- [ ] Build OpenAI vision message format: `{"type":"image_url","image_url":{"url":"data:image/png;base64,..."}}`
- [ ] Call LlmClient.complete
- [ ] Return LLM's description
- [ ] Test: with mock LLM

### 8. image_gen — Image generation

**Requirement:** Generate image via DALL-E or similar API.

**Design:**
- POST to OpenAI /v1/images/generations
- Save returned image to file

**Tasks:**
- [ ] HTTP POST with prompt and size
- [ ] Parse response, extract image URL or base64
- [ ] Save to file
- [ ] Return file path
- [ ] Test: with mock HTTP

### 9. transcription — Audio transcription

**Requirement:** Transcribe audio via Whisper API.

**Design:**
- POST multipart/form-data to OpenAI /v1/audio/transcriptions
- Return transcribed text

**Tasks:**
- [ ] Read audio file
- [ ] Build multipart request
- [ ] POST to Whisper API
- [ ] Return text
- [ ] Test: with mock HTTP

### 10. tts — Text-to-speech

**Requirement:** Convert text to speech via TTS API.

**Design:**
- POST to OpenAI /v1/audio/speech
- Save audio to file

**Tasks:**
- [ ] HTTP POST with text and voice
- [ ] Save response body as audio file
- [ ] Return file path
- [ ] Test: with mock HTTP

### 11. homeassistant — Smart home control

**Requirement:** Control HA devices via REST API.

**Design:**
- All 4 tools use HTTP calls to `{ha_url}/api/...` with Bearer token
- ha_list_entities: GET /api/states
- ha_get_state: GET /api/states/{entity_id}
- ha_call_service: POST /api/services/{domain}/{service}
- ha_list_services: GET /api/services

**Tasks:**
- [ ] Implement HTTP calls for each action
- [ ] Parse JSON responses
- [ ] Format readable output
- [ ] Test: with mock HTTP

### 12. honcho — User modeling

**Requirement:** Retrieve/update user context from Honcho API.

**Design:**
- HTTP calls to Honcho server
- honcho_context: GET /users/{id}/context
- honcho_profile: GET /users/{id}/profile
- honcho_search: POST /users/{id}/search
- honcho_conclude: POST /users/{id}/conclude

**Tasks:**
- [ ] Implement HTTP calls
- [ ] Parse responses
- [ ] Test: with mock HTTP

---

## Tier 3: Complex / external dependencies

### 13. browser_actions — Browser automation (11 tools)

**Requirement:** Control a headless browser.

**Design:** Requires CDP (Chrome DevTools Protocol) or Playwright. Too complex for pure Zig v1. Options:
- Shell out to `playwright` CLI
- Implement minimal CDP WebSocket client
- Keep as stub, document requirement

**Tasks:**
- [ ] Implement via `playwright` CLI if available: `playwright navigate {url}`, etc.
- [ ] Fallback: return "Install playwright for browser support"

### 14. mixture_of_agents — Multi-model orchestration

**Requirement:** Send same prompt to multiple models, aggregate.

**Design:** Needs multiple LlmClient instances. Complex for v1.

**Tasks:**
- [ ] Accept comma-separated model list
- [ ] Call LlmClient.complete for each model sequentially
- [ ] Combine responses
- [ ] Test: with mock LLM

### 15. rl_training — RL training (7 tools)

**Requirement:** Manage RL training via Tinker-Atropos.

**Design:** Requires Tinker-Atropos Python package. Keep as stubs.

**Tasks:**
- [ ] Keep as stubs with clear error messages
- [ ] Document: "Install tinker-atropos for RL training support"

---

## Agent Loop Prerequisite: Session Persistence

Many tools (session_search, memory nudges) require the agent loop to persist conversations to SQLite.

**Tasks:**
- [ ] In agent/loop.zig run(): after each LLM response, call `database.appendMessage(session_id, role, content)`
- [ ] Create session on first message: `database.createSession(session_id, "cli", model)`
- [ ] Pass database reference to AgentLoop struct
- [ ] Wire in main.zig: open database, pass to AgentLoop

---

## Execution Order

```
1. Agent loop session persistence (prerequisite)
2. Tier 1: session_search, checkpoint, process, delegate, send_message
3. Tier 2: web_search, vision, image_gen, transcription, tts, homeassistant, honcho
4. Tier 3: browser_actions, mixture_of_agents (rl_training stays stub)
```
