# Quickstart: Built-in Tavli AI keys

## 1. Create the local key file (never committed)

```bash
cp secrets.example.json secrets.json
```

Fill in any of the values (leave `""` for providers you don't want built in):

```json
{
  "GEMINI_API_KEY": "<key from aistudio.google.com/apikey>",
  "GROQ_API_KEY": "<key from console.groq.com/keys>",
  "OPENROUTER_API_KEY": "<key from openrouter.ai/keys>"
}
```

`git status` must not list `secrets.json`.

## 2. Run / build with the keys

```bash
flutter run -d macos --dart-define-from-file=secrets.json
flutter build macos --debug --dart-define-from-file=secrets.json
flutter build apk --dart-define-from-file=secrets.json
```

Without `--dart-define-from-file` the app has no built-in keys (behaves as before).

## 3. Validate

1. Profil → AI ključevi: providers with a built-in key and no own key show "Koristi se ugrađeni Tavli AI".
2. Delete own keys, tap "Napravi probni recept": a recipe appears; "Kako je lanac radio" marks attempts with "Tavli AI".
3. Save an own key: the text disappears for that provider; the chain test now answers without the "Tavli AI" mark.
4. `flutter test` — all tests pass without any `secrets.json`.
