## Context

Hermes now supports:
- truthful command discovery,
- vertical slash menus,
- real `/model <name>` switching with persistence and runtime refresh.

The remaining UX gap is that `/model` itself is still informational only. Users can see configured models, but they cannot select one directly from the command output. This change is a focused UX enhancement on top of the now-correct model-switching foundation.

## Goals / Non-Goals

**Goals:**
- Make `/model` open an interactive selector when configured model choices exist.
- Reuse existing CLI menu primitives where practical.
- Preserve `/model <name>` as a direct path.
- Keep fallback behavior sane for non-interactive terminals.

**Non-Goals:**
- Changing the underlying model persistence or provider refresh mechanism.
- Adding remote model discovery from providers.
- Building a full-screen TUI just for model switching.

## Decisions

### Decision 1: `/model` without arguments becomes a selector entrypoint in interactive mode

If the terminal supports interactive CLI mode and configured models are available, `/model` should open a small in-terminal selector rather than only printing text. In fallback mode or when configured models are missing, `/model` can continue to print the current model and available choices.

Alternatives considered:
- Replace `/model <name>` with interactive-only switching.
  Rejected because power users still benefit from direct command entry.

### Decision 2: Reuse the existing menu stack where possible

The selector should reuse the same style and key semantics already used in slash menus:
- Up/Down navigation,
- Enter confirmation,
- Escape cancellation.

Alternatives considered:
- Add a completely separate selection UI path.
  Rejected because it would duplicate rendering and interaction logic.

### Decision 3: Selection does not apply until confirmation

Moving through model options should only preview selection visually. The runtime and config should be updated only when the user confirms with Enter.

Alternatives considered:
- Apply model changes immediately on highlight movement.
  Rejected because it would create surprising side effects while navigating.

## Risks / Trade-offs

- Reusing the existing menu logic may expose layout edge cases if slash-menu assumptions are too specific → Mitigation: keep model selection as a narrow adapter over a generalized selection component.
- Non-interactive environments still need a useful `/model` experience → Mitigation: preserve the current textual list behavior when interactive mode is unavailable.

## Migration Plan

1. Extract or reuse a menu-selection primitive suitable for both slash menus and `/model`.
2. Wire `/model` to invoke the selector when interactive mode and model choices are available.
3. Keep `/model <name>` behavior unchanged.
4. Update docs and tests.

Rollback strategy:
- Keep real `/model <name>` switching and revert `/model` to the current list-only behavior if the selector proves unstable.

## Open Questions

- Whether the selector should display only model IDs or include short descriptions in the future can be deferred until richer provider metadata exists.
