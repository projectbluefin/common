---
name: factory-improvement
version: "1.3"
last_updated: "2026-10-07"
id: factory-improvement
one_line_purpose: Audit and propose task-scoped factory automation improvements.
entry_point: docs/skills/factory-improvement/SKILL.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [factory, automation, improvement]
description: >-
  Use for an explicitly requested factory automation audit, workflow gap
  investigation, or repository onboarding assessment.
metadata:
  type: reference
---

# Factory improvement

Use for a scoped automation assessment, not routine bug fixes, single-PR
reviews, or incident response. Measure the requested behavior against current
workflows and failures before proposing automation; avoid enforcing identical
infrastructure on repositories with different needs.

Human triage acceptance, review/merge approval, release blocker calls,
production go/no-go, and stale PR reassignment or closure remain human decisions.
Do not automate them without explicit maintainer approval. The `ublue-os/*`
write prohibition has no automation exception. Other boundaries and accepted-work
routing are in [AGENTS.md](../../../AGENTS.md).

Choose the smallest accepted improvement. Verify the changed behavior using the
target repo's checks; update documentation only if it becomes inaccurate or a
reusable operational constraint needs recording. A factory assessment does not
require a skill update, a docs migration, or a new issue for every observation.
Keep actionable backlog in GitHub rather than appending status lists here.

Optional detail:
- [Audit queries and E2E coverage](references/loop-detail.md)
- [CI pitfalls and cross-repo dispatch](references/ci-patterns.md)
