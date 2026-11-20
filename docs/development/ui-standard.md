# UI and interaction standard

Applies to new and changed screens. Use the Claude “Tavli: ekrani po uređajima”
canvas as the visual reference and the rules below for interactive behavior.
The local `packages/tavli_ui` package holds the theme, tokens and reusable UI.

## Design source

The design canvas **"Tavli: ekrani po uređajima"**
(<https://claude.ai/artifact/LYWX2feRv4ZUKSkRXTbsK7>) is the canonical Tavli
design. It is the app's original design, not a redesign: Tavli has no released
version whose look must be preserved. The canvas shows Plan, Nabavka, Početna,
Recepti and Ostava for Android, iOS, macOS and Windows.

- Build screens and components exactly as the canvas shows them: layout,
  hierarchy, copy, colors, typography, radii, spacing and icons.
- Do not invent layouts, controls or screens that the canvas does not show.
  When a needed screen or state is missing (an error state, a dialog, a screen
  not drawn yet), add it to the canvas first, or describe it in the feature spec
  with a reference to the nearest canvas pattern, and get Dev 4 review before
  implementation.
- When code, an older spec or an older mockup disagrees with the canvas, the
  canvas wins. Earlier visual references (for example the mockup linked from
  `specs/005-themes-animations`) are history only.
- When the canvas look and an accessibility rule below conflict (for example a
  hit area under 48×48), keep the look and meet the rule (larger hit area,
  wrapping text). Record the deviation in the PR.
- The canvas is drawn on fixed artboards (390×844 phone, 1200×760 desktop).
  Those are drawing frames, not layout sizes; see Sizing.

## Sizing: no fixed sizes

- Never give a screen, section, card, list, row or text container a fixed width
  or height. Width comes from the available space (parent constraints,
  `Expanded`/`Flexible`, the breakpoints below); height follows content.
- Control heights in the table below are **minimum** heights (`minHeight`
  constraints), never fixed heights. At 2× text controls grow; long Serbian copy
  wraps or the actions stack.
- A readable maximum width for text-heavy content, dialogs and sheets is allowed
  as a `maxWidth` constraint taken from a package token.
- Icons, avatars, checkboxes and thumbnails use token sizes.
- No number literals for spacing, radius, size or color in `lib/features/`; use
  package tokens. A missing token is added to the UI package with light/dark
  values and a gallery example in the same PR as its first consumer.

## Measurements from the canvas

Values are logical pixels. Heights are minimums.

| Element | Canvas value |
| --- | --- |
| Screen edge / between sections | 20 horizontal padding; 14 between sections |
| Inside cards and rows | 8 between small elements; 14 between cards; card padding 16–18 |
| Card | radius 20, no elevation; white surface with 1 px divider-color border, or a tinted container for the highlighted meal |
| Compact card, thumbnail, text button | radius 14 |
| Cooked meal card | muted surface, muted text, check icon, label "· skuvano" |
| Primary (filled) button | height 56, radius 18, label 15/700, optional 18 icon |
| Secondary (outlined) button | height 56, radius 18, 1 px outline, label 15/700; same height as a primary button (Anja, 2026-11-20). Buttons in one row always share one height |
| Floating action button | radius 20 |
| Segmented control | height 40, radius 20, 1 px outline |
| Filter chip | height 36, radius 10 |
| Text field, notice | radius 16 |
| List group / row | group radius 20 with 1 px dividers; row height 52, padding 16, gap 14 |
| Checkbox | 22, radius 6; checked = primary fill with white check |
| Status badge | 18 |
| Avatar (profile) | 40 on Android, 36 on iOS |
| Dialog, bottom sheet | radius 24 |
| Top bar | 64 on Android (title left, 22/700), 56 on iOS (title centered, 17/700) |
| Bottom navigation | 80 on Android; 98 on iOS including the home-indicator area; selected indicator 60×32, radius 16 |

Typography is Plus Jakarta Sans (bundled in the UI package): page title 28/800
(letter spacing −0.02em), highlighted card title 20/800, body 16, secondary text
14, section labels 12/700 uppercase (letter spacing 0.06em), navigation labels
12 (500, selected 700). Body text stays at least 16; preparation steps need
generous line spacing.

Colors come only from the palettes (Bosiljak default, Šafran, Borovnica; light
and dark). The canvas is drawn in Bosiljak light; other palettes map the same
roles. Never copy hex values into feature code.

Desktop layouts (macOS and Windows rows of the canvas) use the window frame,
page header, action bar, week strip, month calendar, card grid, list group,
data table and thumbnail components shown there.

## Icons

The canvas uses one icon style, and it applies to the whole app:

- outline line icons on a 24×24 grid, stroke 2, round line caps and joins,
  color from the surrounding text color; no filled, two-tone or emoji icons;
- the check mark in a status is stroke 2.4, inside a filled checkbox stroke 3;
- sizes: 22 in navigation, 18 inside buttons, 20 for status marks, 16 inside a
  checkbox.

Icons drawn on the canvas: Plan (calendar), Nabavka (cart), Početna (house),
Recepti (book), Ostava (box), Kuvaj (pot), Skuvano and checkbox (check mark).
A needed icon that is not on the canvas is drawn in the same style.

Screens use one Tavli icon set exported by the UI package and never reference
Material `Icons` directly. Current Material icons are a known deviation, replaced
when each screen moves to the library. Whether the set is drawn in-house or
taken from an open-source outline set with the same geometry is decided and
recorded in the [UI library spec](../../specs/031-external-ui-library/spec.md).
Decorative icons are excluded from semantics; icon-only buttons have a Serbian
label and tooltip.

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
| Buttons | Use the canvas minimum for each button variant; long Serbian copy wraps or stacks; every interactive target is at least 48×48 dp |
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
