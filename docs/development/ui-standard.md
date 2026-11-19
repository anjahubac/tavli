# UI and interaction standard

Status: applies to new/changed screens in the existing design. The local
`packages/tavli_ui` package holds the theme and tokens; components move into it
in later library phases.

## Reuse the current implementation

Use `buildTavliTheme`, `TavliColors`, `TavliPalette`, `TavliStatusColors`,
`TavliSpacing`, `TavliRadius`, `TavliMotion` and `MotionBuilder` from
`package:tavli_ui/tavli_ui.dart`, plus `ThemeController` and the existing
`TabAppBar`. Use Material icons consistent with neighboring
screens. New tokens belong in `packages/tavli_ui` with light/dark values;
new screen-specific widgets belong under `lib/features/<feature>/`.

An approved reusable component can stay in its current feature until a second
consumer justifies extraction into `packages/tavli_ui`.

## Required component behavior

| Component | Required behavior |
| --- | --- |
| Card grid | Cards align to equal row heights for ordinary text; at 2× text use adaptive height/list layout instead of clipping |
| Buttons | Same-row actions have consistent height; long Serbian copy wraps or stacks; every interactive target is at least 48×48 dp |
| Fields | Use existing theme styles; label, help and validation remain visible; keyboard does not hide the focused field or submit action |
| Dialog/sheet | Use current adaptive patterns; bounded readable width, focus restored on close, accessible dismissal |
| Search/list | Loading, empty, error and populated states; preserve query/scroll on retry and return |
| Shopping row | Large check target; quantity beside name; bought group separate; undo accessible; no confirmation per check |
| Home/plan meal | Cooked state uses a check icon, text/semantics and muted surface, not color alone |
| Motion | Existing reduced-motion support; immediate action feedback, no artificial delay or endless blocking animation |
| Images | Distinguish scanned recipe source from dish photo; honest fallback and semantic description |

Spacing/radii/typography come from existing theme tokens and neighboring approved
components. If a needed spacing/control token is missing, Dev 4 records its
proposed value and usage in the feature contract before implementation. Do not
invent a second set of arbitrary measurements per screen. Body text targets
16 logical pixels; preparation steps need generous line spacing.

## Navigation and platform behavior

Code has five tabs with Home in the middle (default `/home`, still empty):
**Plan, Nabavka, Početna, Recepti, Ostava**, with Home opening after auth/name
gates and profile behind the avatar. The wide side menu lists Home first and
ends with Profil instead of the top avatar. Further route additions and
redirect changes require Dev 4 review and regression tests. Preserve `/plan`,
`/shopping`, `/recipes`, `/pantry`, `/profile` and recipe deep links.

Retain current breakpoints: bottom bar below 720 px, rail at 720 px, extended
rail at 1000 px. Fixed primary actions sit above mobile navigation and safe
areas, with scrolling content padded so the last item remains reachable. On
desktop place actions with the content, not in a phone-shaped overlay.

Plan week/month switches and shared actions retain a stable place/size.
Mobile month shows day markers and selected-day meals; wide month can show a
readable grid. Smartphone camera/gallery and desktop file selection remain
platform-appropriate. All controls support keyboard/focus and screen readers.

## Acceptance matrix

Every UI PR records phone widths 320/400, wide width 1200, light/dark, text 1×/2×,
reduced motion, keyboard navigation and loading/empty/error/offline states.
Check real device permissions for camera, microphone and wake lock where used;
state what was not tested. Full journey: choose meal/plan → inspect ingredients
→ add only the difference → purchase/transfer → cook/undo. No pantry/profile
setup is required for first useful plan or standalone recipe shopping.

The five-person first-use evaluation inherited from 010 remains a release goal
(at least four complete core journeys without instruction). Until performed,
it is unverified; widget tests or a polished screenshot do not replace it.
