---
name: hive
version: "3.0"
last_updated: "2026-09-13"
id: hive
one_line_purpose: Route factory work through Hive coordination and labels.
entry_point: docs/skills/hive.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [hive, multi-repo, coordination]
description: >-
  KubeStellar Hive coordination and the seven numbered workflow-state labels.
  Use when finding or routing factory work across projectbluefin repositories.
metadata:
  type: reference
  context7-sources:
    - /websites/github_en_rest
---

# The Hive

The Hive coordinates GitHub work across the Project Bluefin factory. GitHub is
the authority for issues, pull requests, assignments, projects, branches, and
labels. The Hive API is the authority only for configured Hive scope, live
governor and agent state, and the contributor or federation state the
deployment actually returns. Never infer repository scope or workflow state
from a hostname, cached output, dashboard chrome, or an agent message.

The deployment host, the HTTP endpoint contract, and the trust tiers live in
[`hosted-hive.md`](./hosted-hive.md). Read them there.

## Workflow-state labels

These seven are the *workflow-state* vocabulary — the labels that encode where
a piece of work sits in the pipeline:

| Label | Meaning |
|---|---|
| `1-triage` | New work awaiting triage |
| `2-discussing` | Discussion or design clarification |
| `3-human-queue` | Human-maintained queue |
| `3-clanker-queue` | Agent-maintained queue |
| `4-review` | Pull request awaiting review |
| `blocked` | Waiting on human input or an external dependency |
| `hold` | Intentionally paused |

They are not the only labels in the org. Descriptive and operational families
coexist with them — `agent/*` role labels, `hive/*` routing labels,
`lgtm`/`automerge`, `quality`, `testing`, `tech-debt`, `architecture`,
`needs-human`, and the `queue/*` dialect that some repositories run instead of
the numbered set. [`label-workflow.md`](./label-workflow.md) is the label
authority; read it before applying any label.

Never hand-edit a numbered label to manufacture a transition. Component,
severity, and source facts belong in the issue body or Hive metadata.

## Finding work

Read GitHub's live issue and pull-request state for the affected organization,
including open work assigned to the agent or routed through the relevant
project. Verify the repository, issue number, title, assignee, and current
labels before acting. The repository named by the work item is the
destination; a Hive control variable is not a destination.

If GitHub data is missing, stale, or contradictory, stop and request
verification. Do not guess an issue, repository, assignee, or queue.

Corroborate scope and runtime state with the Hive reads documented in
[`hosted-hive.md`](./hosted-hive.md#authority-and-authentication) — never as a
replacement for GitHub state. Use only the fields a deployment actually
returns; an absent field is unknown, not empty or false.

## Ownership and gates

`projectbluefin/actions` owns reusable lifecycle automation and
`projectbluefin/bonedigger` owns report intake. This repository documents the
contract; it does not own those implementations.

Agents act only on assigned or project-routed work. Design, security,
cross-repository breakage, approval, review, and merge decisions remain human
gates. Pull requests must link their issue with `Closes #NNN`.

## Red flags

- Queue state inferred from cached output or an agent message.
- More than one numbered workflow label on a single item.
- A label or slash command used as an unverified state transition.
- Repository scope read off the Hive hostname.

## Verification

- [ ] GitHub identifies the affected repository and issue.
- [ ] Live Hive config or status corroborates the intended repository scope.
- [ ] Missing, stale, or contradictory API fields were escalated, not guessed.
- [ ] Exactly one numbered workflow label is present.
- [ ] Trust tier and permissions are sufficient for the requested action.
- [ ] Human gates have not been bypassed.
