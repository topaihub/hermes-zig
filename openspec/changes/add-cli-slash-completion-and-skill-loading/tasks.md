## 1. Command Surface And Runtime Shape

- [x] 1.1 Consolidate slash-command definitions into a single runtime registry shared by discovery and execution.
- [x] 1.2 Define the runtime session state for slash suggestion UI and a single active skill.

## 2. Terminal Input Foundation

- [x] 2.1 Extract a key-aware CLI input controller from the current line-only prompt loop.
- [x] 2.2 Implement terminal capability detection and fallback to the existing line-mode path when interactive input is unsupported.
- [x] 2.3 Integrate command history traversal into the new input controller without breaking chat submission.

## 3. CLI Slash Discovery

- [x] 3.1 Implement slash-command suggestion rendering, prefix filtering, and selection state from the unified command registry.
- [x] 3.2 Implement keyboard completion behavior for Tab and suggestion navigation for arrow keys.
- [x] 3.3 Implement suggestion dismissal and slash-mode exit behavior without losing the current input buffer.
- [x] 3.4 Ensure completed suggestions always execute the same command handlers exposed in the discovery list.

## 4. Skill Runtime Integration

- [x] 4.1 Load installed skills from the resolved skills directory into runtime inventory.
- [x] 4.2 Replace the placeholder `/skills` flow with real list, view, use, and clear subcommands.
- [x] 4.3 Add single-active-skill session state that survives across turns until cleared or replaced.
- [x] 4.4 Inject the active skill body into request-time system context without mutating stored conversation history.
- [x] 4.5 Implement empty-state and not-found handling for `/skills list`, `/skills view`, and `/skills use`.
- [x] 4.6 Clear active skill state when a new session is started.

## 5. Verification And UX Polish

- [x] 5.1 Add focused tests for terminal fallback, slash discovery state transitions, and keyboard completion behavior.
- [x] 5.2 Add tests for skill loading, single-skill activation, replacement, prompt injection, and clearing behavior.
- [x] 5.3 Update help text and user-facing messaging to describe slash discovery, skill usage, and fallback behavior.
- [x] 5.4 Update repository-facing documentation for slash discovery and skill activation behavior.
