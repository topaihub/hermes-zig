## ADDED Requirements

### Requirement: Slash commands are discoverable during input

The CLI SHALL present slash-command suggestions while the user is composing input that starts with `/`, without requiring the user to press Enter first.

#### Scenario: Slash prefix opens command suggestions
- **WHEN** the user enters `/` at the CLI prompt
- **THEN** the CLI shows the available slash commands
- **AND** the input remains editable without executing a command

### Requirement: Slash suggestions filter by typed prefix

The CLI SHALL filter slash-command suggestions based on the currently typed command prefix.

#### Scenario: Prefix narrows the command list
- **WHEN** the user types a slash-command prefix such as `/mo`
- **THEN** the CLI limits the suggestion list to commands matching that prefix
- **AND** non-matching commands are not shown in the active suggestion list

### Requirement: Slash suggestions reflect executable commands

The CLI SHALL derive slash-command suggestions from the same command definitions used for slash-command execution.

#### Scenario: Suggested command can be executed directly
- **WHEN** the CLI shows a slash command in the suggestion list
- **THEN** submitting that completed command executes the corresponding runtime command handler
- **AND** the suggestion list does not contain commands that lack runtime handling

### Requirement: Slash suggestions support keyboard selection and completion

The CLI SHALL allow users to navigate suggestions and complete the selected command from the keyboard.

#### Scenario: Tab completes the selected slash command
- **WHEN** the user has an active slash-command suggestion selected
- **AND** the user presses Tab
- **THEN** the CLI updates the input buffer to the selected full slash command

#### Scenario: Arrow keys move between slash suggestions
- **WHEN** the slash-command suggestion list is visible
- **AND** the user presses the up or down arrow key
- **THEN** the selected suggestion changes accordingly
- **AND** the input buffer is not submitted

#### Scenario: Escape dismisses slash suggestions
- **WHEN** the slash-command suggestion list is visible
- **AND** the user presses Escape
- **THEN** the suggestion list closes
- **AND** the current input buffer remains editable without being submitted

### Requirement: Slash suggestion visibility tracks slash-command mode

The CLI SHALL only show slash suggestions while the current input remains in slash-command mode.

#### Scenario: Leaving slash-command mode hides suggestions
- **WHEN** the user edits the input so it no longer starts with `/`
- **THEN** the slash-command suggestion list is hidden
- **AND** the input continues in normal chat-entry mode

### Requirement: Slash discovery degrades safely

The CLI SHALL preserve current slash-command execution behavior even if interactive discovery is unavailable or dismissed.

#### Scenario: Enter still executes the typed slash command
- **WHEN** the user types a valid slash command and presses Enter
- **THEN** the corresponding slash-command handler executes
- **AND** this behavior does not depend on the suggestion list being visible

#### Scenario: Unsupported terminal falls back to line-mode input
- **WHEN** the terminal cannot support the interactive slash discovery mode
- **THEN** the CLI continues to accept slash commands through line-mode input
- **AND** the user can still execute commands after pressing Enter
