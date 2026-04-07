## ADDED Requirements

### Requirement: `/tools` reflects actual effective tool state

The CLI SHALL report the current effective enabled and disabled tool state instead of a hardcoded placeholder list.

#### Scenario: `/tools` shows real enabled and disabled state
- **WHEN** the user invokes `/tools`
- **THEN** the CLI shows tool availability based on the current config
- **AND** disabled tools are distinguishable from enabled tools

### Requirement: Interactive tool toggling is supported when possible

The CLI SHALL allow users to toggle tool availability interactively when the terminal supports interactive input.

#### Scenario: Interactive selection disables a tool
- **WHEN** the user opens the interactive `/tools` UI
- **AND** toggles an enabled tool off
- **THEN** the tool becomes disabled in config
- **AND** the CLI confirms the change

#### Scenario: Interactive selection re-enables a disabled tool
- **WHEN** the user opens the interactive `/tools` UI
- **AND** toggles a disabled tool on
- **THEN** the tool is removed from the disabled set
- **AND** the tool becomes available to future turns

### Requirement: Tool changes persist and take effect immediately

The CLI SHALL persist tool enable/disable changes and refresh runtime tool availability without restarting the process.

#### Scenario: Disabling a tool removes it from future runtime dispatch
- **WHEN** the user disables a tool
- **THEN** the updated configuration is written to disk
- **AND** future turns in the same process do not expose that tool in the effective runtime registry

### Requirement: `/tools` degrades gracefully in non-interactive terminals

The CLI SHALL provide a textual `/tools` experience when interactive selection is unavailable.

#### Scenario: Fallback mode shows textual tool state
- **WHEN** the user invokes `/tools` in a non-interactive terminal
- **THEN** the CLI prints the effective enabled and disabled tool state
- **AND** the user is not shown an interactive selector

### Requirement: Unknown tool operations fail clearly

The CLI SHALL reject attempts to toggle unknown tool names without mutating configuration.

#### Scenario: Unknown tool toggle is rejected
- **WHEN** the user attempts to enable or disable a tool name that is not part of the known tool surface
- **THEN** the CLI reports that the tool is unknown
- **AND** the configuration remains unchanged
