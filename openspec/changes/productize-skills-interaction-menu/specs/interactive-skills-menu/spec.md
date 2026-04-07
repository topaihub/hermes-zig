## ADDED Requirements

### Requirement: `/skills` opens an interactive menu when possible

The CLI SHALL open an interactive skills menu when the user invokes `/skills` in an interactive terminal and installed skills are available.

#### Scenario: `/skills` opens installed skill menu
- **WHEN** the user invokes `/skills`
- **AND** the terminal supports interactive input
- **AND** at least one installed skill exists
- **THEN** the CLI opens an interactive skill menu
- **AND** the active skill, if any, is visibly distinguishable

### Requirement: Interactive skill selection activates a skill for the current session

The CLI SHALL allow the user to activate one installed skill from the interactive menu.

#### Scenario: Selecting a skill activates it
- **WHEN** the interactive skills menu is open
- **AND** the user selects an installed skill and presses Enter
- **THEN** that skill becomes the active skill for the current session
- **AND** subsequent turns use that skill in prompt assembly

### Requirement: Interactive skills flow allows clearing active session skill state

The CLI SHALL allow the user to clear the active skill from the interactive skills flow.

#### Scenario: Clearing the active skill from the menu
- **WHEN** an active skill exists
- **AND** the user selects the clear action from the interactive skills flow
- **THEN** the active skill is cleared
- **AND** subsequent turns no longer include that skill in prompt assembly

### Requirement: `/skills` degrades gracefully in non-interactive terminals

The CLI SHALL keep a useful textual `/skills` behavior when interactive selection is unavailable.

#### Scenario: Non-interactive terminal falls back to text output
- **WHEN** the user invokes `/skills`
- **AND** interactive input is unavailable
- **THEN** the CLI prints installed skill state as text
- **AND** the user can still use `/skills view <name>`, `/skills use <name>`, and `/skills clear`

### Requirement: Empty skill state is explicit

The CLI SHALL clearly explain when interactive `/skills` cannot proceed because no installed skills are available.

#### Scenario: `/skills` with no installed skills shows guidance
- **WHEN** the user invokes `/skills`
- **AND** no installed skills exist
- **THEN** the CLI explains that no skills are installed
- **AND** the resolved skills directory is shown or referenced for user guidance
