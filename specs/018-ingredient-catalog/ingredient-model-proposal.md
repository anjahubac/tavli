# Ingredient identity and lookup contract proposal

**Status:** Draft for review; no decision or implementation is implied.
**Source:** D1-001 / FR-001 in [018](spec.md), Trello card
[Dogovor: oblik namirnice](https://trello.com/c/DEXL7rzp/15-dogovor-oblik-namirnice).
**Producer:** Dev 1. **Consumers:** Dev 2, Dev 3 and Dev 4.
**Review requested:** Dev 2, Dev 3 and Dev 4; independent human acceptance is
required before this contract is treated as agreed.

## Scope and baseline

The current `dev` recipe ingredient stores its original name, quantity, unit,
category and optional note; it does not carry a catalog identity. The current
ID generator makes UUID v4 values. The [shared boundary C1](../011-team-development/contracts/shared-boundaries.md)
calls for a stable UUID and readable slug, with separate matched, unresolved
and proposed outcomes. This document proposes that interface; it does not add
a database, matcher, migration, network call or application behavior.

## Proposed interface

Proposed contract version: **1**. A change to required fields, result semantics
or lookup precedence requires a new contract version and consumer review.

The following Dart-like types specify intent, not compiled code:

```dart
enum FoodBaseUnit { piece, gram, milliliter }

final class FoodIdentity {
  final String id;       // immutable UUID; never derived from the name
  final String slug;     // readable identifier, distinct from id
  final String name;     // non-empty human-readable canonical name
  final String category; // existing ingredient category vocabulary
  final FoodBaseUnit baseUnit;
}

sealed class FoodMatchResult {}
final class Matched extends FoodMatchResult { final FoodIdentity food; }
final class Unresolved extends FoodMatchResult {}
final class Proposed extends FoodMatchResult { final FoodIdentity candidate; }

abstract interface class FoodMatcher {
  Future<FoodMatchResult> findByName({
    required String originalText,
    required FoodLookupScope scope,
  });
}
```

### Scope and match confidence

Resolve the active household from the authenticated application context at
lookup start. A lookup may use shared reference data plus data visible to that
household. A confirmed household alias takes priority over a shared alias.
If equally authoritative visible mappings disagree, return `Unresolved` until
the user confirms the intended food. Discard an in-flight result if the
household changes or access is revoked. The server independently enforces
authorization. Overrides affect future lookups in that household and do not
rewrite references already confirmed and saved.

`Matched` means there is evidence that the input refers to the returned food:
a unique reviewed canonical name or alias, or an explicit confirmation in the
active scope. The mere existence of a food in the catalog is insufficient.
Fuzzy or AI suggestions may return `Proposed` for a visible existing identity.
A suggestion to create a new food stays unresolved until a separate creation
flow accepts it. Lookup does not persist aliases or accept suggestions.

### Offline, errors and cancellation

Keep the original text for every outcome. Empty or whitespace-only input
returns `Unresolved` without I/O. Offline lookup can use an authorized local
snapshot of reviewed entries and confirmed overrides for the active household.
If that snapshot cannot establish a match, keep the original text and return
`Unresolved` with a retry opportunity when online. A failed lookup is a
retryable error for transport failures or an access error for invalid scope,
distinct from an ordinary unresolved name. A canceled lookup returns no
match result. Error and cancellation never write data.

Backfill uses the ingredient's stable record identity and the contract version
to recognize prior work. Repeating the same backfill against unchanged input
and catalog evidence leaves the same links and creates no duplicate aliases or
proposals. Skip already confirmed identities and do not overwrite a newer user
edit. Unresolved rows may be retried when evidence changes.

`piece`, `gram` and `milliliter` are proposed domain units, not new UI copy or
a settled wire representation. Aliases, conversions, nutritional data and
packaging are separate future concerns; unknown conversion data is not zero.
The stable ID remains unchanged when a name changes. Slug uniqueness and rename
behavior require a decision before persistence.

## Review fixtures

These examples are proposed acceptance fixtures, not passing test results.

| Input / situation | Expected contract behavior |
| --- | --- |
| Confirmed `jaja` alias for food `jaje` | `Matched` returns its UUID and canonical name; original `jaja` remains intact. |
| Unknown `zmajevo voće` | `Unresolved`; the original text remains usable. |
| A candidate for `jogurt` is `kiselo mleko` | It is not accepted as an exact alias merely because it is similar. |
| A user has not accepted an AI suggestion | At most `Proposed`; no canonical food or alias is saved. |
| Empty or whitespace-only input | `Unresolved`, without a remote request. |
| Two households have different custom foods | Each lookup uses only its authorized active scope; server access is tested independently. |
| Household A confirms an override for a shared alias | A uses the override; household B retains the shared mapping. |
| The active household changes while lookup is pending | Discard the result; no write occurs. |
| Offline cache has no confident match | Preserve original text; the caller can retry online. |
| Lookup is canceled or transport fails | No match is applied. Only the transport failure is offered for retry. |
| The same backfill runs twice after a user confirms a correction | One link remains, and the confirmation wins. |
| A confirmed food is renamed | Its UUID stays the same; existing ingredient text is not rewritten. |

## Compatibility, failure and privacy

Existing recipe JSON and approved snapshots remain readable; absence of a food
identity is valid. A later implementation must define additive serialization,
old/new client behavior, migration and rollback before it changes persisted
data. It must preserve pending outbox entries and original ingredient text,
and test offline replay and two-account isolation. There is no schema or
outbox change in this proposal. Ingredient text can be user data: no raw text
or request content should be logged; any AI use requires its own reviewed
consent, privacy and gateway contract.

## Decisions required before implementation

- Dev 1 and consumers: confirm the field types and whether this result shape
  meets all recipe, plan, voice and import consumers.
- Dev 1 and reviewers: decide slug uniqueness, normalization, rename semantics,
  category vocabulary, wire values and UUID validation/generation boundaries.
- Dev 1 and Dev 3: define scope resolution, household transitions and exact
  server authorization; decide conflict and household-override behavior.
- Dev 1 and Dev 2: decide bounded candidate generation, confirmation,
  cancellation, offline and error outcomes; no AI proposal is a trusted match.
- Dev 1 and Dev 4: coordinate unit terminology with the unresolved 017
  conversion decisions. No conversion assumptions are finalized here.

Owners, decision dates, accepted examples and the producing PR must be recorded
when decisions are actually made. This proposal does not mark T001 or D1-001
complete; their review and acceptance remain outstanding.
