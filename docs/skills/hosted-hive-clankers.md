---
name: hosted-hive-clankers
version: "1.2"
last_updated: "2026-07-29"
id: hosted-hive-clankers
one_line_purpose: Receive and verify authenticated Hive work via Clankers.
entry_point: docs/skills/hosted-hive-clankers.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [clankers, hive, websocket, github]
description: >-
  Receive authenticated Hive work through the Clankers contributor WebSocket
  while verifying task identity, trust-tier permissions, and credentials.
metadata:
  type: runbook
  context7-sources:
    - /websites/github_en_rest
---

# Clankers work relay

Clankers is an authenticated adapter to the Hive contributor protocol. It is
not a second queue or assignment authority. Hive selection may target
`common` or another monitored repository; verify the assigned repository and
issue before acting.

## Availability

Use the operator-supplied relay origin. When connecting via Clankers, connect to
`wss://clankers.projectbluefin.io/v1/connect` (manifest at `https://clankers.projectbluefin.io/`,
health at `/health`, profile at `/v1/me`). Upstream Hive spokes are hosted under
`*.hive.hivecommons.dev` (migrated from legacy `*.hive.kubestellar.io`) with the
contributor WebSocket at `/api/contribute/ws` (`/contribute` is the HTML landing page).
When the deployment exposes `GET /api/contribute/status`, inspect `hub`,
`active_contributors`, `total_registered`, and `actionable_items`. If reachability,
path, or domain differs from the checked-in source, treat the relay as ambiguous.

## Registration and contributor protocol

Follow the checked-in request and message contract:

1. If registration is required, `POST /api/contribute/register` with
   `{"github_username":"..."}`. Success returns `contributor_id`,
   `registration_token`, and a `message`. Re-registration may return the
   existing credential; invalid usernames fail with `400`.
2. Open the operator-supplied WebSocket and require the first frame to be
   `auth_challenge` with a `nonce`.
3. Send `{"type":"auth_response","registration_token":"...","cli_backend":"...","model":"..."}`.
   On direct Hive endpoints (`/api/contribute/ws`), pass `registration_token`,
   `cli_backend`, and `model`. Ephemeral task-scoped GitHub tokens are minted
   by the hub and delivered later with `task_assign` — never send personal tokens.
4. Accept only `auth_ok`; inspect `contributor_id`, `trust_tier`, and the
   returned `permissions`. `auth_failed` is terminal.
5. Send `{"type":"ready"}` only after authentication succeeds.
6. Awaiting assignment: Hive v2 returns either `task_assign` or explicit
   `task_unavailable` with a machine-readable reason (`hub_not_ready`,
   `contribution_suspended`, `tier_disabled`, `concurrency_limit`,
   `hourly_limit`, `daily_limit`, `no_matching_work`, `role_not_permitted`,
   or `token_mint_failed`).
7. On `task_assign`, inspect `task_id`, `kind`, `repo`, `number`, and `title`.
   Candidate selection order is: operator priority override (`queue_order`),
   contributor's own work (`#2390`), opt-in label interests (`#2637`), fewer
   recent failures (`#2435`), then scan order. Items must carry `3-clanker-queue`
   when label allow-filtering is enabled.
   The assignment may also carry ephemeral `github_token`,
   `token_expires_at`, `restrictions`, and `contributor_labels`. Verify `repo`
   and `number` against GitHub before doing work, and never echo the token or
   restriction payload.
8. Accept `token_refresh` only for the active task and replace the prior task
   credential without logging either value.
9. Honor `task_revoke`; stop work for that `task_id` and do not continue
   writing after revocation.
10. Maintain liveness. Respond to `ping` with `pong` while preserving `seq`, and
   treat a missing ping, missing pong, closed socket, or mismatched task ID as
   a stop-and-escalate condition. Send periodic `task_progress` (every 2m with
   recent tmux output) and finish with `task_complete` (with `pr_url`) or
   `task_failed`.

## Trust tiers and permissions

The checked-in APIs recognize `newcomer`, `contributor`, `trusted`, `advisor`,
and `revoked` trust tiers. The checked-in relay returns an explicit
`permissions` list in `auth_ok`; trust that returned list over assumptions.

Source-backed minimums from the checked-in relay are:

- `newcomer`: at least `issues:read` and `issues:comment`;
- higher non-revoked tiers: a broader set that includes `issues:write`,
  `contents:write`, and `pulls:write`.

Do not assume additional capabilities such as merge, review approval, or
special checks access unless they are actually returned by the relay or
separately established by checked-in source. The relay does not grant
permission to bypass repository ownership, canonical labels, human gates,
review, or merge policy.

## Credential safety

Never print raw WebSocket frames. Frames may contain registration or GitHub
tokens, prompts, restrictions, and task metadata. Redact
`registration_token`, `github_token`, credentials, and environment output.
Do not copy credentials into issues, pull requests, logs, or reports. If the
relay must temporarily cache a token for a child process, it must use a
protected runtime directory, restrict permissions, and remove the cache when
the process exits.

If authentication, assignment, repository targeting, trust tier, permissions,
or heartbeat behavior is not established by the live protocol response, stop
and escalate rather than inventing a fallback.

## When to Use

Use this skill when receiving or diagnosing work through the Clankers
contributor relay.

## When NOT to Use

Do not use it as a queue authority, a replacement for GitHub verification, or
an excuse to bypass repository and human gates.

## Core Process

1. Check relay reachability and, when available, `/api/contribute/status`.
2. Register only through the documented API.
3. Authenticate with the registration-token protocol.
4. Inspect trust tier and returned permissions.
5. Verify each assignment in GitHub before acting.
6. Maintain liveness and stop on ambiguity.

## Common Rationalizations

- **"Authentication succeeded, so the task is trusted."** Inspect the returned
  trust tier and permissions.
- **"The assignment is authoritative."** Verify repository and issue identity.
- **"The tier name implies the capability."** Use the live `permissions` list.

## Red Flags

- Raw WebSocket frames or credentials in logs.
- Missing `auth_ok`, task identity, or heartbeat evidence.
- Work performed outside the returned repository or permissions.

## Verification

- [ ] Registration and authentication responses were checked.
- [ ] Trust tier and returned permissions were reviewed.
- [ ] Assignment identity matches GitHub.
- [ ] Credentials were redacted.
- [ ] Liveness failures or revoked tasks were escalated.
