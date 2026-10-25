---
name: hosted-hive-clankers
version: "1.3"
last_updated: "2026-09-13"
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

Use the operator-supplied relay origin; the org's hosted deployment host is
named in [`hosted-hive.md`](./hosted-hive.md#deployment-host). When the
deployment exposes `GET /api/contribute/status`, inspect `hub`,
`active_contributors`, `total_registered`, and `actionable_items` before
treating the relay as ready. The `projectbluefin` MCP tool
`get_factory_status()` returns the same four fields without authentication.

The checked-in direct hub accepts contributor WebSocket connections at
`/contribute`; the checked-in proxy also forwards `/api/contribute/ws`. Use the
endpoint the operator gives you. If reachability, path, or identity differs
from the checked-in source, treat the relay as ambiguous and escalate.

## Registration and contributor protocol

Follow the checked-in request and message contract:

1. If registration is required, `POST /api/contribute/register` with
   `{"github_username":"..."}`. Success returns `contributor_id`,
   `registration_token`, and a `message`. Re-registration may return the
   existing credential; invalid usernames fail with `400`.
2. Open the operator-supplied WebSocket and require the first frame to be
   `auth_challenge` with a `nonce`.
3. Send `{"type":"auth_response","registration_token":"...","cli_backend":"...","model":"..."}`.
   Do not add fields that the
   checked-in protocol does not establish.
4. Accept only `auth_ok`; inspect `contributor_id`, `trust_tier`, and the
   returned `permissions`. `auth_failed` is terminal.
5. Send `{"type":"ready"}` only after authentication succeeds.
6. On `task_assign`, inspect `task_id`, `kind`, `repo`, `number`, and `title`.
   The assignment may also carry ephemeral `github_token`,
   `token_expires_at`, `restrictions`, and `contributor_labels`. Verify `repo`
   and `number` against GitHub before doing work, and never echo the token or
   restriction payload.
7. Accept `token_refresh` only for the active task and replace the prior task
   credential without logging either value.
8. Honor `task_revoke`; stop work for that `task_id` and do not continue
   writing after revocation.
9. Maintain liveness. Respond to `ping` with `pong` while preserving `seq`, and
   treat a missing ping, missing pong, closed socket, or mismatched task ID as
   a stop-and-escalate condition.

## Trust tiers and permissions

The five tiers and their meaning live in
[`hosted-hive.md`](./hosted-hive.md#trust-tiers). The relay returns an explicit
`permissions` list in `auth_ok`; trust that returned list over the tier name.

Source-backed minimums from the checked-in relay:

- `newcomer`: at least `issues:read` and `issues:comment`;
- higher tiers: a broader set that includes `issues:write`, `contents:write`,
  and `pulls:write`.

Do not assume additional capabilities such as merge, review approval, or
special checks access unless the relay actually returns them or checked-in
source establishes them. The relay does not grant permission to bypass
repository ownership, workflow-state labels, human gates, review, or merge
policy.

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
