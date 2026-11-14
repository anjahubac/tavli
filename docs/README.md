# Development documentation

All maintained engineering documentation is written in English. Exact app copy
remains Serbian (Latin). Start here before asking an AI agent to change Tavli.

| Document | Purpose |
| --- | --- |
| [Architecture](architecture.md) | Verified current structure, boundaries and planned evolution |
| [Product design](product-design.md) | Current product decisions and UX acceptance rules |
| [Product plan](product-plan.md) | Six delivery phases and decisions from the supplied revision |
| [Roadmap](roadmap.md) | Implementation status and feature order |
| [Team workflow](development/team-workflow.md) | Owners, reviews, branches, integration and workload |
| [AI development](development/ai-development.md) | Context, prompts, evidence and agent handoffs |
| [Shared contracts](../specs/011-team-development/contracts/shared-boundaries.md) | Interfaces to agree before parallel work |
| [UI standard](development/ui-standard.md) | Existing themes/components, adaptive layouts and interaction rules |
| [Quality and releases](development/quality-gates.md) | Required checks by change type; local versus hosted operations |
| [Testing strategy](development/testing.md) | Test tiers, fixtures, journeys and CI evidence |
| [Source task mapping](development/source-task-map.md) | All 87 source cards mapped to requirements and tasks |
| [Release and operations](../specs/033-release-operations/spec.md) | Distribution, environments, monitoring and recovery |
| [Security baseline](development/security.md) | Threat model, source findings, priorities and verification |
| [Security implementation spec](../specs/012-security-baseline/spec.md) | Owned remediation slices and negative test matrix |
| [Review findings](development/review-2026-11-13.md) | Scope, evidence, contradictions and unresolved decisions |
| [Flutter practices](flutter-best-practices.md) | Coding conventions for the existing stack |
| [Spec index](../specs/README.md) | Historical specs, current overlays and new feature preparation |
| [Team standardization spec](../specs/011-team-development/spec.md) | Requirements and acceptance criteria for this revision |

Authority: explicit owner decisions → constitution → AGENTS.md → current product
decisions/ADRs → active feature contracts → implementation plan/tasks. Historical
requirements remain evidence of what was originally accepted; see the 010 overlay.
Trello tracks assignments/status, while versioned specs define acceptance.

Code in a different repository, including `tavli-next`, is reference material.
Its presence does not prove that a feature exists here or authorize copying it.
