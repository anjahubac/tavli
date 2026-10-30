# Quickstart: Recipe screens

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
scripts/check.sh
flutter run -d macos --dart-define-from-file=secrets.json
```

Manual check:

1. Recepti tab → "Još nema recepata".
2. "Dodaj recept" → "Po nazivu jela" → "sarma", 4 porcije → "Napravi recept" → preview → "Sačuvaj"; recipe opens.
3. "Dodaj recept" → "Iz slike" → "Izaberi iz galerije" (on Mac) → photo of a recipe → "Sačuvaj"; thumbnail in the list.
4. On a recipe → "Izmeni sa AI" → "bez luka" → "Prihvati"; then "Poništi poslednju izmenu" → original back.
5. "Izmeni" → change a quantity → "Sačuvaj"; "Prethodne verzije" shows "Ručna izmena".
6. "Obriši recept" → confirm; gone from list.
7. Resize the window below and above ~1100 px: split view vs single list.
8. Turn Wi-Fi off: steps 1, 5, 6 still work; AI shows "Nema veze sa serverom. Proveri internet."
