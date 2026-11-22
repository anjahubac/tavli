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

final class FoodLookupScope {
  final String householdId; // the active household; nothing else in version 1
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
household. A confirmed household alias takes priority over a shared alias, and
so does the canonical name of a confirmed household-owned food: both outrank
shared matches. If mappings of the same priority point to different food IDs,
return `Unresolved` until the user confirms the intended food. A household
alias that points to a shared food does not change who owns that food's
canonical name. Discard an in-flight result if the household changes or access
is revoked. The server independently enforces authorization. Overrides affect
future lookups in that household and do not rewrite references already
confirmed and saved.

`Matched` means there is evidence that the input refers to the returned food:
a unique reviewed canonical name or alias, or an explicit confirmation in the
active scope. The mere existence of a food in the catalog is insufficient, and a
food that the shared catalog has withdrawn is never returned as `Matched`.
Fuzzy or AI suggestions may return `Proposed` for a visible existing identity.
A suggestion to create a new food stays unresolved until a separate creation
flow accepts it. Lookup does not persist aliases or accept suggestions.

`FoodLookupScope` holds only the active `householdId` in version 1. Whether
the data came from an offline snapshot is a property of the data source, not
of the scope. The caller or service validates the active context itself and
discards a stale result after a household or access change.

### Name normalization

Lookup keys use the existing `ingredientKey` unchanged, including for
`alias_normalized`. Inflected forms (`jaja`, `jaje`) are reviewed aliases. This
slice adds no stemming and no diacritic stripping.

### Offline, errors and cancellation

Keep the original text for every outcome. Empty or whitespace-only input
returns `Unresolved` without I/O. Offline lookup can use an authorized local
snapshot of reviewed entries and confirmed overrides for the active household.
If that snapshot cannot establish a match, keep the original text and return
`Unresolved` with a retry opportunity when online. A failed lookup is a
retryable error for transport failures or an access error for invalid scope,
distinct from an ordinary unresolved name. A canceled lookup returns no
match result. Error and cancellation never write data.

### Link stored on a recipe ingredient

An ingredient the matcher resolved carries additive fields beside its original
`name`. The following Dart-like type specifies intent, not compiled code:

```dart
enum LinkSource { matched, confirmed }

final class IngredientLink {
  final String foodId;        // FoodIdentity.id
  final String matchedKey;    // ingredientKey(name) when the link was made
  final LinkSource linkSource; // who set it: the matcher or a person
}
```

`foodId` is the UUID of the matched food, and `matchedKey` is the value of
`ingredientKey(name)` when it was resolved (the function is in
`lib/domain/shopping_sync.dart`). `matchedKey` and `linkSource` are required
whenever `foodId` is present, so preserving an explicit confirmation is part of
the contract.

A link is **valid** only while `ingredientKey(name)` still equals `matchedKey`
and the food it points to has not been withdrawn from the shared catalog (the
catalog withdraws an entry instead of deleting it; see the data model
proposal). If the name is edited, or the food is withdrawn, the link stops
being valid by itself: consumers ignore it, treat the ingredient like an
unresolved one, the original text is untouched and the ingredient can be
resolved again. No ingredient identifier is needed.

Backfill recognizes prior work by this link: an ingredient with a valid link is
skipped. Repeating the same backfill against unchanged input and catalog
evidence leaves the same links and creates no duplicate aliases or proposals.
Backfill never overwrites a `confirmed` link or a newer user edit. When a
backfill result is applied, the recipe and ingredient must be checked again:
if either changed since it was read, the result is discarded and read again.
`matchedKey` detects a changed name, but not a changed recipe. Approved plan
snapshots that already exist are never changed by backfill. Unresolved
ingredients carry no link and may be retried when evidence or the contract
version changes.

The first implementation slice is an alias and canonical-name matcher over the
local catalog. It does not complete the matching requirement: AI-assisted
proposals through the gateway, fuzzy candidates and creating new foods remain
open work.

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
| An ingredient is renamed after it was matched | The link is no longer valid because `matchedKey` differs from `ingredientKey(name)`; the original text is kept, consumers ignore the link and the ingredient can be resolved again. |
| Household A has its own food `mleko`; the shared catalog also has `mleko` | A resolves to its own food, household B to the shared one. |
| Two confirmed household entries of the same priority name different foods | `Unresolved` until the user confirms one. |
| Household A adds an alias to a shared food | The alias applies in A only and does not change who owns the canonical name of that food. |
| The food an ingredient is linked to is withdrawn from the shared catalog | The link is ignored and the ingredient is treated as unresolved; the original text is kept and it can be resolved again. |
| A backfill result is applied after the recipe was edited | The result is discarded and read again; the edit and any `confirmed` link stay. |
| A backfill touches a recipe that is already in an approved plan snapshot | The snapshot is unchanged. |
| A build without the link fields saves the recipe | The link fields are dropped. This is a compatibility limitation, not a recovery path: backfill cannot be assumed to restore a lost `confirmed` mapping. |

## Compatibility, failure and privacy

Existing recipe JSON and approved snapshots remain readable; absence of a food
identity is valid. A later implementation must define additive serialization,
old/new client behavior, migration and rollback before it changes persisted
data. It must preserve pending outbox entries and original ingredient text, and
test offline replay and two-account isolation. The ingredient link is additive
JSON on the existing embedded ingredient. Current builds keep `foodId`,
`matchedKey` and `linkSource` (`Ingredient.link`) through stored reads and saves,
ingredient edits in the recipe form and AI recipe edits, where a link carries
over to an ingredient whose `ingredientKey(name)` still equals its
`matchedKey`. AI responses never set a link. Older builds ignore unknown fields
and omit them in `toJson`, so a build that does not know `foodId`,
`matchedKey` and `linkSource` drops them when it saves a recipe. Mixed-version
writes and pending outbox entries created by an older build are an explicit
rollout gate: it is not enough that team builds update together, and backfill
must not be treated as a way to restore a confirmation an old build dropped.
There is no schema or outbox change in this proposal.

Ingredient text can be user data: no raw text or request content should be
logged; any AI use requires its own reviewed consent, privacy and gateway
contract.

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
- Link on the embedded ingredient (`foodId`, `matchedKey`, `linkSource`) and
  not in a separate table: Dev 4 supports this from the consumer side
  (2026-11-18). This is not an approval of the schema or access-rule decisions
  of the data model proposal, which keeps its own reviews.
- Version 1 of `FoodLookupScope` is `householdId` only; `ingredientKey` is
  reused unchanged; a household food's canonical name has the priority of a
  confirmed household alias (Dev 4, 2026-11-18).
- Open: a rollout plan for mixed-version writes and old outbox entries before
  any persisted link is shipped. A draft is in the
  [link rollout plan](link-rollout-plan.md).

Owners, decision dates, accepted examples and the producing PR must be recorded
when decisions are actually made. This proposal does not mark T001 or D1-001
complete; their review and acceptance remain outstanding.
