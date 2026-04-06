## Context

The current CLI loop in `src/main.zig` reads one full line at a time with `readLine`, so it cannot react when the user types `/`, presses Tab, or navigates suggestions with arrow keys. Separately, the repository already contains a skills directory convention, a `skills_loader`, and placeholder `/skills` messaging, but the active chat path never loads skills or gives the user a supported way to apply one to a session.

This change crosses the CLI interaction layer, runtime skill loading, and prompt construction, so a design document is warranted before implementation.

## Goals / Non-Goals

**Goals:**
- Provide immediate slash-command discovery when the input buffer begins with `/`.
- Support command filtering, selection, and Tab completion without breaking current Enter-to-submit behavior.
- Load installed skills from the resolved skills directory on demand.
- Let the user explicitly activate one skill for the current session and have that skill affect subsequent model turns.
- Make `/skills` a real operational command instead of a placeholder message.
- Keep the interactive input layer safe on Windows and degrade cleanly to line-mode behavior if the terminal cannot support the richer flow.

**Non-Goals:**
- Automatic skill triggering from free-form heuristics in this change.
- Marketplace installation or `/hub` networking improvements.
- Full shell-grade line editing parity with mature readline implementations.
- Rich mouse-driven UI or multi-pane TUI work.

## Decisions

### Decision 1: Introduce a lightweight interactive input controller instead of keeping `readLine`

The current `readLine` loop cannot support real-time slash discovery. The CLI should move to a key-aware input controller that owns:
- the current buffer,
- cursor position,
- whether slash discovery is active,
- the filtered command list,
- the selected suggestion index,
- history traversal hooks.

This should live under `src/interface/cli/` rather than staying embedded in `main.zig`, so the interaction logic remains testable and reusable.

Alternatives considered:
- Keep `readLine` and print a static hint when the user types `/`.
  Rejected because it still requires Enter before feedback and does not deliver actual completion.
- Pull in a full external line-editing dependency.
  Rejected because the project is currently a single-binary Zig app and this scope does not require that level of complexity.

### Decision 2: Command discovery operates on the existing slash-command set first

The new discovery UI should autocomplete a single slash-command registry that is also used by command execution. The current repo has overlapping command definitions in `main.zig` and `interface/cli/commands.zig`; this change should consolidate them so the discovery list is the authoritative runtime command surface.

Alternatives considered:
- Continue with two parallel command definitions and let the suggestion layer manually mirror `main.zig`.
  Rejected because the completion list would drift from executable behavior almost immediately.

### Decision 3: The input controller must provide a terminal fallback path

Interactive slash discovery requires key-aware input, but terminal capabilities vary across Windows consoles and redirection scenarios. The controller should attempt richer interactive behavior only when the terminal supports it, and otherwise fall back to the current line-based submission path.

While interactive mode is active, slash discovery visibility should be deterministic:
- the suggestion list appears only while the current buffer is in slash-command mode,
- it closes when the buffer no longer represents a slash command,
- it can be explicitly dismissed without submitting the current input.

Alternatives considered:
- Assume all supported consoles can handle the richer mode.
  Rejected because the current project already has Windows-specific console issues and this would make the CLI brittle.

### Decision 4: Skills are explicitly activated per session and limited to one active skill

Skills should be loaded from disk and selectable through explicit user action, e.g. `/skills use <name>` and `/skills clear`. Exactly one skill should be active at a time in the first version; activating a new skill replaces the previous active skill. The active skill body should affect subsequent model turns in that session.

Explicit single-skill activation is chosen because current `SKILL.md` parsing only guarantees `name`, `description`, and body. There is no robust trigger schema in place yet, and multiple simultaneous skills would create ordering and conflict-resolution problems not worth solving in this change.

Alternatives considered:
- Automatically activate skills by fuzzy matching user prompts.
  Rejected because current metadata is insufficient and false positives would be hard to control.
- Support multiple active skills in the first version.
  Rejected because prompt ordering, conflict handling, and UI visibility would all become ambiguous.
- Always inject all installed skills into the prompt.
  Rejected because prompt bloat and conflicting instructions would quickly degrade model behavior.

### Decision 5: Skill runtime state is session-scoped and separate from installed-skill inventory

The runtime should distinguish:
- installed skills discovered on disk, and
- the single active skill applied to the current conversation.

This allows `/skills` to list installed inventory while only the selected skill influences the prompt. It also preserves the ability to start a new session with a clean skill slate.
The CLI should also define explicit empty and error states:
- if no skills are installed, `/skills list` should return a clear empty-state message,
- if the user references a missing skill in `/skills view` or `/skills use`, the command should fail without altering session state.

Alternatives considered:
- Global activation persisted across all sessions.
  Rejected because it creates hidden state and makes debugging agent behavior harder.

### Decision 6: Active skill injection is applied per request without mutating stored history

Activated skill instructions should be merged into the request-time system context in a single prompt-construction path, preferably near `agent/prompt_builder.zig` or another dedicated prompt assembly point. The active skill should not be written into the persisted conversation history or retroactively modify the stored base system message; instead, each outbound model request should be assembled from:
- the base system prompt,
- the currently active skill body, when present,
- the conversation messages.

Alternatives considered:
- Mutate the stored system message in conversation history whenever the active skill changes.
  Rejected because it couples session state to historical transcript mutation and makes clearing or switching skills error-prone.
- Inject skill text ad hoc in `main.zig` before every call.
  Rejected because it couples prompt concerns to CLI orchestration and makes future interfaces harder to support.

## Risks / Trade-offs

- Interactive terminal input differs across Windows terminals and shells → Mitigation: keep a conservative key-handling surface, explicitly support fallback to line-mode input, and verify on Windows console paths first.
- Slash discovery may complicate command history behavior → Mitigation: isolate history traversal inside the input controller and add focused tests around mixed slash/chat flows.
- Injecting skill text can create prompt bloat or conflicting instructions → Mitigation: require explicit activation, limit the first version to one active skill, support clearing the active skill, and log the active skill name in debug traces.
- Skill parsing is intentionally lightweight today → Mitigation: scope this change to explicit activation and leave automatic trigger metadata for a future change.

## Migration Plan

1. Add the new CLI input controller and wire it into `main.zig`.
2. Consolidate slash command definitions into one runtime registry and implement discovery against that registry.
3. Load installed skills and add `/skills list`, `/skills view`, `/skills use`, and `/skills clear`.
4. Inject the active skill body into per-request system context without mutating stored conversation history.
5. Update help text, fallback behavior, and verification coverage.

Rollback strategy:
- Revert the input controller wiring to the prior line-based loop.
- Disable skill activation while preserving on-disk skills.

## Open Questions

- Should slash discovery also surface dynamic entries such as installed skill names after `/skills use `? This is desirable, but may be phased after the base command palette if implementation complexity grows.
