---
name: hive-review
version: "1.2"
last_updated: "2026-07-29"
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

## Live reads

Read only the live records you need for the review:

| Request | Intent | Evidence to inspect | Stop when |
|---|---|---|---|
| `GET /api/health` or `GET /api/health/deep` | confirm reachability and readiness | `status`, and for deep health the returned `checks` and `fails` map | readiness, auth, or agent health is degraded and you do not have a documented recovery path |
| `GET /api/config` | confirm Hive identity and repository scope | common fields include `org` and `primaryRepo`; some checked-in deployments also expose `repos`, `projectName`, `dashboardTitle`, `hive_id`, or `hub_url` | the response does not establish which repository set you are reviewing |
| `GET /api/status` | inspect governor mode, agent state, and live queue signals | `governor`, `agents`, `repos`, and any returned `timestamp`, `health`, `hold`, `acmmLevel`, advisory, contributor, or alert data | the response is stale, missing key fields, or conflicts with GitHub |
| `GET /api/summaries` | inspect per-agent task, progress, and result evidence | the specific summary records tied to the issue, PR, or agent being reviewed | the relevant record is absent, truncated, or unverifiable |
| `GET /api/gh-auth` and `GET /api/gh-rate-limits` | confirm GitHub access and active quota alerts | `ok`, `lastChecked`, and current `alerts` | GitHub auth is failing or alerts imply the review is incomplete |

Read the corresponding GitHub repositories directly to confirm issue priority,
evidence, labels, assignments, linked pull requests, and workflow checks.
There is no substitute for the source issue or pull request.

If an endpoint is unavailable or returns an incomplete or contradictory
response, record the exact failure and escalate. Do not reconstruct state from
old output or assume that an absent field means an empty queue.

## Review procedure

1. Confirm Hive identity and monitored repository scope from `/api/config`.
2. Inspect `/api/status` and note freshness evidence, governor mode, holds,
   health, advisory signals, and affected repositories.
3. Inspect `/api/summaries` only as supporting evidence for the specific agent
   or work item under review.
4. Re-open the corresponding GitHub issues and pull requests in each affected
   repository.
5. Verify canonical labels, repository targeting, assignments, linked pull
   requests, and current checks.
6. Separate evidence from recommendations. Put descriptive facts in the issue
   or Hive metadata; do not manufacture queue state.
7. Escalate design, security, cross-repository breakage, approval, review, and
   merge decisions to a human.

Priority terms such as P0 or P1 are evidence to investigate, not labels.
In Prow repositories a maintainer sets priority with `/priority`; use only the
labels documented by [label-workflow](./label-workflow.md).

## Advisory findings

Treat an advisory digest or summary entry as a pointer to source records.
Re-open the referenced GitHub issue, pull request, workflow, or source path
before accepting or closing a finding. Do not edit a generated digest as a
substitute for revalidation. If the digest is stale, truncated, lacks a source,
or depends on a missing timestamp or freshness signal, stop and request a fresh
authoritative read.

## Credential and routing rules

Use the deployment's authenticated API mechanism and redact credentials from
all output. Verify the affected repository before any write. Hive or Clankers
selection does not authorize work in another repository and does not bypass
human approval or merge gates.

## When to Use

Use this skill for a live Hive review, triage pass, advisory refresh, or
verification of urgent work.

## When NOT to Use

Do not use it as a substitute for source inspection, a local status dashboard,
or a workflow mutation procedure.

## Core Process

1. Read live Hive health, configuration, status, summaries, and GitHub auth.
2. Confirm each finding against GitHub.
3. Classify evidence without inventing priority or queue state.
4. Escalate stale, incomplete, or contradictory responses.

## Common Rationalizations

- **"The summary is enough."** Recheck the source issue or pull request.
- **"Missing data means no work."** Treat missing fields as ambiguity.
- **"P0 means I should change labels."** P0 or P1 text is a triage signal,
  not a workflow transition.

## Red Flags

- Cached output presented as current state.
- Priority or queue conclusions without source evidence.
- Tokens or unverified findings copied into GitHub.

## Verification

- [ ] Hive identity, readiness, and repository scope were checked.
- [ ] Every actionable finding was verified in GitHub.
- [ ] Missing freshness evidence or stale data was escalated.
- [ ] Canonical labels and repository targeting were preserved.
