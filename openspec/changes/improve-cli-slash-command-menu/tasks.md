## 1. Menu Rendering State

- [x] 1.1 Extend the input controller state to track visible viewport start, visible row count, and previously rendered menu height.
- [x] 1.2 Add any command metadata needed for vertical menu rendering and description display.

## 2. Vertical Dropdown Renderer

- [x] 2.1 Replace the inline slash suggestion renderer with a vertical multi-line menu renderer.
- [x] 2.2 Add selected-row highlighting and selected-command description display.
- [x] 2.3 Clear stale rows when the menu shrinks or closes.

## 3. Navigation And Scrolling

- [x] 3.1 Keep Up/Down navigation behavior while making the selected row remain inside the visible viewport.
- [x] 3.2 Add bounded scrolling for result sets larger than the visible menu limit.
- [x] 3.3 Preserve Tab completion, Esc dismissal, and Enter execution with the new menu layout.

## 4. Verification And Docs

- [x] 4.1 Add focused tests for menu visibility, redraw clearing, and viewport scrolling behavior.
- [x] 4.2 Update startup/help messaging to reflect the dropdown-style command menu.
- [x] 4.3 Update README documentation to describe the improved slash command menu.
