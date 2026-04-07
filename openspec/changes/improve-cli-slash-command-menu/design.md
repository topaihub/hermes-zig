## Context

The current implementation added slash discovery quickly and safely by rendering suggestions inline on the prompt row. That choice proved the input controller and fallback model, but it does not scale well for readability. The next iteration should improve usability without destabilizing the terminal input foundation that was just introduced.

This change is intentionally scoped to presentation and interaction layout for slash discovery. It does not alter command execution semantics or the skill activation model.

## Goals / Non-Goals

**Goals:**
- Render slash suggestions as a vertical dropdown-style list rather than a horizontal inline strip.
- Keep the current keyboard model: filtering, Up/Down navigation, Tab completion, Esc dismissal, Enter execution.
- Show command descriptions in a readable way while keeping the prompt usable.
- Support bounded visible rows with scrolling when the match set is larger than the viewport.
- Keep fallback-to-line-mode behavior unchanged for unsupported terminals.

**Non-Goals:**
- Changing the slash command registry or command semantics.
- Adding mouse support.
- Implementing dynamic skill-name completions in this change.
- Replacing the terminal input controller again.

## Decisions

### Decision 1: Reuse the existing input controller and upgrade only the renderer

The current `input_controller.zig` already owns buffer state, suggestion indices, completion, dismissal, and history traversal. This change should keep that controller and evolve the rendering/output model rather than replacing the state machine.

Alternatives considered:
- Rewrite the input controller around a different TUI abstraction.
  Rejected because it would reopen input correctness risks for a mostly presentational improvement.

### Decision 2: The dropdown uses a bounded vertical viewport

The command menu should display a fixed maximum number of rows, such as 5 to 8 visible items, with the selected item always kept inside the viewport. When the filtered results exceed the viewport, Up/Down should scroll the window.

Alternatives considered:
- Render the full filtered list every time.
  Rejected because terminal height is limited and long command sets would cause redraw noise.

### Decision 3: The selected row includes the most important description

Each visible row should prioritize command literal readability. A short summary should be shown either inline on the same row or as a companion line for the selected item only, depending on layout constraints. The chosen rendering must remain stable on narrow Windows terminals.

Alternatives considered:
- Show no descriptions.
  Rejected because the menu then improves scanning only marginally over the current implementation.
- Show descriptions for every row in full.
  Rejected because the dropdown would become too tall and noisy.

### Decision 4: Prompt redraw tracks menu height explicitly

Because the dropdown occupies multiple lines, the renderer must know how many lines were previously drawn so it can clear and repaint the menu without leaving stale rows behind.

Alternatives considered:
- Rely on clearing only the current prompt line.
  Rejected because stale suggestion rows would remain after filtering or dismissal.

## Risks / Trade-offs

- Multi-line redraw can flicker on some Windows terminals → Mitigation: keep the menu small, repaint only the active block, and test on the current supported console path.
- Terminal width may truncate descriptions → Mitigation: prefer short summaries and clamp rendering width conservatively.
- A more complex renderer can introduce stale-row bugs → Mitigation: track previously rendered line count and add focused tests around shrinking/expanding match sets.

## Migration Plan

1. Extend the input controller state to track viewport position and previously rendered menu height.
2. Replace the inline renderer with a vertical dropdown renderer.
3. Add scrolling behavior for filtered lists longer than the viewport.
4. Update prompt/help documentation.
5. Verify behavior in interactive Windows console mode and fallback mode.

Rollback strategy:
- Restore the prior inline suggestion renderer while preserving the underlying input controller.

## Open Questions

- Whether descriptions should be shown on every visible row or only for the selected row should be finalized during implementation based on terminal width behavior.
