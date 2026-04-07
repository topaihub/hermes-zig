## Why

`/model` now truthfully lists configured model choices and supports direct switching with `/model <name>`, but it still breaks the interaction rhythm users expect from the upgraded CLI. In the current UX, users must manually type the target model name even though the application already knows the valid configured options. An interactive model switcher would make model selection discoverable, reduce typing errors, and align `/model` with the terminal-first interaction style established by slash discovery.

## What Changes

- Upgrade `/model` so invoking it without an argument opens an interactive model selection menu instead of only printing a static list.
- Allow users to navigate configured model choices with keyboard input and confirm the selection directly from the menu.
- Preserve `/model <name>` as the direct power-user path.
- Keep invalid or empty model states understandable when no configured models are available.
- Ensure model selection UI follows the same fallback principles as the rest of the interactive CLI.

## Capabilities

### New Capabilities
- `interactive-model-switching`: Keyboard-driven in-terminal model selection and confirmation for configured model choices.

### Modified Capabilities
- `live-model-switching`: Extend the existing real model-switching flow so `/model` itself can invoke an interactive selector, not just `/model <name>`.

## Impact

- `src/main.zig`: Route `/model` without arguments into an interactive model selection flow.
- `src/interface/cli/input_controller.zig` and/or `src/interface/cli/curses_ui.zig`: Reuse or extend current menu rendering and selection behavior for model choice.
- `src/interface/cli/commands.zig`: Keep `/model` metadata aligned with its upgraded interaction model.
- `README.md`: Update model switching documentation to describe direct and interactive usage.
