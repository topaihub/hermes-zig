## ADDED Requirements

### Requirement: Discoverable CLI commands are executable

The CLI SHALL only expose slash commands in discovery and help output if those commands have real supported runtime behavior.

#### Scenario: Help output matches supported commands
- **WHEN** the user invokes `/help`
- **THEN** every command shown in the help output has a supported execution path
- **AND** invoking one of those commands does not produce a generic placeholder response such as “not yet implemented”

#### Scenario: Slash discovery excludes unsupported commands
- **WHEN** the slash discovery menu is shown
- **THEN** it only contains commands that are supported in the current release
- **AND** commands without supported behavior are not listed

### Requirement: CLI command state is consistent across surfaces

The command registry, slash discovery, help output, and runtime command execution SHALL reflect the same command set and semantics.

#### Scenario: A discovered command behaves as described
- **WHEN** the user selects a command from slash discovery
- **THEN** the executed command behavior matches the command summary shown in the CLI
- **AND** the same command appears consistently in `/help`

### Requirement: Deferred commands are not presented as ready

The CLI SHALL not advertise deferred or placeholder command flows as ready-to-use commands.

#### Scenario: Deferred command is hidden from user-facing command menus
- **WHEN** a command remains intentionally deferred in the current release
- **THEN** it is not shown in slash discovery
- **AND** it is not presented in `/help` as an available command
