## ADDED Requirements

### Requirement: `/model` opens an interactive selector when possible

The CLI SHALL open an interactive model selection menu when the user invokes `/model` without an argument in an interactive terminal and configured model choices are available.

#### Scenario: `/model` opens model selector
- **WHEN** the user invokes `/model`
- **AND** the terminal supports interactive input
- **AND** the configuration contains one or more model choices
- **THEN** the CLI opens an interactive model selection menu
- **AND** the current model is visibly identifiable in that menu

### Requirement: Interactive selection confirms model switch on Enter

The CLI SHALL apply a model change only when the user confirms the selected model.

#### Scenario: Confirming a selected model switches runtime model
- **WHEN** the interactive model selector is open
- **AND** the user selects a configured model and presses Enter
- **THEN** the CLI switches to that model
- **AND** the selected model is persisted to configuration
- **AND** subsequent turns in the same process use the newly selected model

### Requirement: Cancelling interactive model selection leaves state unchanged

The CLI SHALL allow the user to dismiss the model selector without mutating runtime or persisted configuration.

#### Scenario: Escape cancels model selection
- **WHEN** the interactive model selector is open
- **AND** the user presses Escape
- **THEN** the selector closes
- **AND** the current model remains unchanged

### Requirement: `/model` degrades gracefully when interactive selection is unavailable

The CLI SHALL preserve a useful textual `/model` experience when interactive selection cannot be used.

#### Scenario: Non-interactive terminal falls back to list output
- **WHEN** the user invokes `/model`
- **AND** interactive input is unavailable
- **THEN** the CLI shows the current model and configured model choices as text
- **AND** the user can still switch models with `/model <name>`

### Requirement: Empty model choice state is explicit

The CLI SHALL clearly explain when interactive model selection cannot proceed because no configured model choices exist.

#### Scenario: `/model` with no configured model list shows guidance
- **WHEN** the user invokes `/model`
- **AND** no configured model list is available
- **THEN** the CLI explains that no model choices are configured
- **AND** the CLI shows how to provide or add model choices
