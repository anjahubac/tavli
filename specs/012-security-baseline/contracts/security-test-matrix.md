# Security verification matrix

Status: planned evidence. No test below is claimed executed by this revision.
Keep normal allowed cases alongside negative ones; a system that denies all
access is not correct. Use synthetic data and local services, never hosted probes.

| Requirement / risk | Allowed case | Denied / failure cases | Evidence owner |
| --- | --- | --- | --- |
| FR-001 / SEC-06 | Member uses own household data; user sees own personal row | anon; other household; forged parent ID; ownership UPDATE; private row by co-member; RPC execute; object rename across households | Dev 3 + Dev 1, pgTAP |
| FR-002 / SEC-01 | Valid user sends allowed bounded task | missing/invalid token; supplied other uid; arbitrary URL/model; oversized input; quota race; cancel/retry budget | Dev 2, fake provider + local gateway |
| FR-003 / SEC-03 | Serbian category/action shown | provider body, token-shaped fixture, recipe/email or raw exception in UI/attempt/toString/log | Dev 2 + Dev 3, unit/widget |
| FR-004 / SEC-02 | Valid recipe photo read/write/delete/sync | ../, absolute names, alternate separators, invalid snapshot name, encoded traversal, symlink escape, oversized/corrupt image | Dev 1 + Dev 4, temp files and sync fixtures |
| FR-005 / SEC-05 | Valid current OTP creates session | expired/replayed/wrong code; throttled resend/verify; malicious redirect; callback for wrong environment; expired/revoked session | Dev 3, fake auth + local stack; operator settings evidence |
| FR-006 / SEC-04 | Same account returns to retained cache | new account/project sees prior session/data; queued write changes household; failed migration loses unsynced edits | Dev 3 + Dev 1, migration/account tests |
| FR-007 / SEC-04 | Approved OS/storage and backup behavior | secrets in plain prefs; sensitive data in backup/export; raw cycle dates synced/logged; stale hint persists | Dev 4 + Dev 3, device evidence and fixtures |
| FR-008 / SEC-07 | Valid self deletion completes/retries | missing token; forged uid; interrupted photo/data/auth deletion; member removal during replay; incorrect shared-household deletion | Dev 3 + Dev 1, local function/SQL |
| FR-009 / SEC-08 | Reviewed same-SHA checks pass then deploy | failed/missing/stale check still deploys; untrusted fork gains secrets | Dev 3 + Anja, credential-free CI proof |
| FR-010 / SEC-08 | Reviewed locked/signed build | injected dependency/secret fixture misses scanner; unreviewed action update; wrong environment artifact | Dev 3 + Dev 4, redacted build evidence |
| FR-011 | Authorized book/document/draft operation | cross-household chunk retrieval; prompt instructions execute command; deleted book still retrieved; raw upload retained | Feature owner + Dev 3, later feature fixtures |
| FR-012 | Operators follow containment/restore checklist | missing owner, inaccessible kill switch, no recovery evidence or secrets in incident ticket | Anja + team, local tabletop |

Record command/fixture, tested SHA/platform, expected/actual result, reviewer,
residual risk and linked task. Never substitute a passed Flutter suite for an
unrun SQL/device/hosted-configuration check. Approved risk exceptions must name
scope, owner, expiration and mitigations; High blockers defer affected release.
