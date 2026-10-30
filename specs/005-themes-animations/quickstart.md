# Quickstart: Themes and ingredient animations

```bash
cd ../tavli-005-themes
flutter pub get
scripts/check.sh
flutter run -d macos --dart-define-from-file=secrets.json   # copy secrets.json from the main checkout
```

1. Launch: the intro shows the Bosiljak basil sprig for ~1,8 s (tap to skip).
2. Profil → Izgled: pick "Šafran", then "Tamna"; the app recolours. Restart — still Šafran, dark.
3. Profil → Animacije (debug builds only): all nine animations.
4. macOS System Settings → Accessibility → Display → Reduce motion: animations stand still.
5. Recepti → Dodaj recept → Iz slike: scan line while the AI reads; ingredient chips pop in on the preview.
6. Recepti → Po nazivu jela: simmering pot with rotating messages.
7. Pull the recipe list down: the spoon stirs. Ostava / Kupovina: animated empty states.
