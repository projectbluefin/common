---
name: hive
version: "2.3"
last_updated: "2026-09-24"
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
  KubeStellar Hive coordination, Trust the Machines routing, and the canonical
  seven-label workflow. Use when finding or routing factory work.
metadata:
  type: reference
  context7-sources:
    - /websites/github_en_rest
---

# The Hive

The Hive coordinates GitHub work across the Project Bluefin factory. GitHub is
the authority for issues, pull requests, assignments, projects, branches, and
labels. The Hive API is the authority only for configured Hive scope, live
governor and agent state, and contributor or federation state exposed by the
checked-in API. Do not infer repository scope or workflow state from a
hostname, cached output, dashboard chrome, or an agent message.

## Canonical workflow labels

The only labels that **route workflow state** are:

| Label | Meaning |
|---|---|
| `1-triage` | New work awaiting triage |
| `2-discussing` | Discussion or design clarification |
| `3-human-queue` | Human-maintained queue |
| `3-clanker-queue` | Agent-maintained queue |
| `4-review` | Pull request awaiting review |
| `blocked` | Waiting on human input or an external dependency |
| `hold` | Intentionally paused |

Workflows own these seven labels. Never invent, add, remove, or hand-edit
workflow state. Repository-local product labels may describe kind or ownership;
they never substitute for assignment, a reviewed specification, a plan, or
Hive admission. Put other details in the issue body or project fields.

## Finding work

Read GitHub's live issue and pull-request state for the affected organization,
including open work assigned to the agent or routed through the relevant
project. Verify the repository, issue number, title, assignee, and current
labels before acting. The repository named by the work item is the destination;
a Hive control variable is not a destination.

If GitHub data is missing, stale, or contradictory, stop and request
verification. Do not guess an issue, repository, assignee, or queue.

## Hive reads

Use Hive reads to corroborate scope and runtime state, not to replace GitHub
state:

| Request | Intent | Evidence to inspect | Stop when |
|---|---|---|---|
| `GET /api/config` | confirm organization and repository scope | common checked-in fields include `org` and `primaryRepo`; some deployments also return `repos`, `hive_id`, `hub_url`, `github_base_url`, `eval_interval_s`, `projectName`, or `dashboardTitle` | the response omits the routing fields you need or conflicts with GitHub |
| `GET /api/status` | inspect live governor, agent, and repository state | `agents`, `governor`, and `repos`; some deployments also include `timestamp`, `hiveId`, `health`, `hold`, `acmmLevel`, contributor, or alert data | the status is stale, lacks freshness evidence, or does not match GitHub |
| `GET /api/summaries` | inspect per-agent task, progress, and result evidence | the returned summary object for the specific agent or issue under review | an agent record is absent, truncated, or ambiguous enough that you would have to guess |

Use only the fields actually returned by the deployment you are reading. If a
field is absent, treat that fact as unknown rather than empty or false. When a
status response includes a timestamp, inspect it. When it does not, treat
freshness as unknown and corroborate with a second read or direct GitHub state.

Use authenticated requests as required by the deployment. Never print,
persist, or include tokens in logs, prompts, issue bodies, or task reports.

## Ownership and gates

`projectbluefin/bonedigger` owns the reusable lifecycle automation (the
`.github/workflows/lifecycle.yml` reusable workflow, pinned as a `workflow_call`
in each consumer's own `.github/workflows/bonedigger.yml`) and report intake.
This repository documents the contract; it does not own those implementations.

Agents act only on assigned or project-routed work. Design, security,
cross-repository breakage, approval, review, and merge decisions remain human
gates. Pull requests must link their issue with `Closes #NNN`.

## Verification

- [ ] GitHub identifies the affected repository and issue.
- [ ] Live Hive config or status corroborates the intended repository scope.
- [ ] Missing, stale, or contradictory API fields were escalated instead of guessed.
- [ ] Only canonical workflow labels route work; product labels do not change state.
- [ ] Trust tier and permissions are sufficient for the requested action.
- [ ] Human gates have not been bypassed.

## When to Use

Use this skill when discovering, routing, or verifying factory work across
Project Bluefin repositories.

## When NOT to Use

Do not use it to mutate labels, claim work, bypass review, or operate a hosted
Hive without the relevant hosted-Hive skill.

## Core Process

1. Read GitHub state for the affected repository.
2. Verify issue, assignment, project, and pull-request identity.
3. Use Hive reads only to corroborate orchestration context and live state.
4. Escalate stale, incomplete, or contradictory API evidence.
5. Preserve workflow ownership and human gates.

## Common Rationalizations

- **"The Hive message names the repository."** Verify the repository in the
  source issue and GitHub API instead.
- **"A product label means Hive will implement it."** Triage and the
  Spektacular runner are optional upstream features; verify live configuration.
- **"The missing field probably means none."** Missing Hive data is ambiguity,
  not permission to infer state.

## Red Flags

- Queue state inferred from cached output or an agent message.
- More than one numbered workflow label.
- A label or slash command used as an unverified state transition.
