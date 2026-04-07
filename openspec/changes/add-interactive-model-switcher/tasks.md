## 1. Selector Foundation

- [x] 1.1 Identify or extract a reusable interactive selector primitive that can be used by `/model`.
- [x] 1.2 Ensure the selector supports current-item highlighting, Up/Down navigation, Enter confirmation, and Escape cancellation.

## 2. `/model` Interactive Flow

- [x] 2.1 Update `/model` without arguments to open the selector when interactive mode and configured model choices are available.
- [x] 2.2 Keep `/model <name>` as the direct model switching path.
- [x] 2.3 Preserve textual fallback output for non-interactive terminals or missing model choices.

## 3. State And Persistence Verification

- [x] 3.1 Ensure interactive confirmation uses the existing real model-switching path so config persistence and runtime refresh stay consistent.
- [x] 3.2 Ensure cancellation leaves the current runtime and persisted model unchanged.

## 4. Tests And Documentation

- [x] 4.1 Add tests for interactive selection behavior, cancellation, and fallback behavior.
- [x] 4.2 Update help/README text to describe the interactive `/model` flow.
