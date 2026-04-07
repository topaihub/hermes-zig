## Why

Hermes already has truthful slash discovery, session-scoped skill activation, and direct commands such as `/skills use <name>` and `/skills clear`. The remaining gap is discoverability and flow: `/skills` still behaves like a text dump instead of a productized command surface. Users should be able to enter `/skills`, see installed skills, identify the active skill, and activate or clear session skill state without memorizing subcommands.

## What Changes

- Upgrade `/skills` so it opens an interactive skill menu when the terminal supports interactive input.
- Surface installed skills, the current active skill, and a clear-session action in one flow.
- Preserve `/skills view <name>`, `/skills use <name>`, and `/skills clear` as direct command paths.
- Keep a readable textual fallback for non-interactive terminals.
- Keep the current single-active-skill session model intact.

## Capabilities

### New Capabilities
- `interactive-skills-menu`: In-terminal skill discovery and activation for installed session skills.

### Modified Capabilities
- `skill-session-activation`: Extend the existing skill runtime so `/skills` itself becomes the primary interactive entrypoint, not just a textual listing.

## Impact

- `src/main.zig`: Route `/skills` into an interactive menu flow when available.
- `src/interface/cli/input_controller.zig` and/or shared CLI menu primitives: Reuse existing selector behavior for skill choice.
- `src/interface/cli/skills_runtime.zig`: Expose the data needed to render skill list state cleanly.
- `src/interface/cli/commands.zig`: Keep `/skills` help text aligned with the upgraded interaction.
- `README.md`: Document interactive and fallback skill usage.
