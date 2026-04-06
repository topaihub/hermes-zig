## Why

The current CLI only parses slash commands after Enter and does not surface installed skills in a usable runtime flow. This makes command discovery poor, leaves the existing skills system effectively dormant, and blocks the workflow users now expect from an interactive agent shell.

## What Changes

- Add interactive slash-command discovery so typing `/` immediately shows available commands instead of waiting for trial-and-error.
- Add prefix filtering, keyboard navigation, and Tab completion for slash commands in the CLI prompt.
- Unify the slash-command definition used by discovery and execution so the suggested command surface matches actual runtime behavior.
- Load installed skills from the resolved skills directory (`HERMES_HOME` when set, otherwise the default `.hermes/skills` location) and expose them through a real `/skills` command flow.
- Allow users to activate, inspect, and clear one active skill for the current session so a selected skill meaningfully affects subsequent model turns.

## Capabilities

### New Capabilities
- `cli-command-discovery`: Interactive slash-command suggestion, filtering, navigation, and completion in the CLI prompt.
- `skill-session-activation`: Runtime loading of installed skills plus explicit session-scoped skill activation and clearing.

### Modified Capabilities
- None.

## Impact

- `src/main.zig`: Replace line-only slash input handling with an interactive command discovery flow and session-scoped active skill state.
- `src/interface/cli/*`: Introduce reusable input-state, command registry, suggestion rendering, and terminal fallback logic.
- `src/intelligence/skills_loader.zig`: Promote loader usage from dormant utility to active runtime path.
- `src/agent/prompt_builder.zig` and/or `src/agent/loop.zig`: Inject the active skill into per-request model-facing context without mutating stored conversation history.
- `src/tools/builtin/skills_ops.zig`: Align tool-facing and CLI-facing skill directory behavior.
