---
name: hive-review
version: "2.0"
last_updated: "2026-09-13"
id: hive-review
one_line_purpose: Review live Hive and GitHub state for actionable work.
entry_point: docs/skills/hive-review.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [hive, review, code-review]
description: >-
  Review live Hive and GitHub state for urgent work, advisory findings, and
  agent-ready issues without relying on derived local state.
metadata:
  type: reference
  context7-sources:
    - /websites/github_en_rest
---

# Hive review

Use this skill when reviewing priority work or starting a triage pass. The
authoritative sources are the live Hive API for agent and governor state and
the GitHub API for issues, pull requests, labels, assignments, projects, and
workflow results.

The endpoints, the deployment host, and the authentication rules are in
[`hosted-hive.md`](./hosted-hive.md#authority-and-authentication). This file
only adds the review procedure.

## Review procedure

1. Confirm Hive identity and monitored repository scope from `/api/config`.
2. Inspect `/api/status` and note freshness evidence, governor mode, holds,
   health, advisory signals, and affected repositories.
3. Check `/api/gh-auth` and `/api/gh-rate-limits` when a write has failed or a
   quota alert is plausible — a throttled deployment produces an incomplete
   review.
4. Inspect `/api/summaries` only as supporting evidence for the specific agent
   or work item under review.
5. Re-open the corresponding GitHub issues and pull requests in each affected
   repository. There is no substitute for the source issue or pull request.
6. Verify workflow-state labels, repository targeting, assignments, linked
   pull requests, and current checks.
7. Separate evidence from recommendations. Put descriptive facts in the issue
   or Hive metadata; do not manufacture queue state.
8. Escalate design, security, cross-repository breakage, approval, review, and
   merge decisions to a human.

Priority terms such as P0 or P1 are evidence to investigate, not workflow
labels. The label vocabulary is defined in
[`label-workflow.md`](./label-workflow.md).

If an endpoint is unavailable or returns an incomplete or contradictory
response, record the exact failure and escalate. Do not reconstruct state from
old output, and do not assume an absent field means an empty queue.

## Advisory findings

Treat an advisory digest or summary entry as a pointer to source records.
Re-open the referenced GitHub issue, pull request, workflow, or source path
before accepting or closing a finding. Editing a generated digest is not a
substitute for revalidation. If the digest is stale, truncated, lacks a
source, or depends on a missing timestamp, stop and request a fresh
authoritative read.

## Routing rules

Verify the affected repository before any write. Hive or Clankers selection
does not authorize work in another repository and does not bypass human
approval or merge gates. Redact credentials from all output.

## Red flags

- Cached output presented as current state.
- Priority or queue conclusions without source evidence.
- Tokens or unverified findings copied into GitHub.

## Verification

- [ ] Hive identity, readiness, and repository scope were checked.
- [ ] Every actionable finding was verified in GitHub.
- [ ] Missing freshness evidence or stale data was escalated.
- [ ] Workflow-state labels and repository targeting were preserved.
