# Release evidence contract

Status: required template; no release has been performed by this revision.

| Evidence | Required content | Owner |
| --- | --- | --- |
| Candidate | Version/build, immutable commit, platform, environment, artifact checksum | Dev 4 |
| Validation | Same-SHA Flutter/SQL/security/device results; actual limitations, reviewer | Dev 3 + feature owners |
| Compatibility | Supported older clients/cache versions, schema order, queued writes, cleanup limits | Dev 1 |
| AI operations | Gateway task/model configuration version, limits, disable/rotation operator | Dev 2 |
| Distribution | Verified signing/store access and URL, staged rollout where supported | Anja |
| Recovery | Compatible artifact, forward-repair approach, synthetic restore drill, verified backup limits | Dev 1 + Dev 3 |
| Operations | Sanitized alert categories/thresholds, on-call owner, redacted support procedure | Dev 3 |
| Approval | Independent review and authorized production approver, timestamp and decision | Anja |

A candidate with missing mandatory evidence is not released. Never substitute
stale checks, a different commit or a simulator screenshot for required proof.
Don't include keys, tokens, signed URLs, personal screenshots or signing material.
A store link is verified separately; the website displays Uskoro until it exists.
