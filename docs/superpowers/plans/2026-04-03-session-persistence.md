# Agent Loop Session Persistence — Requirements, Design, Tasks

## Requirement

Agent loop must persist ALL conversation turns to SQLite, so that:
1. `session_search` tool can search past conversations
2. Sessions survive process restart (resume conversation)
3. Usage statistics are tracked per session
4. Memory nudges can reference conversation history

Currently only the final assistant response is saved. Missing:
- User input messages
- Assistant messages with tool calls
- Tool result messages
- Session creation on first message
- Session metadata updates (message count, token usage)

## Design

### Session lifecycle

```
User starts conversation
  → createSession(session_id, "cli", model)

Each turn:
  User sends message
    → appendMessage(session_id, "user", content)
  LLM responds with text
    → appendMessage(session_id, "assistant", content)
  LLM responds with tool calls
    → appendMessage(session_id, "assistant", tool_calls_json)
  Tool returns result
    → appendMessage(session_id, "tool", result, tool_call_id=id, tool_name=name)
  Loop continues...

Session ends
  → updateSessionStats(session_id, message_count, tool_call_count, input_tokens, output_tokens)
```

### Changes to AgentLoop

```zig
pub const AgentLoop = struct {
    // existing fields...
    db: ?core_sqlite.Database = null,
    session_id: []const u8 = "default",

    pub fn run(self, messages, tool_schemas) !RunResult {
        // 1. Create session if db available and not exists
        if (self.db) |db| {
            core_database.createSession(db, self.session_id, "cli", self.config.model) catch {};
        }

        // 2. Persist initial user messages
        if (self.db) |db| {
            for (messages) |msg| {
                core_database.appendMessage(db, self.session_id, @tagName(msg.role), msg.content) catch {};
            }
        }

        // In the loop:
        // 3. After LLM response (text): persist assistant message
        // 4. After LLM response (tool_calls): persist as JSON
        // 5. After tool execution: persist tool result with tool_call_id
        // 6. After final response: update session stats
    }
};
```

### Changes to database.zig

Current `appendMessage` signature: `(db, session_id, role, content)`

Need to extend to support tool metadata:
```zig
pub fn appendMessage(db, session_id, role, content) !void  // existing
pub fn appendToolMessage(db, session_id, content, tool_call_id, tool_name) !void  // new
pub fn updateSessionStats(db, session_id, msg_count, tool_count, in_tokens, out_tokens) !void  // exists but verify
```

### Changes to main.zig

- Generate unique session_id per conversation (timestamp-based or UUID-like)
- Pass db and session_id to AgentLoop
- On `/new` command: generate new session_id

## Tasks

### Task 1: Extend database.zig
- [ ] Add `appendToolMessage(db, session_id, content, tool_call_id, tool_name) !void`
- [ ] Verify `updateSessionStats` works correctly
- [ ] Test: append tool message, verify in getMessages

### Task 2: Update AgentLoop to persist all turns
- [ ] Add `session_id: []const u8` field to AgentLoop
- [ ] At start of run(): createSession if db available
- [ ] Before LLM call: persist user messages from input
- [ ] After LLM text response: persist assistant message
- [ ] After LLM tool_calls response: persist as assistant message with tool_calls JSON
- [ ] After each tool execution: persist tool result with appendToolMessage
- [ ] After final response: call updateSessionStats with accumulated counts
- [ ] Test: run with mock LLM + in-memory db, verify all messages persisted

### Task 3: Wire session management in main.zig
- [ ] Open SQLite database at startup: `core.sqlite.Database.open("hermes.db")`
- [ ] Init schema: `core.database.initSchema(db)`
- [ ] Generate session_id: timestamp-based `"cli-{timestamp}"`
- [ ] Pass db and session_id to AgentLoop
- [ ] On `/new` command: generate new session_id
- [ ] On exit: close database

### Task 4: Wire session_search tool to real database
- [ ] Add `db` field to SessionSearchTool
- [ ] In execute: call `core.search.searchMessages(db, query)`
- [ ] Format results: "Session {id} ({source}): ...snippet..."
- [ ] In main.zig: pass db when creating SessionSearchTool
- [ ] Test: insert messages, search, verify results

### Task 5: Verify end-to-end
- [ ] Start hermes-zig, send messages
- [ ] Check hermes.db has sessions and messages tables populated
- [ ] Use /new to start new session, verify new session_id
- [ ] session_search tool returns real results from past conversations
