# Contract: KeySource

```dart
enum KeyOrigin { user, builtIn }

class ApiCredential {
  const ApiCredential(this.provider, this.value, this.origin);
  final AIProvider provider;
  final String value;
  final KeyOrigin origin;
}

abstract interface class KeySource {
  /// Keys to try for [provider], in order. Empty list = provider unavailable.
  Future<List<ApiCredential>> credentialsFor(AIProvider provider);
}
```

`LayeredKeySource(KeyStore own, BuiltInKeys builtIn)`:

1. own key from `KeyStore` if non-empty → `KeyOrigin.user`
2. built-in key if non-empty → `KeyOrigin.builtIn`

Note (2026-11-23): own keys may be free or paid, for any service in the
service list of spec 004. Own keys are always before the built-in key.
`AIRouter` gets an `OwnKeyOrder { paidFirst, freeFirst }` (default
`paidFirst`, stored on the device). The router stable-sorts the direct model
chain by the cost class of each model's service according to it; the order
inside a class and the order of keys of one service do not change. The gateway
pass stays last.

`BuiltInKeys` and layer 2 are removed: `OwnKeySource(KeyStore own)` returns own
keys only. `KeyOrigin.builtIn` now marks the gateway credential, which has no
key value on the device.

Guarantees: no empty values; at most one credential per origin; never throws
for a missing key.

# Contract: ModelStatusStore (changed)

```dart
Future<DateTime?> blockedUntil(ModelSpec model, {KeyOrigin origin = KeyOrigin.user});
Future<void> block(ModelSpec model, DateTime until, String reason, {KeyOrigin origin = KeyOrigin.user});
Future<void> recordRequest(ModelSpec model, DateTime at, {KeyOrigin origin = KeyOrigin.user});
```

# Contract: AIRouter (changed)

- Constructor takes `KeySource keys` instead of `KeyStore keys`.
- `AIResult.origin` and `AttemptLog.origin` report which key answered / was tried.
- Per model: for each credential in order → skip if rejected / missing / paused for that origin, otherwise call. `RateLimitError`, `AuthError`, `ModelNotFoundError` → mark that origin and try the next credential of the same model. Other `AIError`s → next model.
- `invalidProviders` = providers whose own key was rejected; `resetProvider(p)` clears own-key state for `p`.
