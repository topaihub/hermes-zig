# hermes-zig

A self-improving AI agent written in Zig. CLI interface with 50+ tools, multi-platform messaging gateway, skills system, and persistent memory.

Zig rewrite of [hermes-agent](https://github.com/nousresearch/hermes-agent), built on [zig-framework](https://github.com/topaihub/zig-framework).

## Features

- **Interactive CLI** — Terminal UI with streaming responses, slash commands, command history
- **Web Config UI** — Browser-based setup at `http://127.0.0.1:8318`
- **50+ Tools** — Terminal, file ops, web search, browser, code execution, vision, TTS, and more
- **Multi-provider LLM** — OpenRouter (200+ models), OpenAI, Anthropic, Nous, custom endpoints
- **14 Messaging Platforms** — Telegram, Discord, Slack, WhatsApp, Signal, Email, Matrix, and more
- **Skills System** — Procedural memory, Skills Hub marketplace, autonomous skill creation
- **Persistent Memory** — SQLite-backed sessions, FTS5 search, user modeling
- **Cron Scheduler** — Scheduled tasks with platform delivery
- **Security** — Command approval, injection scanning, path safety, env filtering
- **Single Binary** — Zero runtime dependencies, cross-platform (Linux/macOS/Windows)

## Quick Start

### Download

Grab the latest binary from [Releases](https://github.com/topaihub/hermes-zig/releases), or build from source:

```bash
git clone https://github.com/topaihub/hermes-zig.git
cd hermes-zig
zig build -Doptimize=ReleaseSmall
./zig-out/bin/hermes-zig
```

### First Run

On first launch, hermes-zig starts the **Setup Wizard**:

```
  _  _ ___ ___ __  __ ___ ___
 | || | __| _ \  \/  | __/ __|
 | __ | _||   / |\/| | _|\__ \
 |_||_|___|_|_\_|  |_|___|___/
       A G E N T  (Zig Edition)

  Config UI: http://127.0.0.1:8318

  No config.json found. Starting setup wizard...

  Select a provider:
    1) OpenRouter (200+ models, recommended)
    2) OpenAI
    3) Anthropic (Claude)
    4) Nous Research
    5) Custom endpoint
```

Or open `http://127.0.0.1:8318` in your browser for the web-based config UI.

### Configuration

The setup wizard creates `config.json`:

```json
{
    "provider": "openrouter",
    "model": "openrouter/nous-hermes",
    "api_key": "sk-or-...",
    "temperature": 0.7,
    "terminal": {
        "backend": "local",
        "timeout_ms": 30000
    },
    "memory": {
        "enabled": true,
        "nudge_interval": 10
    },
    "security": {
        "command_approval": true,
        "injection_scanning": true
    }
}
```

### CLI Commands

| Command | Description |
|---------|-------------|
| `/setup` | Re-run setup wizard |
| `/model` | Switch model |
| `/config` | Show current configuration |
| `/tools` | List available tools |
| `/new` | Start new conversation |
| `/help` | Show all commands |
| `/quit` | Exit |

### Chat

Just type a message and press Enter:

```
hermes> Write a Python script that fetches weather data

⚡ Agent: [streaming response...]
```

## Tools (50+)

| Category | Tools |
|----------|-------|
| Terminal | `terminal` — Execute shell commands |
| Files | `read_file`, `write_file`, `patch`, `search_files` |
| Web | `web_search`, `web_extract` |
| Browser | `browser_navigate`, `browser_click`, `browser_type`, `browser_scroll`, `browser_snapshot`, and more |
| Code | `execute_code` |
| Media | `image_generate`, `text_to_speech`, `vision_analyze`, `transcription` |
| Memory | `memory`, `session_search` |
| Skills | `skills_list`, `skill_view`, `skill_manage` |
| Smart Home | `ha_list_entities`, `ha_get_state`, `ha_call_service`, `ha_list_services` |
| Productivity | `todo`, `cronjob`, `delegate_task`, `send_message`, `clarify` |
| Process | `process`, `checkpoint` |
| AI | `mixture_of_agents`, `honcho_context`, `honcho_profile` |
| RL | `rl_start_training`, `rl_stop_training`, `rl_check_status`, and more |

## Providers

| Provider | Config Value | Models |
|----------|-------------|--------|
| OpenRouter | `openrouter` | 200+ models via openrouter.ai |
| OpenAI | `openai` | gpt-4o, gpt-4o-mini, o1-preview |
| Anthropic | `anthropic` | claude-sonnet-4, claude-haiku-3.5 |
| Nous Research | `nous` | hermes-3-llama-3.1-405b |
| Custom | `custom` | Any OpenAI-compatible endpoint |

## Web Config UI

Open `http://127.0.0.1:8318` after starting hermes-zig:

- Select provider and model (with suggestions or free text input)
- Enter API key (with show/hide toggle)
- Configure tools, terminal backend, memory, security
- Save configuration
- Test API connection

## Building

Requires [Zig 0.15.2](https://ziglang.org/download/):

```bash
zig build              # Debug build
zig build -Doptimize=ReleaseSmall  # Release build
zig build test         # Run tests
```

Cross-compile:

```bash
zig build -Dtarget=aarch64-linux-musl -Doptimize=ReleaseSmall
zig build -Dtarget=x86_64-windows -Doptimize=ReleaseSmall
zig build -Dtarget=aarch64-macos -Doptimize=ReleaseSmall
```

SQLite is vendored (no system dependency needed).

## Architecture

```
src/
├── main.zig           Entry point, CLI loop, setup wizard
├── web_server.zig     Web config UI server (port 8318)
├── web_config.html    Embedded config UI (@embedFile)
├── core/              Types, config, SQLite, FTS5 search
├── llm/               LlmClient (vtable), OpenAI-compat, Anthropic, SSE
├── tools/             50+ tools (comptime makeToolHandler), 7 terminal backends, MCP
├── agent/             Agent loop, prompt builder, context compressor, credential pool
├── interface/         CLI (TUI, commands), Gateway (14 platforms), ACP
├── intelligence/      Skills, memory, cron scheduler, Honcho
└── security/          Approval, injection scanning, path safety, env filter
```

## License

MIT
