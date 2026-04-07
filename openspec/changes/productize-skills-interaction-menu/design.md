## Context

Hermes now supports:
- truthful slash discovery,
- vertical command menus,
- real `/model` switching,
- interactive `/tools`,
- single active skill injection per session.

The remaining UX gap is that `/skills` is still mostly command-line syntax driven. Users can manage skills if they already know `/skills view`, `/skills use`, and `/skills clear`, but the primary `/skills` command does not yet feel like a first-class interactive surface.

## Goals / Non-Goals

**Goals:**
- Make `/skills` open an interactive skills menu when possible.
- Show installed skills and clearly mark the current active skill.
- Allow activation and session clear from the interactive flow.
- Preserve textual fallback and direct subcommands.
- Keep the current single-active-skill model unchanged.

**Non-Goals:**
- Adding multi-skill activation.
- Implementing automatic skill triggering.
- Building a full-screen TUI dedicated to skills.
- Adding remote installation or marketplace flows.

## Decisions

### Decision 1: `/skills` becomes the primary interactive entrypoint

If interactive input is available, `/skills` should open a menu instead of only printing text. This keeps the top-level command aligned with the upgraded CLI interaction model.

Alternatives considered:
- Keep `/skills` textual and introduce a separate `/skills menu` command.
  Rejected because it splits discovery across two surfaces.

### Decision 2: The interactive flow remains explicit and session-scoped

Selecting a skill from the menu activates that skill for the current session only. A dedicated clear action is shown when a skill is active. This keeps the existing prompt-injection model predictable.

Alternatives considered:
- Make activation global or persistent across sessions.
  Rejected because the current design is explicitly session-scoped.

### Decision 3: Reuse the existing selector primitive

The same selector semantics already established elsewhere should be reused:
- Up/Down to navigate,
- Enter to confirm activation,
- Escape to cancel and exit.

Alternatives considered:
- Create a dedicated skills-specific renderer with separate key handling.
  Rejected because it duplicates interaction behavior and increases maintenance cost.

### Decision 4: Viewing full skill bodies remains a direct command for the first iteration

The interactive `/skills` menu should focus on discovery, activation, and clear-session state. Rich body inspection can continue to live behind `/skills view <name>` in the first version.

Alternatives considered:
- Add a nested body viewer inside the menu immediately.
  Rejected because it expands scope without being required to make `/skills` first-class.

## Risks / Trade-offs

- A long skills list can become crowded in a small terminal.
  Mitigation: reuse the existing viewport-limited selector behavior.
- Users may expect body preview directly inside the interactive menu.
  Mitigation: keep `/skills view <name>` documented and consider preview as a future enhancement.
- Single-skill activation may feel restrictive for advanced users.
  Mitigation: keep this change aligned with the existing single-active-skill session model and defer multi-skill composition to a future proposal.

## Migration Plan

1. Define the interactive `/skills` behavior and menu contents.
2. Reuse the selector primitive for installed skill choice and clear action.
3. Preserve fallback text output and direct subcommands.
4. Add tests and docs.

Rollback strategy:
- Revert `/skills` to textual listing while keeping the existing direct commands and session activation model.

## Open Questions

- Whether the menu should eventually show short descriptions inline or only mark the active skill can be decided during implementation.
