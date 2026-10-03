---
name: hive
version: "3.0"
last_updated: "2026-10-02"
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
  Hive coordination across repositories with GitHub as workflow authority.
  Use when finding routed work or checking the common pilot's acceptance boundary.
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

## Workflow-state authority

Read [`label-workflow.md`](./label-workflow.md) before triaging common work.
It defines the **common-only** pilot, overlays, analysis preference, and
trusted human acceptance gate. Other repositories retain their local numbered
or `queue/*` contracts; read their `AGENTS.md` rather than applying this pilot.

Common issues use one lifecycle stage; PRs use native GitHub assignment and
review status. Preserve descriptive and operational labels alongside
`agent/*` and `hive/*` routing. Reporter machine-analysis consent is not
implementation acceptance; immutable labeled-event authority and unchanged
issue-body scope establish acceptance, not the label's presence alone.

The common runtime uses native `needs-human` enumeration gating for
unaccepted or human-only work. It introduces no global Hive approval API or
deployment change. Hive `ready` is not a verified accepted-label admission
gate, and local reconciliation cannot guarantee scheduling enforcement for
cached, assigned, or differently configured workers. Verify the human
acceptance record, scope, assignment, overlays, and preference before acting.

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

Common owns its local policy script, catalog, and issue-lifecycle workflow.
Report intake automation is a separate integration, and other repositories
retain their local lifecycle callers. This pilot changes none of those
implementations or Hive's deployment, authentication, or secrets.

Agents act only on accepted, assigned or explicitly routed common work.
Design, security, cross-repository breakage, approval, review, and merge
decisions remain human gates. Link image reports with `Refs #NNN` while
delivery is unresolved; code-only work satisfied at merge may use
`Closes #NNN`. Delivery/verification transitions require validated human
evidence, not a Hive queue result. Follow the target repository's local PR
linkage rules outside common.

## Verification

- [ ] GitHub identifies the affected repository and issue.
- [ ] Live Hive config or status corroborates the intended repository scope.
- [ ] Missing, stale, or contradictory API fields were escalated instead of guessed.
- [ ] Common issues have at most one pilot stage; PRs have no issue-stage label.
- [ ] Trusted human acceptance and delivery evidence are validated independently
      of Hive readiness, and human-only preferences remain intact.
- [ ] Trust tier and permissions are sufficient for the requested action.
- [ ] Human gates have not been bypassed.

## When to Use

Use this skill when discovering, routing, or verifying factory work across
Project Bluefin repositories.

## When NOT to Use

Do not use it to self-accept work, claim work, bypass review, or operate a
hosted Hive without the relevant hosted-Hive skill. Trusted human common
triage follows the label-picker procedure in the label-workflow skill.

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
- Common work accepted from machine-analysis consent, a body edit, an old
  queue, or Hive readiness instead of an authorized human decision.
- A label or slash command used as an unverified state transition.
