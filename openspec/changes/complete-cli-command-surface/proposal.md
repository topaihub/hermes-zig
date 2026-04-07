## Why

The CLI now has a stronger interaction foundation, but the command surface is still uneven: some commands are fully usable, some are informational only, and some still behave like placeholders. This creates a mismatch between what the slash menu suggests, what `/help` advertises, and what users can actually accomplish in-session. To align Hermes with the reference quality level, the CLI command surface must be made consistently real, stateful, and user-facing.

## What Changes

- Audit the existing slash command surface and classify every command as supported, removed, or deferred.
- Make supported commands truly operational rather than informational placeholders.
- Ensure command execution, slash discovery, `/help`, and README all reflect the same real command set.
- Implement actual model switching behavior for `/model`, including config persistence and live runtime refresh.
- Improve skills, tools, and related command flows so they return actionable output rather than placeholder text.
- Remove or hide commands from discovery/help if they are not actually implemented in this release.

## Capabilities

### New Capabilities
- `cli-command-parity`: A single, truthful CLI command surface where discoverable commands are executable and stateful.
- `live-model-switching`: Runtime model switching with config persistence and in-session effect.

### Modified Capabilities
- `cli-command-discovery`: Restrict discovery to commands that are actually supported and keep discovery output synchronized with runtime execution behavior.
- `skill-session-activation`: Improve command ergonomics and error handling as part of the unified command surface.

## Impact

- `src/interface/cli/commands.zig`: Becomes the authoritative command registry with support status and richer metadata.
- `src/main.zig`: Replace remaining placeholder command branches with real handlers or remove them from the active surface.
- `src/interface/cli/*`: Add missing command handlers or refine existing ones so command UX is consistent.
- `src/llm/runtime_provider.zig` and runtime config flow: Support re-resolving the active provider/model after `/model` changes.
- `README.md`: Document only commands that are actually usable.
