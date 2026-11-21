# Data model for direct household join

Status: proposed for D3-005, pending Dev 1 review. The existing server account
and recipe schemas are the migration baseline.

| Area | Current | Target |
| --- | --- | --- |
| Household membership | Unique household/user pair; provisioned users start as owner | Database uniqueness on user; owner and member roles; serialize changes to both affected households |
| Invite | No invite storage | One stable, high-entropy token per household, accessed through owner-share and authenticated preview/confirm operations. Source deletion invalidates the token |
| Recipe provenance | `updated_by` is edit attribution | Immutable server-controlled creator. Existing unknowns stay unknown. Copy caller-created and unknown records only |
| Recipe copy | Recipe and versions have household-scoped relations | Independent destination IDs, valid destination references, private photo copy where present, source originals retained until any confirmed source deletion |
| Switch retry | No recorded switch operation | Identifiable receipt per authenticated caller and operation UUID, with the original request and result bound to it. Replays neither repeat changes nor grant access outside current authorization |
| Source cleanup | Account deletion has a separate server path | Last-member switch requires explicit acknowledgement. Remove source shared rows transactionally after copying and queue cleanup of private source photo objects after commit |

The migration must preserve existing memberships and detect duplicate legacy
memberships before applying uniqueness. The receipt, token and cleanup data
have restricted access. The online switch saves only server-side state; the
app rebinds its offline cache to the verified membership. Any needed drift
migration is planned with the sync consumer. Personal account rows retain
their existing access and lifecycle.
