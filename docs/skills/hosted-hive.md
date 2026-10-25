---
name: hosted-hive
version: "1.4"
last_updated: "2026-09-13"
id: hosted-hive
one_line_purpose: Operate hosted Hive APIs with routing and trust safeguards.
entry_point: docs/skills/hosted-hive.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [hive, github, hosted, factory, agents, clankers]
description: >-
  Manage a hosted Hive through its authenticated API while preserving
  repository routing, trust tiers, credential redaction, and human gates.
metadata:
  type: runbook
  context7-sources:
    - /websites/github_en_rest
---

# Hosted Hive

This file is the single home for the hosted Hive deployment host, its HTTP
endpoint contract, and its trust tiers. `hive.md`, `hive-review.md`,
`hive-automerge.md`, and `hosted-hive-clankers.md` link here instead of
restating any of it.

## Deployment host

The org runs one hosted Hive:

```
https://hosted-projectbluefin-knuckle-gjvq.hive.hivecommons.dev
```

`~/.local/bin/sync-hive-kb` reads `/api/v1/knowledge` on that host. The
hostname identifies a deployment, not a repository — never infer repository
scope from it. Prefer an operator-supplied `HIVE_URL` when you are given one.

The zero-auth path to the same live numbers is the `projectbluefin` MCP
server's `get_factory_status()` and `get_work_queue()` tools; the HTTP API
below requires the deployment's own authentication.

## Authority and authentication

Read the relevant record before acting:

| Request | Intent | Evidence to inspect | Verify after mutation |
|---|---|---|---|
| `GET /api/health`, `GET /api/health/deep` | confirm reachability and readiness | `status` such as `ok` or `starting`; deep health also returns a `checks` and `fails` map | not a mutation |
| `GET /api/config` | confirm Hive identity and repository scope | common checked-in fields include `org` and `primaryRepo`; some deployments also expose `projectName`, `repos`, `hive_id`, `hub_url`, `github_base_url`, `eval_interval_s`, or `dashboardTitle` | re-read if scope is part of the decision you just made |
| `GET /api/status` | inspect live governor, agent, and repository state | `governor`, `agents`, `repos`, and any returned `timestamp`, `health`, `hold`, `acmmLevel`, contributor, or alert data | re-read after any operational mutation |
| `GET /api/config/governor` | inspect governor thresholds, labels, budget, health, repo list, and sensing settings | `thresholds`, `labels`, `budget`, `health`, `repos`, and `sensing` when present | re-read the same record after any governor mutation |
| `GET /api/config/agent/{name}` | inspect one agent's effective configuration | `general`, `cadences`, `models`, `pipeline`, `restrictions`, and any returned `hooks`, `stats`, or current prompt text | re-read the same agent after any config mutation |
| `GET /api/config/agent/{name}/prompt` | inspect the effective prompt text | checked-in implementations return prompt text under `prompt`; some also include source metadata such as `agent` or `sourceFiles` | re-read after any prompt change |
| `GET /api/summaries` | inspect task, progress, and result evidence | the returned summary object for the specific agent or work item | re-read after a kick or config change that should alter task state |
| `POST /api/kick/{agent}` | request a transient agent kick | request body may include optional `prompt`; success is `ok: true` with `output` text | always re-read `/api/status` and `/api/summaries` |
| `GET /api/gh-auth`, `GET /api/gh-rate-limits` | confirm the deployment's GitHub access and quota alerts | `ok`, `lastChecked`, and current `alerts` | re-read if a write failed on auth or quota |

Authenticate using the deployment's supported bearer, cookie, or session
mechanism. Never print, persist, echo, or place tokens in JSON, prompts,
issue bodies, or reports. Treat mutating requests as privileged and confirm the
caller's role or trust tier before sending them.

If the response shape differs from the checked-in implementations, use only the
fields actually returned. If the deployment does not establish the field,
permission, or mutation behavior you need, stop and escalate.

## Repository targeting

Use live `repos` and `primaryRepo` data only to understand Hive scope. Findings
belong to the repository named by the evidence, not automatically to the
primary repository. Verify the target repository and issue in GitHub before
creating or changing anything. Workflow state goes in the numbered workflow
labels defined by [`label-workflow.md`](./label-workflow.md); descriptive
details belong in the issue body or Hive metadata.

If repository scope, issue identity, or authorization is ambiguous, stop and
escalate rather than guessing.

## Agent configuration and kicks

`POST /api/kick/{agent}` is an operational request, not a configuration change.
Use it only when a maintainer has authorized the action and the agent appears
in the configured fleet. A prompt supplied in the request body is transient and
must remain credential-free.

Do not claim that a kick, config change, or permission change succeeded until
the follow-up read proves it. If the endpoint returns an error, lacks
post-mutation evidence, or behaves differently from the checked-in contract,
stop and ask a maintainer.

Do not change ACMM autonomy, merge policy, hold behavior, GitHub App
permissions, trust tiers, or repository scope without an explicit maintainer
decision.

## Trust tiers

Live `get_factory_status()` reports five tiers, each with its own contribution
limit: `newcomer`, `contributor`, `trusted`, `merger`, `advisor`. `merger` is
the tier the queue-automerge action in
[`hive-automerge.md`](./hive-automerge.md) requires.

The relay returns an explicit `permissions` list at authentication time. Trust
that returned list over any inference from the tier name, and never assume
merge, review-approval, or checks access that the deployment did not return.

## Advisory refresh boundary

Use GitHub as the source for advisory issues and the Hive API for live agent
configuration and status. Revalidate each referenced issue, pull request,
workflow, or source path before closing or replacing a finding. Editing a
generated comment alone is not a durable refresh. If the API does not expose
the required operation or result, stop at the hosted-configuration boundary
and request a separate human-approved change.

## Verification

- [ ] Relevant config, status, and summary responses were read before acting.
- [ ] GitHub confirms the affected repository, issue, labels, and checks.
- [ ] The caller's trust tier and role authorize the requested operation.
- [ ] Post-mutation reads confirmed the intended result.
- [ ] Credentials are redacted.
- [ ] Human design, security, breakage, approval, review, and merge gates remain intact.

## When to Use

Use this skill when reading or operating a hosted Hive through its documented
HTTP API.

## When NOT to Use

Do not use it to invent undocumented endpoints, change permissions, or treat a
hostname as repository scope.

## Common Rationalizations

- **"The request succeeded."** Verify the resulting API state.
- **"The primary repository is the target."** Use the repository named by the
  evidence.
- **"The field exists in another deployment."** Use only the fields this
  deployment actually returned.

## Red Flags

- Tokens in command output, prompts, or reports.
- Unsupported mutation claims.
- ACMM, trust, or merge policy changed without maintainer approval.
