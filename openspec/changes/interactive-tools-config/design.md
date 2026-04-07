## Context

Hermes now has:
- truthful slash discovery,
- a vertical slash command menu,
- real `/model` switching,
- session-scoped skill activation.

The `/tools` command is lagging behind. The config model already contains a `tools` section, but the CLI does not expose an actual management workflow and the runtime registry is not rebuilt from user-driven tool toggles. This change closes that gap.

## Goals / Non-Goals

**Goals:**
- Make `/tools` show the actual effective enabled/disabled state.
- Allow users to enable or disable tools interactively in terminals that support it.
- Persist tool changes to config.
- Rebuild the active runtime tool registry after a change so the effect is immediate.
- Preserve a textual fallback path when interactive UI is unavailable.

**Non-Goals:**
- Introducing new tools.
- Adding marketplace or remote tool installation.
- Replacing the entire tool registry architecture.
- Editing every toolset dimension at once beyond what is required for truthful tool toggling.

## Decisions

### Decision 1: `/tools` is the primary tool management command

Users already discover `/tools` from the command menu and expect it to be useful. The command should become the single primary entrypoint for:
- listing effective tool state,
- toggling tools interactively when possible,
- printing textual state in fallback mode.

Alternatives considered:
- Keep `/tools` informational and move real behavior to `/tools config`.
  Rejected because it creates an unnecessary split and leaves the primary command misleading.

### Decision 2: Persist tool state through `disabled_tools` first

The config schema already provides `tools.disabled_tools`. The simplest truthful implementation is:
- compute effective tools from the baseline/default surface,
- subtract explicitly disabled tools,
- persist toggles by updating `disabled_tools`.

This avoids a larger redesign around fully editable toolset bundles in the first iteration.

Alternatives considered:
- Model the first version around full `enabled_toolsets` editing.
  Rejected because it introduces precedence and UX complexity that is not necessary to make `/tools` real.

### Decision 3: Runtime tool registry must be rebuilt from shared logic

When tools are changed, the process should not hand-edit the registry in one-off code. Instead, there should be a shared path that:
1. reads the current config,
2. determines the effective enabled tools,
3. constructs or refreshes the runtime registry from that result.

Alternatives considered:
- Mutate the registry incrementally in place.
  Rejected because it is harder to reason about and easier to drift from startup behavior.

### Decision 4: Interactive tool toggling reuses menu semantics already established

The existing interactive selector patterns in the CLI should be reused:
- Up/Down to navigate
- Enter or a direct toggle key to change state
- Esc to exit without extra mutation

The UI should emphasize state visibility first: whether a tool is currently enabled or disabled.

Alternatives considered:
- Build a separate full-screen TUI for tools.
  Rejected because it is too large a change relative to the current need.

### Decision 5: Unknown tools and unsupported states fail explicitly

If a tool name is unknown or a requested operation cannot be applied, the CLI should say so clearly and avoid mutating config. This is required to keep `/tools` trustworthy.

Alternatives considered:
- Silently ignore unknown tool names.
  Rejected because it makes configuration debugging difficult.

## Risks / Trade-offs

- Runtime registry refresh can drift from startup construction if not centralized → Mitigation: extract one shared “build tool registry from config” helper.
- The initial persisted model using `disabled_tools` may not express every future configuration case → Mitigation: treat this as the first truthful version and defer richer multi-toolset editing to a future change.
- Interactive toggling for a long tool list can become cluttered → Mitigation: reuse bounded selector viewport behavior.

## Migration Plan

1. Define effective tool-state computation from config.
2. Upgrade `/tools` to show real state.
3. Add interactive toggling and fallback text mode.
4. Persist changes and refresh the runtime registry.
5. Add tests and docs.

Rollback strategy:
- Preserve persisted config changes but temporarily disable live registry refresh if instability is found.
- Fall back to textual `/tools` display if the interactive path proves too brittle.

## Open Questions

- Whether `/tools config` should remain as a visible alias to the same workflow can be decided during implementation.
