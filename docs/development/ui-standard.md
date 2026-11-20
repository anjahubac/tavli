# UI and interaction standard

Applies to new and changed screens. Use the Claude “Tavli: ekrani po uređajima”
canvas as the visual reference and the rules below for interactive behavior.
The local `packages/tavli_ui` package holds the theme, tokens and reusable UI.

## Reuse the current implementation

Use `buildTavliTheme`, `TavliColors`, `TavliPalette`, `TavliStatusColors`,
`TavliSpacing`, `TavliRadius`, `TavliMotion` and `MotionBuilder` from
`package:tavli_ui/tavli_ui.dart`, plus `ThemeController` and the existing
`TabAppBar`. Use Material icons consistent with neighboring
screens. New tokens belong in `packages/tavli_ui` with light/dark values;
new screen-specific widgets belong under `lib/features/<feature>/`.

An approved reusable component can stay in its current feature until a second
consumer justifies extraction into `packages/tavli_ui`.

## Component gallery and library checks

Debug builds have Profil > Komponente (route `/components`), which opens
even without sign-in from the sign-in screen. It shows `TavliGallery` from the
package with switches for theme, light/dark, text size and simulated platform.
Release builds do not register the route. Every new library component adds a
section to `TavliGallerySections` and a golden image.

- `scripts/check.sh` formats and analyzes the package and fails when app code
  imports anything from `package:tavli_ui` other than `tavli_ui.dart`.
- The pre-commit hook runs package tests when a package file changes.
- Golden images (`packages/tavli_ui/test/goldens`, tag `golden`) are compared
  only on Linux, as in CI; other systems skip them. Regenerate them with
  `scripts/update-goldens.sh` (Docker, CI's Flutter version) and review the
  image diff before committing; `--check` only compares. A failed CI run
  uploads the differences as the `golden-failures` artifact.

Gallery coverage complements checks of the actual screen, including focus,
scrolling, permissions and platform window controls.

## Required component behavior

| Component | Required behavior |
| --- | --- |
| Card grid | Cards align to equal row heights for ordinary text; at 2× text use adaptive height/list layout instead of clipping |
| Buttons | Same-row actions have consistent height; long Serbian copy wraps or stacks; every interactive target is at least 48×48 dp |
| Fields | Use existing theme styles; label, help and validation remain visible; keyboard does not hide the focused field or submit action |
| Dialog/sheet | Use current adaptive patterns; bounded readable width, focus restored on close, accessible dismissal |
| Search/list | Loading, empty, error and populated states; preserve query/scroll on retry and return |
| Shopping row | Separate the large purchase check target from the visible source-detail action. Keep quantity beside the name. Check items without a confirmation prompt and group bought items with accessible undo. |
| Pantry row | Swipe is an optional shortcut. Provide a visible or keyboard-focusable action to remove the item and a reachable undo action. |
| Home/plan meal | Cooked state uses a check icon, text/semantics and muted surface, not color alone |
| Motion | Existing reduced-motion support; immediate action feedback, no artificial delay or endless blocking animation |
| Images | Distinguish scanned recipe source from dish photo; honest fallback and semantic description |

Spacing/radii/typography come from existing theme tokens and neighboring approved
components. If a needed spacing/control token is missing, Dev 4 records its
proposed value and usage in the feature contract before implementation. Do not
invent a second set of arbitrary measurements per screen. Body text targets
16 logical pixels; preparation steps need generous line spacing.
Use 4.5:1 contrast for normal text and 3:1 for large text and meaningful
control boundaries or indicators. Check selected, cooked, warning and keyboard
focus states in light and dark themes. Announce state changes in Serbian and
leave a named action after a transient message expires when recovery is needed.

## Navigation and platform behavior

The app already defaults to `/home` after sign-in and name entry. The bottom
bar shows **Plan, Nabavka, Početna, Recepti, Ostava**, with the profile avatar
above. The side rail shows **Početna, Plan, Nabavka, Recepti, Ostava**, with
Profil at the bottom. Preserve those orders, the existing routes and recipe
deep links. Dev 4 coordinates shell and redirect changes.

Navigation depends on available window width in logical pixels. Use the bottom
bar below 720, a compact rail from 720, and the extended rail from 1000.
Choose content panes based on the width and height left after navigation.
Use one pane when the list and detail cannot both remain readable.

Before adopting the new shell, verify compact navigation at 2× system text.
Allow labels to reflow or use a readable compact presentation with all five
destinations available. A text scale cap or ellipsis alone cannot satisfy this
check. Keep the selected tab, selected day or item, search and scroll position
across layout changes. Keep keyboard focus on the equivalent control or return
it to a logical location if that control moves. Every destination has an
accessible name and selected state.

Place fixed mobile actions above the bottom bar and safe area. Keep the last
item and active input reachable when the keyboard is open or buttons wrap.
Place desktop actions beside the content. Keep week/month switching and
shared actions stable. On compact month views show day markers and the
selected day's meals, with a day list available when the grid cannot fit
readable labels and 48×48 targets. Wide layouts can show a calendar and detail.
Use camera/gallery on phones and a file picker on desktop. Use native window
controls and dialogs when validating each desktop target.

## Acceptance matrix

Every UI PR records the relevant cases below. Use long Serbian labels and
realistic synthetic recipes. Record the build, platform and any untested cases.

| Check | Evidence |
| --- | --- |
| Layout and resize | Phone widths 320/400 and wide width 1200. For shell or pane changes test 719/720 and 999/1000, narrow desktop windows and short landscape heights. Verify selection, focus, safe areas and the last scrollable item. |
| Appearance and input | Light/dark, text 1×/2× and reduced motion. Check touch, system Back, mouse/trackpad, visible keyboard focus and screen-reader names and announcements. Verify gesture actions also work through an explicit control. |
| Mobile and tablet | Android phone/tablet and iPhone/iPad where applicable. Check rotation, iPad split view and Android split screen, system insets and the keyboard. Use TalkBack and VoiceOver on the affected journeys. |
| Desktop | On macOS, check resize, keyboard, trackpad, VoiceOver and native file dialogs. In the Windows and Linux platform slices, check real-device window controls, resizing, OS scaling, keyboard navigation and file dialog cancellation. |
| States and recovery | Loading, empty, no results, populated, error with retry, cached offline and reconnect as applicable. Distinguish an empty result from a failed read. Check camera, microphone and wake lock on real devices when the screen uses them. |

Verify plan → ingredients → purchase/transfer and standalone recipe → missing
ingredients → purchase. A first useful plan and standalone shopping require no
pantry setup or extra profile configuration after sign-in and name entry.
Verify “Kuvaj” → “Skuvano” → “Poništi” through the
[021 scenarios](../../specs/021-home-and-cooking/spec.md#user-scenarios-and-acceptance).

The five-person first-use evaluation inherited from 010 remains a release goal
(at least four complete core journeys without instruction). Until performed,
it is unverified; widget tests or a polished screenshot do not replace it.
