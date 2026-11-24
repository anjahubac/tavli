# Feature readiness checklist

- [ ] CHK001 Source requirements match current code and remaining work is recorded.
- [ ] CHK002 Blocking product/privacy/source/platform questions have owner decisions.
- [x] CHK003 Exact producer/consumer contract and synthetic acceptance fixtures agreed.
- [ ] CHK004 Current files, schema/compatibility changes and dependencies verified.
- [ ] CHK005 Each Ready slice has implementer, independent reviewer and effort range.
- [ ] CHK006 Security 012 and testing 013 cases are attached; UI copy/accessibility finalized.
- [ ] CHK007 Applicable checks have real evidence; external setup is not assumed.
- [ ] CHK008 Release/rollback and unresolved limits reviewed before delivery Done.

Evidence links: [implementation and remaining checks](../plan.md), [execution
breakdown](../tasks.md), [server/client contract](../contracts/ai-gateway-contract.md),
and [local quota model](../data-model.md). The server fake tests cover part of
CHK007. The authenticated local run is recorded in `evals/capstone/gateway-flow.md`; hosted and build evidence are still open.

## Evidence status (2026-11-24)

Only items with evidence in this repository are checked. The others stay open
until the gateway owner (Dev 2) records the decision or the run.

| Item | Status | Evidence or what is missing |
| --- | --- | --- |
| CHK001 | Open | `plan.md` and `tasks.md` exist; the owner has not confirmed that they match the current code |
| CHK002 | Open | No owner decision is recorded for the blocking questions |
| CHK003 | Done | [Contract](../contracts/ai-gateway-contract.md) and fake-provider cases in `supabase/functions/ai-gateway/gateway_test.ts` |
| CHK004 | Open | Dependencies and compatibility have not been re-verified against `dev` |
| CHK005 | Open | Reviewer per slice is recorded in the PRs, not in `tasks.md` |
| CHK006 | Partial | Controls and tests are listed in [security.md](../../../docs/development/security.md#gateway-evidence-source-and-fake-provider-tests); UI copy and accessibility are not reviewed here |
| CHK007 | Partial | `deno test supabase/functions/ai-gateway` and `supabase/tests/13_ai_reservation_test.sql`; an authenticated local-stack run (`supabase start` + `functions serve`, synthetic user, free-tier provider chain) is recorded in [gateway-flow.md](../../../evals/capstone/gateway-flow.md); a macOS release build from a clean clone with no provider key found in it is recorded in [artifact-check.md](../../../docs/capstone/artifact-check.md); no hosted-project run and no signed distribution artifact is recorded |
| CHK008 | Open | Rollback and release review not recorded; hosted cutover evidence is required before wider distribution |
