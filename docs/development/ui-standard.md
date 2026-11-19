# UI and interaction standard

Status: binding for every new or changed screen and component.

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
| Secondary (outlined) button | height 48, radius 16, 1 px outline, label 15/700 (also beside a primary button) |
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
`TabAppBar`. App code imports only that file, never `src/`. New tokens belong in
`packages/tavli_ui` with light/dark values; new screen-specific widgets belong
under `lib/features/<feature>/`.

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

## Required component behavior

| Component | Required behavior |
| --- | --- |
| Card grid | Cards align to equal row heights for ordinary text; at 2× text use adaptive height/list layout instead of clipping |
| Buttons | Heights as in the table above; long Serbian copy wraps or stacks; every interactive target is at least 48×48 dp |
| Fields | Use existing theme styles; label, help and validation remain visible; keyboard does not hide the focused field or submit action |
| Dialog/sheet | Use current adaptive patterns; bounded readable width, focus restored on close, accessible dismissal |
| Search/list | Loading, empty, error and populated states; preserve query/scroll on retry and return |
| Shopping row | Large check target; quantity beside name; bought group separate; undo accessible; no confirmation per check |
| Home/plan meal | Cooked state uses a check icon, text/semantics and muted surface, not color alone |
| Motion | Existing reduced-motion support; immediate action feedback, no artificial delay or endless blocking animation |
| Images | Distinguish scanned recipe source from dish photo; honest fallback and semantic description |

Do not invent a second set of measurements per screen. If a needed value is not
on the canvas or in the tokens, Dev 4 records the proposed value and usage in
the feature contract before implementation.

## Navigation and platform behavior

Code has five tabs with Home in the middle (default `/home`, still empty):
**Plan, Nabavka, Početna, Recepti, Ostava**, with Home opening after auth/name
gates and profile behind the avatar. The wide side menu lists Home first and
ends with Profil instead of the top avatar. Further route additions and
redirect changes require Dev 4 review and regression tests. Preserve `/plan`,
`/shopping`, `/recipes`, `/pantry`, `/profile` and recipe deep links.

Each platform follows its own canvas row: Android, iOS, macOS and Windows.
Retain current breakpoints: bottom bar below 720 px, rail at 720 px, extended
rail at 1000 px. Fixed primary actions sit above mobile navigation and safe
areas, with scrolling content padded so the last item remains reachable. On
desktop place actions with the content, not in a phone-shaped overlay.

Plan week/month switches and shared actions retain a stable place/size.
Mobile month shows day markers and selected-day meals; wide month can show a
readable grid. Smartphone camera/gallery and desktop file selection remain
platform-appropriate. All controls support keyboard/focus and screen readers.

## Acceptance matrix

Every UI PR compares the result with the matching canvas board and states any
difference. It also records phone widths 320/400, wide width 1200, light/dark,
text 1×/2×, reduced motion, keyboard navigation and loading/empty/error/offline
states. Check real device permissions for camera, microphone and wake lock
where used; state what was not tested. Full journey: choose meal/plan → inspect
ingredients → add only the difference → purchase/transfer → cook/undo (see
[flows](../flows.md)). No pantry/profile setup is required for first useful plan
or standalone recipe shopping.

The five-person first-use evaluation inherited from 010 remains a release goal
(at least four complete core journeys without instruction). Until performed,
it is unverified; widget tests or a polished screenshot do not replace it.
