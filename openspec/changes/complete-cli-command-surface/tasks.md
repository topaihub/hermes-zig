## 1. Command Surface Audit

- [x] 1.1 Audit every slash command currently exposed by discovery and `/help` against its real runtime handler.
- [x] 1.2 Remove or defer commands from the active command registry if they still resolve to placeholder behavior.
- [x] 1.3 Align help text, discovery metadata, and runtime command coverage to the same authoritative command registry.

## 2. Real `/model` Switching

- [x] 2.1 Implement `/model` list behavior so it reports the current model and configured model choices clearly.
- [x] 2.2 Implement `/model <name>` validation against configured model choices.
- [x] 2.3 Persist successful model changes back to config.
- [x] 2.4 Refresh in-memory runtime state so subsequent chat turns use the new model without restarting the process.

## 3. Placeholder Command Cleanup

- [x] 3.1 Review remaining command handlers for placeholder-only behavior.
- [x] 3.2 Upgrade any command included in the active surface to real usable output where feasible.
- [x] 3.3 Remove deferred commands from user-facing discovery/help when real implementation is not included in this release.

## 4. Verification And Documentation

- [x] 4.1 Add tests covering `/model` listing, successful switch, invalid switch, and runtime refresh behavior.
- [x] 4.2 Add tests ensuring user-facing command discovery/help do not expose unsupported placeholder commands.
- [x] 4.3 Update README and command help documentation to reflect the truthful supported command surface.
