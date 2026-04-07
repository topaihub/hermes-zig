## Context

Hermes now has:
- a unified slash command registry,
- interactive slash discovery,
- session-scoped skill activation,
- a more robust prompt construction path.

However, the command surface still mixes fully implemented commands with partial or placeholder behavior. The most obvious example is `/model`, which currently reports state but does not truly persist and reload the selected model in a complete user-facing way. Similar gaps exist anywhere the CLI advertises capability beyond what runtime behavior actually guarantees.

This change is about product parity and command-surface truthfulness, not terminal rendering primitives.

## Goals / Non-Goals

**Goals:**
- Ensure every command exposed in slash discovery and `/help` is genuinely usable.
- Remove, hide, or defer commands that remain incomplete.
- Implement real `/model` switching with config persistence and runtime refresh.
- Keep command behavior consistent across execution, slash discovery, help text, and docs.
- Improve command handlers that currently return placeholder or low-value output when that behavior blocks real usage.

**Non-Goals:**
- Introducing a large new command set.
- Reworking provider APIs beyond what live model switching requires.
- Replacing the recently added slash input controller.
- Marketplace-grade `/hub` implementation in this change if it remains out of scope.

## Decisions

### Decision 1: The command registry must carry support truth, not just display metadata

`commands.zig` should be the authoritative registry for the interactive CLI surface. Each exposed command should map to a real supported handler path. Commands that are not truly supported should be removed from the primary discoverable surface until implemented.

Alternatives considered:
- Keep placeholder commands visible and rely on “not yet implemented” responses.
  Rejected because it undermines user trust and defeats the purpose of command discovery.

### Decision 2: `/model` is the priority command to make fully stateful

The CLI must support a complete `/model` flow:
- list configured models,
- choose a new model,
- persist it to config,
- update in-memory runtime state so the next turn uses it.

This is the most visible command-surface gap today and a strong indicator of whether the CLI feels real.

Alternatives considered:
- Leave `/model` informational until a larger runtime refactor.
  Rejected because the current user expectation is explicit and the command is already exposed.

### Decision 3: Runtime config updates must have an explicit refresh path

When a command changes configuration that affects active runtime behavior, the process must define whether the change:
- applies immediately to the current session,
- applies only to future sessions,
- or requires an explicit reload.

For `/model`, the target behavior should be immediate effect for subsequent turns in the current process.

Alternatives considered:
- Write config only and require restart.
  Rejected unless clearly documented; it would feel broken for an interactive `/model` command.

### Decision 4: Placeholder outputs should be either upgraded or removed from the discoverable surface

Commands that still produce static placeholder text must be reviewed. If they cannot be made real in this change, they should be removed from help/discovery rather than remain misleading.

Alternatives considered:
- Keep placeholders for future discoverability.
  Rejected because the current objective is parity and truthfulness, not roadmap visibility.

## Risks / Trade-offs

- Tightening the command surface may temporarily reduce the number of visible commands → Mitigation: prioritize correctness over breadth and document deferred commands separately.
- Live `/model` switching can introduce runtime state bugs if config persistence and provider refresh diverge → Mitigation: define a single update path that writes config and refreshes runtime together.
- Some commands may require deeper refactors than expected → Mitigation: explicitly defer them from the active surface rather than shipping another placeholder.

## Migration Plan

1. Audit the command registry against real handlers.
2. Implement full `/model` switching and persistence.
3. Upgrade or remove any remaining placeholder command flows included in the active surface.
4. Align slash discovery, `/help`, and README with the actual supported command set.
5. Verify behavior end-to-end in the built executable.

Rollback strategy:
- Restore the prior command exposure list if a new handler path proves unstable.
- Disable immediate runtime refresh for `/model` if persistence is correct but hot reload is not yet safe.

## Open Questions

- Whether `/model` should support interactive menu selection in addition to `/model <name>` can be decided during implementation, but at minimum the command must become truthful and stateful.
