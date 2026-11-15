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

The separate `tavli-next` implementation is useful evidence, not a drop-in
contract: its shared seed uses readable identifiers such as `f_krompir` as
primary IDs and its matcher uses exact aliases. Those IDs must not silently
become UUIDs or be confused with slugs. No data migration between the two
repositories is assumed by this proposal.

## Proposed interface

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

`FoodLookupScope` identifies the active household through an authenticated
application context, not a client assertion of server permission. Its exact
type and lifecycle remain open. Reference data is shared or household-scoped;
this small identity value does not itself confer read or write access. The
server must independently enforce access when persistence is introduced.

An empty or whitespace-only name cannot match a food; the caller receives an
unresolved result without a network request. A `Matched` result identifies a
reviewed or explicitly confirmed food; a `Proposed` result is a suggestion and
may refer only to an existing, visible food identity. A suggestion to create a
new food remains unresolved until a separate reviewed creation flow; no UUID
is invented for it. A proposal must not silently persist an alias or food. A
consumer retains `originalText` regardless of outcome. Lookup errors or
cancellation must not be interpreted as a successful match. Exact error and
cancellation types remain open. No
normalization, AI candidate generation, persistence or fallback is implemented
by this contract-only slice.

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
- Dev 1 and reviewers: decide whether any `tavli-next` data will be imported;
  if so, review a separate stable old-ID-to-UUID mapping and migration plan.

Owners, decision dates, accepted examples and the producing PR must be recorded
when decisions are actually made. This proposal does not mark T001 or D1-001
complete; their review and acceptance remain outstanding.
