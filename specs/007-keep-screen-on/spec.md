# Feature Specification: Keep the screen on while cooking

**Feature Branch**: `007-keep-screen-on` (created from latest `main`)

**Created**: 2026-10-30

**Status**: Implemented

**Input**: User description (Serbian, translated): "Add an option so the screen doesn't turn off while you cook."

> All UI text is Serbian (Latin script). Quoted strings are the exact UI copy.

## Clarifications

### Session 2026-10-30

Decided as defaults while the owner was away:

- Q: Where is the option? → A: A toggle in the recipe's top bar ("Ne gasi ekran"), because that is where you are while cooking.
- Q: Is the choice remembered? → A: Yes, for all recipes until switched off. Default is off (saves battery).
- Q: When is the screen kept on? → A: Only while a recipe is open (detail screen, or the recipe pane on wide windows). Leaving the recipe or sending the app to the background lets the screen turn off normally.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Screen stays on while a recipe is open (Priority: P1)

While cooking from a recipe, the person taps "Ne gasi ekran" in the recipe's top
bar. The screen no longer dims or locks while that recipe is open. The choice
is remembered for the next recipe.

**Independent Test**: open a recipe, turn the toggle on, wait past the auto-lock time; the screen stays on. Leave the recipe; the screen locks normally.

**Acceptance Scenarios**:

1. **Given** the toggle is off, **When** the person taps it, **Then** it shows as on and "Ekran se neće gasiti dok je recept otvoren." is shown.
2. **Given** the toggle is on, **When** the person taps it, **Then** it shows as off, "Ekran se gasi kao i obično." is shown and the screen may turn off again.
3. **Given** the toggle is on, **When** the person leaves the recipe, **Then** the screen may turn off again.
4. **Given** the toggle was turned on earlier, **When** another recipe is opened (also after restarting the app), **Then** the screen is kept on without tapping again.

### Edge Cases

- The platform refuses to keep the screen on → the app keeps working; nothing crashes.
- Wide window: the recipe pane next to the list counts as "recipe open".

## Requirements *(mandatory)*

- **FR-001**: The recipe screen MUST have a toggle "Ne gasi ekran" (tooltip; selected state when on).
- **FR-002**: While a recipe is open and the toggle is on, the screen MUST NOT turn off automatically.
- **FR-003**: Leaving the recipe MUST release the keep-on request.
- **FR-004**: The choice MUST be stored on the device and apply to all recipes; default off.
- **FR-005**: Failures of the platform keep-on request MUST NOT crash or block the screen.

## Success Criteria *(mandatory)*

- **SC-001**: One tap turns the option on; it then applies to every recipe until turned off.
- **SC-002**: With the option on, the screen does not lock during a 30-minute cooking session with a recipe open.

## Assumptions

- Works on Android, iOS and macOS (macOS: prevents display sleep).
