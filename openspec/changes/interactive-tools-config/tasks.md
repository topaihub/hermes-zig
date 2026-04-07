## 1. Effective Tool State

- [x] 1.1 Define how effective enabled and disabled tool state is computed from existing config fields.
- [x] 1.2 Add a shared helper for building the runtime tool registry from current config.

## 2. `/tools` Real Behavior

- [x] 2.1 Replace the static `/tools` output with real effective tool-state reporting.
- [x] 2.2 Preserve a readable textual fallback for non-interactive terminals.

## 3. Interactive Tool Toggling

- [x] 3.1 Reuse the interactive selector pattern for tool configuration.
- [x] 3.2 Implement enable/disable toggling and state confirmation in the interactive flow.
- [x] 3.3 Reject unknown tool names without mutating config.

## 4. Persistence And Runtime Refresh

- [x] 4.1 Persist tool state changes back to config.
- [x] 4.2 Refresh the current process tool registry so future turns use the new tool set.

## 5. Verification And Docs

- [x] 5.1 Add tests for effective tool state, toggling, unknown tool rejection, and runtime refresh behavior.
- [x] 5.2 Update help and README documentation for the new `/tools` behavior.
