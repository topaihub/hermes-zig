# SP-7: Gateway Core + All Platforms — Detailed Implementation Plan

> **For agentic workers:** Read Python files: gateway/run.py, gateway/session.py, gateway/delivery.py, gateway/platforms/base.py, gateway/platforms/*.py

**Goal:** PlatformAdapter vtable, MessageQueue, session routing, 14 platforms each in own thread.

**CRITICAL:** Each platform adapter runs in its own `std.Thread`. Communication with agent loop is ONLY through MessageQueue. No shared mutable state.

---

## Task 1: Gateway Core

**Files:** src/interface/gateway/root.zig, platform.zig, session.zig, delivery.zig, pairing.zig, hooks.zig

- [ ] PlatformAdapter vtable: platform(), connect(), send(allocator, chat_id, content, reply_to) !SendResult, setMessageHandler(MessageHandler), deinit()
- [ ] IncomingMessage: source (SessionSource), content, reply_to, timestamp, allocator. `deinit()` frees content.
- [ ] SendResult: message_id, allocator. `deinit()` frees id.
- [ ] MessageHandler: ctx (*anyopaque), handle (*const fn(ctx, IncomingMessage) void)
- [ ] **MessageQueue** (Mutex + Condition + ArrayList):
  ```zig
  pub fn push(msg) void — lock, append, signal
  pub fn pop(timeout_ns) ?IncomingMessage — lock, wait on condition, remove first
  pub fn close() void — set closed flag, broadcast
  ```
- [ ] session.zig: Session routing — (platform, chat_id) → session_id lookup/create in SQLite
- [ ] delivery.zig: Message chunking (Telegram 4096 chars, Discord 2000, etc.), markdown→platform format conversion
- [ ] pairing.zig: DM auth — generate code, verify code, link user
- [ ] hooks.zig: Gateway hooks — load boot.md, execute pre/post message hooks
- [ ] Tests: MessageQueue push/pop, session routing, delivery chunking
- [ ] Commit: `feat(gateway): add core gateway with MessageQueue and session routing`

## Task 2: Gateway Runner

**Files:** src/interface/gateway/runner.zig

- [ ] GatewayRunner: holds all platform adapters + shared MessageQueue + AgentLoop
- [ ] `start()`:
  1. For each configured platform: create adapter, spawn std.Thread running adapter.connect()
  2. Main loop: pop from MessageQueue → route to session → AgentLoop.run → send response via adapter
- [ ] `stop()`: close MessageQueue, join all threads
- [ ] Graceful shutdown: set flag, close queue, adapters disconnect
- [ ] Commit: `feat(gateway): add gateway runner with multi-threaded platform adapters`

## Task 3: Telegram Adapter

**Files:** src/interface/gateway/platforms/root.zig, telegram.zig

- [ ] Bot API long polling: GET /getUpdates with offset
- [ ] Parse Update → extract message/callback_query → IncomingMessage
- [ ] Send: POST /sendMessage (text), /sendPhoto, /editMessageText
- [ ] Features: groups (check bot mentioned), threads (reply_to_message_id), media handling
- [ ] Run in dedicated thread, push to MessageQueue
- [ ] Tests with mock HTTP
- [ ] Commit: `feat(gateway): add Telegram adapter`

## Task 4: Discord Adapter

**Files:** src/interface/gateway/platforms/discord.zig

- [ ] Gateway WebSocket: connect to wss://gateway.discord.gg, handle HELLO/HEARTBEAT/DISPATCH
- [ ] Parse MESSAGE_CREATE events → IncomingMessage
- [ ] Send: POST /channels/{id}/messages
- [ ] Features: slash commands, threads, reactions, embeds
- [ ] Tests with mock WebSocket
- [ ] Commit: `feat(gateway): add Discord adapter`

## Task 5: Remaining 12 Platforms

**Files:** src/interface/gateway/platforms/{slack,whatsapp,signal,email,matrix,feishu,dingtalk,wecom,homeassistant,sms,mattermost,webhook}.zig

- [ ] slack.zig: Events API (HTTP POST webhook), Web API for sending
- [ ] whatsapp.zig: Cloud API webhooks (verify + receive), send via API
- [ ] signal.zig: signal-cli JSON-RPC (spawn process, communicate via stdin/stdout)
- [ ] email.zig: IMAP polling for incoming, SMTP for sending (via std.net TCP)
- [ ] matrix.zig: Client-server API (/sync polling, /send)
- [ ] feishu.zig: Feishu Bot API (event subscription + send)
- [ ] dingtalk.zig: DingTalk Bot API (webhook receive + send)
- [ ] wecom.zig: WeCom Bot API (callback + send)
- [ ] homeassistant.zig: HA conversation API (REST)
- [ ] sms.zig: Twilio API (webhook receive + REST send)
- [ ] mattermost.zig: Mattermost Bot API (WebSocket events + REST send)
- [ ] webhook.zig: Generic HTTP server — receive POST, send response
- [ ] Each: connect in own thread, push to MessageQueue, send via platform API
- [ ] Tests for each with mock HTTP/WebSocket
- [ ] Commit per platform or batch: `feat(gateway): add {platform} adapter`
