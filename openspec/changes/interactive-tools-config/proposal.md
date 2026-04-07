## Why

`/tools` is still one of the last user-facing commands that behaves like a placeholder. It lists tools, but it does not let users actually decide which tools are enabled for the current configuration or session. This creates a mismatch with the rest of the CLI, which now supports real slash discovery, skills activation, and interactive model switching. Tool management should be equally real, interactive, and persistent.

## What Changes

- Turn `/tools` into a real inspection and configuration entrypoint instead of a static list.
- Show which tools are currently enabled and disabled based on actual config.
- Add interactive enable/disable toggling for tools when the terminal supports interactive selection.
- Persist tool state changes to `config.json`.
- Refresh the active runtime tool registry after a tool configuration change so future turns reflect the new tool set.
- Preserve a textual fallback path for non-interactive terminals.

## Capabilities

### New Capabilities
- `interactive-tools-configuration`: In-terminal tool selection and toggling with persisted config and live runtime refresh.

### Modified Capabilities
- `cli-command-parity`: `/tools` becomes a genuinely usable command rather than a display-only placeholder.

## Impact

- `src/main.zig`: Route `/tools` into a real tool configuration flow and rebuild the runtime registry after changes.
- `src/interface/cli/input_controller.zig`: Reuse menu-selection primitives for tool toggling where appropriate.
- `src/interface/cli/tools_config.zig`: Replace placeholder subcommands with config-backed behavior.
- `src/core/config.zig`: Use existing `tools.enabled_toolsets` and `tools.disabled_tools` fields as the persisted source of truth.
- `src/tools/registry.zig` and `src/tools/toolsets.zig`: Align runtime registry construction with configured enabled/disabled state.
- `README.md`: Document real `/tools` behavior.
