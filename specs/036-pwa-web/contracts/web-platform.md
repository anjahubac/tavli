# Contract: web-only client behaviour

**Owner**: Dev 4 | **Version**: 1 (2026-11-24). Native implementations are unchanged; every
item below is selected only when compiling for the web.

| Interface | Native (unchanged) | Web |
| --- | --- | --- |
| `KeyStore` (`lib/ai/key_store.dart`) | `SecureKeyStore` with Keychain/Keystore/Windows | `NoOwnKeyStore`: own-key list always empty; adding throws `UnsupportedError` that the UI never triggers (D2). The session stays in `SessionStore` over secure storage (D1) |
| `RecipePhotoStore` | `FileRecipePhotoStore` (`file()` on the class) | `IndexedDbRecipePhotoStore`; `read()` + `Image.memory`; same path validation |
| Offline detection | `SocketException` | `http.ClientException` (already caught everywhere); stub `SocketException` never thrown |
| Email redirect | `authEmailRedirectUrl` as today | `WEB_AUTH_REDIRECT_URL` dart-define; page URL `?code=` is turned into the `tavli://auth-callback` flow; code entry always works |
| `AppLinks` stream | as today | empty stream |
| Window channels (`app.dart`) | macOS/Windows as today | not used |
| AI keys screen | key list | notice “Sopstveni ključevi rade samo u aplikaciji. U pregledaču Tavli koristi zajednički pristup.” |
| Voice recorder | temp file, AAC/WAV | WAV blob read into memory; microphone denial returns false as on native |

Tests: web variants are unit-tested with `flutter test --platform chrome`; the native
variants keep their existing tests, which must pass unchanged.
