# SP-2: LLM Client Layer — Detailed Implementation Plan

> **For agentic workers:** Read Python files: run_agent.py (lines 1-500), agent/auxiliary_client.py, hermes_cli/runtime_provider.py

**Goal:** LlmClient vtable with Arena-based responses, OpenAI-compatible + Anthropic clients, SSE streaming.

**MANDATORY:** CompletionResponse MUST use ArenaAllocator. No exceptions.

---

## Task 1: LLM Interface

**Files:** src/llm/root.zig, src/llm/interface.zig

- [ ] Define CompletionRequest: model, messages ([]Message), tools (?[]ToolSchema), temperature (f32), max_tokens (?u32), stream (bool), reasoning (?ReasoningConfig)
- [ ] Define CompletionResponse with **ArenaAllocator**: content (?[]const u8), tool_calls (?[]ToolCall), usage (TokenUsage), arena (std.heap.ArenaAllocator). `pub fn deinit(self: *CompletionResponse) void { self.arena.deinit(); }`
- [ ] Define StreamCallback: ctx (*anyopaque), on_delta (*const fn(ctx, content, done) void). `pub fn emit(self, content, done) void`
- [ ] Define LlmClient vtable: complete, completeStream, deinit
- [ ] Tests: CompletionResponse arena lifecycle (alloc strings from arena, deinit frees all)
- [ ] Commit: `feat(llm): add LlmClient interface with Arena responses`

## Task 2: SSE Streaming Parser

**Files:** src/llm/streaming.zig

- [ ] SSE line parser: split by `\n`, detect `data: ` prefix, handle `data: [DONE]`
- [ ] Stream accumulator: collect deltas into full content + tool_calls
- [ ] Handle OpenAI format: `{"choices":[{"delta":{"content":"..."}}]}`
- [ ] Handle Anthropic format: event types (message_start, content_block_delta, message_delta, message_stop)
- [ ] Tests: parse OpenAI SSE chunks, parse Anthropic SSE events, accumulate to full response
- [ ] Commit: `feat(llm): add SSE streaming parser`

## Task 3: OpenAI-Compatible Client

**Files:** src/llm/openai_compat.zig

- [ ] OpenAICompatClient struct: base_url, api_key, allocator
- [ ] `asLlmClient(self) LlmClient` — return vtable interface
- [ ] complete: POST /v1/chat/completions, parse response JSON, allocate all strings from Arena
- [ ] completeStream: POST with stream=true, parse SSE via streaming.zig, call StreamCallback per delta
- [ ] Parse tool_calls from response (id, function.name, function.arguments)
- [ ] Parse usage (prompt_tokens, completion_tokens, total_tokens)
- [ ] Use framework.NativeHttpClient for HTTP
- [ ] Tests with mock HTTP (inject custom requester into NativeHttpClient)
- [ ] Commit: `feat(llm): add OpenAI-compatible client`

## Task 4: Anthropic Client

**Files:** src/llm/anthropic.zig

- [ ] AnthropicClient struct: api_key, model, allocator
- [ ] POST /v1/messages with headers: x-api-key, anthropic-version, content-type
- [ ] Parse Anthropic response format: content[].text, stop_reason, usage
- [ ] Handle tool_use content blocks (type="tool_use", id, name, input)
- [ ] Stream: handle event types (message_start → content_block_start → content_block_delta → content_block_stop → message_delta → message_stop)
- [ ] Tests with mock HTTP
- [ ] Commit: `feat(llm): add Anthropic native client`

## Task 5: Provider Registry

**Files:** src/llm/provider_registry.zig

- [ ] Factory: config provider name → LlmClient instance
- [ ] Mapping: "openrouter" → OpenAICompatClient(openrouter base URL), "openai" → OpenAICompatClient(openai base URL), "anthropic" → AnthropicClient, "nous" → OpenAICompatClient(nous base URL), "z.ai" → OpenAICompatClient(z.ai base URL), "kimi" → OpenAICompatClient(kimi base URL), "minimax" → OpenAICompatClient(minimax base URL)
- [ ] Support custom base_url from config
- [ ] Tests: create client from config, verify correct type
- [ ] Commit: `feat(llm): add provider registry factory`
