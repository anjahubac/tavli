# Quickstart: Themes and ingredient animations

```bash
cd ../tavli-005-themes
flutter pub get
scripts/check.sh
flutter run -d macos --dart-define-from-file=secrets.json   # copy secrets.json from the main checkout
```

1. Launch: new installations use light Bosiljak; saved settings are retained. The active theme motif appears only during account-session loading; there is no minimum intro duration. Sign in to reach the app tabs.
2. Profil → Izgled: pick "Šafran", then "Tamna"; the app recolours. Restart — still Šafran, dark.
3. Profil → Animacije (debug builds only): theme motifs and animation demos.
4. macOS System Settings → Accessibility → Display → Reduce motion: animations stand still. Enable it during a checkmark, badge or chip flight too: active feedback stops immediately.
5. Recepti → Dodaj recept → Iz slike: scan line while the AI reads; ingredient chips pop in on the preview.
6. Recepti → Po nazivu jela: simmering pot with rotating messages.
7. Pull the recipe list down: the spoon stirs only while data is read, with no forced delay. Nabavka shows an empty basket and "Pogledaj recepte"; Ostava describes records not yet entered, with a softly lit fridge.
8. Profil → Animacije → ingredient demo: mark what you have, add missing ingredients, unmark one and add again. Only the difference is added, with one "Dodato u nabavku: N" confirmation. The demo does not modify real shopping data.
9. At 320 px and text 2×, the selected tab name stays on one line below the icons. Theme previews and demo headings remain readable; screen-on uses a screen icon rather than the theme's sun.
10. Across all three palettes, ingredient confirmations use the same semantic success colours. Real plan/pantry entry actions and monthly-generation progress remain in spec 010.
