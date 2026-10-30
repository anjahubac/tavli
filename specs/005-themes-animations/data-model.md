# Data model: Themes and ingredient animations

## ThemeChoice (domain, pure Dart)

| Field | Type | Values | Default |
|---|---|---|---|
| theme | `TavliTheme` | `bosiljak` ("Bosiljak"), `safran` ("Šafran"), `borovnica` ("Borovnica") | `bosiljak` |
| mode | `AppThemeMode` | `light` ("Svetla"), `dark` ("Tamna"), `system` ("Kao sistem") | `system` |

`ThemeChoice.fromSettings(theme: String?, mode: String?)` — unknown or missing
values fall back to the defaults (never throws: settings are user data, not AI output).

## AppSettings rows (existing table, no schema change)

| key | value |
|---|---|
| `theme` | `TavliTheme.name` |
| `theme_mode` | `AppThemeMode.name` |

## TavliPalette (UI)

bg, surface, primary, onPrimary, container, onContainer, text, muted, line,
boxLine, tints[3] — one const per theme × brightness (6), values in the spec input.
