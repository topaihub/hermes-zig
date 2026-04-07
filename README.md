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

#### Config File Location

| OS | Path |
|----|------|
| Linux | `./config.json` (current directory) or `~/.hermes/config.json` |
| macOS | `./config.json` (current directory) or `~/.hermes/config.json` |
| Windows | `.\config.json` (current directory) or `%USERPROFILE%\.hermes\config.json` |

hermes-zig looks for `config.json` in the **current working directory** first. If not found, it starts the setup wizard.

A full example is provided in [`config.example.json`](config.example.json). Copy it to get started:

```bash
cp config.example.json config.json
nano config.json  # Edit with your API key
```

#### Data Directory

| OS | Path | Contents |
|----|------|----------|
| Linux | `~/.hermes/` | state.db, SOUL.md, MEMORY.md, skills/ |
| macOS | `~/.hermes/` | state.db, SOUL.md, MEMORY.md, skills/ |
| Windows | `%USERPROFILE%\.hermes\` | state.db, SOUL.md, MEMORY.md, skills\ |

Override with `HERMES_HOME` environment variable.

#### Config Example

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
| `/model` | Open the interactive model selector when supported, or show current/available models |
| `/config` | Show current configuration |
| `/tools` | Open interactive tool toggler or show effective tool state |
| `/skills` | Open interactive skill menu or show installed skill state |
| `/skills view <name>` | View a skill |
| `/skills use <name>` | Activate one skill for the current session |
| `/skills clear` | Clear the active skill |
| `/new` | Start new conversation |
| `/help` | Show all commands |
| `/quit` | Exit |

### Slash Discovery

When the terminal supports interactive input:

- Type `/` to show available slash commands
- Keep typing to filter matching commands
- Use `Up` / `Down` to move through suggestions
- Press `Tab` to complete the selected command
- Press `Esc` to dismiss suggestions without submitting

If the terminal does not support interactive input, hermes-zig automatically falls back to the original line-mode command entry.

### Interactive Model Switching

When interactive input is available and `config.json` contains a `models` list, `/model` opens an in-terminal selector:

- Use `Up` / `Down` to move between configured models
- Press `Enter` to confirm the selected model
- Press `Esc` to cancel without changing the current model

You can still switch directly by name:

```text
/model gpt-5.3-codex
```

If interactive input is unavailable, `/model` falls back to printing the current model and configured choices.

### Interactive Tool Switching

`/tools` now reflects the real effective tool state for the current config.

When interactive input is available:

- `/tools` opens a tool toggler
- Use `Up` / `Down` to move between tools
- Press `Enter` to enable or disable the selected tool
- Press `Esc` to exit the tool menu

When interactive input is unavailable, or when you want an explicit textual flow:

```text
/tools list
/tools disable todo
/tools enable todo
```

Changes are written back to `config.json` and the current process refreshes its runtime tool registry immediately.

### Interactive Skills Menu

`/skills` now acts as the primary session-skill entrypoint.

When interactive input is available and installed skills exist:

- `/skills` opens a skill menu
- Use `Up` / `Down` to move between installed skills
- Press `Enter` to activate the selected skill for the current session
- When a skill is already active, the menu also includes a clear action
- Press `Esc` to exit without further changes

When interactive input is unavailable, `/skills` falls back to textual state output and keeps these direct commands available:

```text
/skills view poetry-helper
/skills use poetry-helper
/skills clear
```

### Chat

Just type a message and press Enter:

```
hermes> Write a Python script that fetches weather data

⚡ Agent: [streaming response...]
```

### Skills

Install skills under your Hermes home directory:

- Linux/macOS: `~/.hermes/skills/<skill-name>/SKILL.md`
- Windows: `%USERPROFILE%\\.hermes\\skills\\<skill-name>\\SKILL.md`

Or set `HERMES_HOME` and place skills under `<HERMES_HOME>/skills/`.

Example session:

```text
hermes> /skills
hermes> /skills use poetry-helper
hermes> 写一首七言绝句，题目为《春夜》
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
