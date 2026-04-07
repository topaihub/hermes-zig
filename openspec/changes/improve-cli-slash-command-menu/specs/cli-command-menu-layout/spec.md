## ADDED Requirements

### Requirement: Slash suggestions are rendered as a vertical command menu

The CLI SHALL render slash-command suggestions as a vertical dropdown-style menu while slash discovery is active.

#### Scenario: Slash prefix shows a vertical menu
- **WHEN** the user enters `/` at the CLI prompt in interactive mode
- **THEN** the CLI renders suggestions on subsequent terminal rows
- **AND** the suggestions are not flattened into a single inline horizontal strip

### Requirement: The command menu highlights one selected row

The CLI SHALL visibly indicate which slash-command suggestion is currently selected.

#### Scenario: Navigating changes the highlighted row
- **WHEN** the slash-command menu is visible
- **AND** the user presses the up or down arrow key
- **THEN** the highlighted row changes to the newly selected suggestion
- **AND** the previous row is no longer highlighted

### Requirement: The command menu exposes command context

The CLI SHALL display enough descriptive context for the user to understand the selected command before completion.

#### Scenario: Selected command shows its description
- **WHEN** a slash-command suggestion is selected in the command menu
- **THEN** the CLI displays that command's summary text in the menu region
- **AND** the command literal remains visible

### Requirement: The command menu supports bounded scrolling

The CLI SHALL support filtered result sets that are larger than the visible command menu window.

#### Scenario: Moving past the last visible row scrolls the menu
- **WHEN** the filtered slash-command result set contains more entries than the visible menu limit
- **AND** the user navigates beyond the current visible window
- **THEN** the menu scrolls to keep the selected command visible
- **AND** the prompt input buffer remains intact

### Requirement: The command menu clears stale rows on redraw

The CLI SHALL clear previously rendered suggestion rows whenever the visible slash-command menu shrinks or closes.

#### Scenario: Narrower filtering removes stale rows
- **WHEN** the user changes the slash-command prefix and the filtered result set becomes shorter
- **THEN** rows that are no longer part of the current menu are cleared from the terminal
- **AND** only the current filtered suggestions remain visible

#### Scenario: Dismissing the menu clears the menu region
- **WHEN** the slash-command menu is visible
- **AND** the user dismisses it with Escape or by leaving slash-command mode
- **THEN** the rendered menu rows are cleared
- **AND** the prompt line remains usable
