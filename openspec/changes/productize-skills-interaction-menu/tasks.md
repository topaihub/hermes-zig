## 1. Menu Behavior

- [x] 1.1 Define the interactive `/skills` menu entries and active-skill marker behavior.
- [x] 1.2 Reuse the existing selector primitive for skill choice and clear-session action.

## 2. Session Skill Actions

- [x] 2.1 Activate the selected skill through the existing session activation path.
- [x] 2.2 Expose a clear-active-skill action in the interactive flow.
- [x] 2.3 Preserve `/skills view <name>`, `/skills use <name>`, and `/skills clear` direct commands.

## 3. Fallback And Empty States

- [x] 3.1 Preserve readable textual `/skills` output for non-interactive terminals.
- [x] 3.2 Show explicit guidance when no installed skills are available.

## 4. Verification And Docs

- [x] 4.1 Add tests for interactive selection state, clear behavior, fallback output, and empty-state guidance.
- [x] 4.2 Update help and README text to describe the new `/skills` interaction model.
