---
name: hosted-hive
version: "1.3"
last_updated: "2026-07-29"
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

Use the operator-supplied `HIVE_URL`. Spoke deployments are hosted under
`*.hive.hivecommons.dev` (migrated from legacy `*.hive.kubestellar.io`, with login
hub at `https://hive.hivecommons.dev`). The hostname identifies a deployment,
not a repository. Read the live API before making any decision.

## Authority and authentication

Read the relevant record before acting:

| Request | Intent | Evidence to inspect | Verify after mutation |
|---|---|---|---|
| `GET /api/health` | confirm basic reachability | `status` such as `ok` or `starting` when the endpoint is exposed | not a mutation |
| `GET /api/config` | confirm Hive identity and repository scope | common checked-in fields include `org` and `primaryRepo`; some deployments also expose `projectName`, `repos`, `hive_id`, `hub_url`, `github_base_url`, `eval_interval_s`, or `dashboardTitle` | re-read if scope is part of the decision you just made |
| `GET /api/status` | inspect live governor, agent, and repository state | `governor`, `agents`, `repos`, and any returned `timestamp`, `health`, `hold`, `acmmLevel`, contributor, or alert data | re-read after any operational mutation |
| `GET /api/config/governor` | inspect governor thresholds, labels, budget, health, repo list, and sensing settings | `thresholds`, `labels`, `budget`, `health`, `repos`, and `sensing` when present | re-read the same record after any governor mutation |
| `GET /api/config/agent/{name}` | inspect one agent's effective configuration | `general`, `cadences`, `models`, `pipeline`, `restrictions`, and any returned `hooks`, `stats`, or current prompt text | re-read the same agent after any config mutation |
| `GET /api/config/agent/{name}/prompt` | inspect the effective prompt text | checked-in implementations return prompt text under `prompt`; some also include source metadata such as `agent` or `sourceFiles` | re-read after any prompt change |
| `GET /api/summaries` | inspect task, progress, and result evidence | the returned summary object for the specific agent or work item | re-read after a kick or config change that should alter task state |
| `POST /api/kick/{agent}` | request a transient agent kick | request body may include optional `prompt`; success is `ok: true` with `output` text | always re-read `/api/status` and `/api/summaries` |

Management & Operations controls in Hive v2:
- `hub.contribute_queue_order`: Drag-and-drop operator priority override. Pinned items sort first.
- `hub.contribute_queue_hold`: Per-issue manual park (`%s#%d`). Held items are excluded until resumed.
- `hub.contribute_labels_mode` & `hub.contribute_deny_labels`: Label filter mode (`allow` or `deny`). When `allow`, only issues matching the list (e.g., `3-clanker-queue`) are offered to contributors.
- `hub.disabled_tiers` & `hub.tier_limits`: Disabled tiers (`newcomer`, `contributor`, etc.) and caps on `MaxConcurrent`, `MaxPerHour`, and `MaxPerDay`.


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
creating or changing anything. Use only the canonical seven workflow labels;
descriptive details belong in the issue body or Hive metadata.

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

## Core Process

1. Read health, configuration, status, and summaries.
2. Verify repository and issue identity in GitHub.
3. Confirm authorization before any mutation.
4. Re-read the affected API record and escalate contradictions.

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
