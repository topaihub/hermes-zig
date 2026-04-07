## ADDED Requirements

### Requirement: `/model` lists configured model choices

The CLI SHALL present the currently selected model and the configured model choices when the user invokes `/model` without an argument.

#### Scenario: `/model` shows current and available models
- **WHEN** the user invokes `/model`
- **THEN** the CLI shows the current model
- **AND** the CLI shows the configured `models` list when it exists

### Requirement: `/model <name>` persists the chosen model

The CLI SHALL persist a valid selected model to configuration when the user invokes `/model <name>`.

#### Scenario: Switching to a configured model updates config
- **WHEN** the user invokes `/model <name>` with a model that is present in the configured `models` list
- **THEN** the CLI writes that model as the active model in configuration
- **AND** the CLI confirms the selected model to the user

### Requirement: Model changes affect subsequent turns in the same process

The CLI SHALL refresh runtime model selection after a successful `/model <name>` change so later chat turns use the new model.

#### Scenario: Next turn uses the newly selected model
- **WHEN** the user successfully switches to a new model
- **AND** then sends another chat message in the same process
- **THEN** the next model request uses the newly selected model

### Requirement: Invalid model switches fail clearly without changing state

The CLI SHALL reject invalid model switch attempts without mutating the current runtime or persisted configuration.

#### Scenario: Unknown model is rejected
- **WHEN** the user invokes `/model <name>` with a model not present in the allowed configured model list
- **THEN** the CLI reports that the model is invalid or unavailable
- **AND** the current model remains unchanged in memory and configuration
