## ADDED Requirements

### Requirement: Installed skills are discoverable at runtime

The runtime SHALL discover installed skills from the resolved skills directory (`HERMES_HOME` when set, otherwise the default `.hermes/skills` location) and expose their metadata to the CLI.

#### Scenario: Listing installed skills returns parsed inventory
- **WHEN** the user invokes the skills listing flow
- **THEN** the CLI shows each discovered skill name
- **AND** the CLI includes the parsed description when it is available

#### Scenario: Listing skills with no installed inventory shows an empty state
- **WHEN** the user invokes the skills listing flow
- **AND** no installed skills are discovered in the resolved skills directory
- **THEN** the CLI shows a clear empty-state message
- **AND** the command does not fail

### Requirement: Users can explicitly activate a skill for the current session

The CLI SHALL allow the user to activate one installed skill for the current chat session.

#### Scenario: Activating a skill marks it active for subsequent turns
- **WHEN** the user invokes the skills activation flow for an installed skill
- **THEN** that skill becomes active for the current session
- **AND** the CLI confirms which skill was activated

#### Scenario: Activating a new skill replaces the previous active skill
- **WHEN** a skill is already active for the current session
- **AND** the user activates a different installed skill
- **THEN** the newly selected skill becomes the active session skill
- **AND** the previously active skill no longer affects subsequent model turns

#### Scenario: Activating a missing skill leaves the current session unchanged
- **WHEN** the user invokes the skills activation flow for a skill that is not installed
- **THEN** the CLI reports that the skill was not found
- **AND** the currently active skill state is unchanged

### Requirement: Active skills influence subsequent model turns

The runtime SHALL include active skill instructions in model-facing context for subsequent user turns in the same session.

#### Scenario: Active skill body is injected into the next model request
- **WHEN** a skill is active for the current session
- **AND** the user sends a new chat message
- **THEN** the model request includes the active skill instruction content
- **AND** the injected content is derived from the loaded `SKILL.md` body
- **AND** the stored conversation history is not retroactively rewritten to persist the skill body

### Requirement: Users can inspect and clear active skills

The CLI SHALL provide a way to inspect and clear active session skills.

#### Scenario: Clearing active skills removes them from session state
- **WHEN** the user invokes the skills clear flow
- **THEN** the current session no longer has an active skill
- **AND** subsequent model requests omit previously active skill instructions

#### Scenario: Viewing an installed skill shows its contents
- **WHEN** the user invokes the skills view flow for an installed skill
- **THEN** the CLI shows the selected skill's metadata and body
- **AND** the skill is not implicitly activated by viewing it

#### Scenario: Viewing a missing skill returns a not-found error
- **WHEN** the user invokes the skills view flow for a skill that is not installed
- **THEN** the CLI reports that the skill was not found
- **AND** the active session skill state is unchanged

### Requirement: Active skill state resets with a new session

The runtime SHALL clear the active skill when a new chat session is started.

#### Scenario: Starting a new session clears the active skill
- **WHEN** a skill is active for the current session
- **AND** the user starts a new session
- **THEN** the new session begins with no active skill
- **AND** subsequent model requests omit the previously active skill instructions
