# SP-5: Agent Loop — Detailed Implementation Plan

> **For agentic workers:** Read Python files: run_agent.py (class AIAgent), agent/prompt_builder.py, agent/context_compressor.py, agent/prompt_caching.py, agent/credential_pool.py

**Goal:** Core agent orchestration — the heart of hermes-agent.

---

## Task 1: Agent Loop

**Files:** src/agent/root.zig, src/agent/loop.zig

- [ ] AgentLoop struct: llm (LlmClient), tools (*ToolRegistry), state (*Database), config (*Config), prompt_builder (PromptBuilder), compressor (ContextCompressor), credential_pool (?*CredentialPool)
- [ ] `run(session, input_message) !Message`:
  ```
  1. Append user message to session history
  2. Build prompt (system + history + tool schemas)
  3. Call llm.complete(request)
  4. If response has tool_calls:
     a. For each tool_call: dispatch via tools.dispatch(name, args, ctx)
     b. Append tool results as tool role messages
     c. Goto 3 (max 25 iterations)
  5. Append assistant message to history
  6. Return assistant message
  ```
- [ ] `runStream(session, input, callback) !Message` — same loop but with llm.completeStream
- [ ] Max iterations guard (prevent infinite tool loops)
- [ ] Error handling: LLM errors → retry with next credential, tool errors → return error message to LLM
- [ ] Tests with mock LlmClient and mock ToolRegistry
- [ ] Commit: `feat(agent): add core agent loop`

## Task 2: Prompt Builder

**Files:** src/agent/prompt_builder.zig

- [ ] PromptBuilder struct: config, soul_content, tool_registry
- [ ] `buildSystemPrompt(allocator, session) ![]u8`:
  1. Start with SOUL.md content (persona)
  2. Append platform-specific hints (CLI vs Telegram formatting rules)
  3. Append context files (AGENTS.md, .cursorrules from working dir)
  4. Append skills index (list of available skills with trigger conditions)
  5. Append memory summary (recent MEMORY.md entries)
- [ ] `buildMessages(allocator, session, system_prompt) ![]Message`:
  1. System message with built system prompt
  2. Session history messages
  3. Apply context window limit (delegate to compressor if needed)
- [ ] `buildToolSchemas(allocator) ![]ToolSchema` — collect from registry
- [ ] Context file scanning: detect prompt injection patterns (from Python's _CONTEXT_THREAT_PATTERNS)
- [ ] Tests: build prompt with various configs, verify structure
- [ ] Commit: `feat(agent): add prompt builder with context file scanning`

## Task 3: Context Compressor

**Files:** src/agent/context_compressor.zig

- [ ] ContextCompressor struct: max_tokens (from model metadata), allocator
- [ ] `compress(messages, max_tokens) ![]Message`:
  1. Count tokens (approximate: chars / 4)
  2. If under limit, return as-is
  3. Strategy 1: Remove oldest non-system messages
  4. Strategy 2: Summarize old messages via LLM call (if available)
  5. Strategy 3: Truncate individual long messages
- [ ] `shouldCompress(messages, max_tokens) bool`
- [ ] Token counting: simple heuristic (chars/4) or tiktoken-style if available
- [ ] Tests: compress long history, verify system message preserved
- [ ] Commit: `feat(agent): add context compressor`

## Task 4: Prompt Caching

**Files:** src/agent/prompt_caching.zig

- [ ] Anthropic-specific: inject `cache_control: {"type": "ephemeral"}` into stable prompt blocks
- [ ] Identify stable blocks: system prompt, tool schemas (change rarely)
- [ ] Identify volatile blocks: recent messages (change every turn)
- [ ] `applyCaching(messages) []Message` — annotate messages with cache hints
- [ ] Tests: verify cache_control added to system message
- [ ] Commit: `feat(agent): add Anthropic prompt caching`

## Task 5: Credential Pool

**Files:** src/agent/credential_pool.zig

- [ ] CredentialPool struct: keys ([]ApiKey), current_index, cooldowns (per-key timestamps)
- [ ] ApiKey: key, base_url, provider, cooled_until
- [ ] `getNext() !ApiKey` — round-robin, skip cooled keys
- [ ] `cooldown(key, duration_seconds)` — mark key as cooled after rate limit
- [ ] `reset(key)` — clear cooldown
- [ ] Integration with agent loop: on rate limit error → cooldown current key → retry with next
- [ ] Tests: rotation, cooldown, exhaustion
- [ ] Commit: `feat(agent): add credential pool with cooldown`
