## Why

The current slash discovery is functional but visually cramped: suggestions are rendered inline on the same row as the prompt, which becomes hard to scan as commands grow. Users expect a vertical command palette or dropdown that makes selection, filtering, and descriptions easier to read in a terminal workflow.

## What Changes

- Replace the current inline horizontal slash suggestion rendering with a vertical dropdown-style command menu.
- Show one selected entry at a time with clear highlight treatment and keep keyboard navigation behavior intact.
- Display command descriptions alongside or beneath the selected entry so users understand what each command does before completion.
- Limit visible rows and support scrolling when the filtered command list exceeds the display window.
- Preserve existing fallback behavior for non-interactive terminals.

## Capabilities

### New Capabilities
- `cli-command-menu-layout`: Vertical dropdown rendering for slash-command discovery with selection, descriptions, and scrolling.

### Modified Capabilities
- `cli-command-discovery`: Upgrade the visual presentation and interaction behavior of existing slash discovery without changing its core execution contract.

## Impact

- `src/interface/cli/input_controller.zig`: Replace inline suggestion rendering with multi-line dropdown rendering and scrolling behavior.
- `src/interface/cli/commands.zig`: Provide richer metadata for menu rendering where needed.
- `src/main.zig`: Ensure prompt redraw behavior remains stable when the dropdown occupies multiple lines.
- `README.md`: Document the improved slash menu behavior.
