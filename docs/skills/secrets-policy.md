---
name: secrets-policy
version: "1.0"
last_updated: "2026-09-26"
id: secrets-policy
one_line_purpose: Keep existing workflow authentication inside the factory security boundary.
entry_point: docs/skills/secrets-policy.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [secrets, security, ci]
description: >-
  Existing workflow authentication and the prohibition on new credentials.
  Use when reviewing auth, diagnosing a missing existing secret, or checking
  whether a PAT or credential reference is allowed.
metadata:
  type: policy
---

# Secrets Policy — Project Bluefin Factory

**PATs (Personal Access Tokens) are banned.** This is a hard rule with no exceptions.

## When to Use

Review an existing workflow's authentication or diagnose a missing credential;
never use this skill to invent a new secret or token.

## Rationale

PATs are user-scoped credentials that:
- Depend on an individual's account and can expire outside a workflow's lifecycle
- Make rotation and ownership harder to audit for a single automation task
- Tie access to a user rather than the owning repository's automation identity
- Violate the factory's explicit no-PAT policy

GitHub App tokens and the built-in `GITHUB_TOKEN` provide the same capabilities with narrower scope, automatic rotation, and full audit trails.

## Approved secrets (frozen set)

These existing names were approved for their listed owners; an entry does not
authorize an agent to add, copy or provision a credential. Verify current
workflow use and the owning repo's security review before relying on one.

| Secret | Type | Where | Purpose |
|---|---|---|---|
| `GITHUB_TOKEN` | Built-in (automatic) | All repos | Default — use this first |
| `MERGERAPTOR_APP_ID` | GitHub App ID | common, dakota, bonedigger | MERGERAPTOR bot identity |
| `MERGERAPTOR_PRIVATE_KEY` | GitHub App private key | common, dakota, bonedigger | MERGERAPTOR bot auth |
| `CASD_CLIENT_KEY` | TLS client certificate key | dakota | BuildStream remote CAS auth |

`common/build.yml` now signs with keyless OIDC. Do not reintroduce
`SIGNING_SECRET`, even though the external actions PAT-ban allowlist still
mentions that retired name.

### Reported use pending security review

These historically observed names are **not approved by this table**. Check
their owning workflows and security-review issues before treating them as
current, provisioned or safe to reuse.

| Secret | Reported owner | Review status |
|---|---|---|
| `CLOUDFLARE_API_TOKEN` | `projectbluefin/documentation` countme worker | No recorded approval; see [common#1091](https://github.com/projectbluefin/common/issues/1091) |
| `CLOUDFLARE_ACCOUNT_ID` | `projectbluefin/documentation` countme worker | No recorded approval; see [common#1091](https://github.com/projectbluefin/common/issues/1091) |
| `BLUEFINBOT_TOKEN` | `projectbluefin/actions` | Security review pending |
| `SYSUPDATE_SIGNING_KEY` | `projectbluefin/server` | Security review pending |

## Rules

1. **No new PATs.** Use the built-in `GITHUB_TOKEN` or an already-configured
   GitHub App token only when the owning repo authorizes it.
2. **No new secrets in agent work.** Agents must never create, propose, or add
   a credential or `secrets.NEW_THING` reference. If a human independently
   considers a new credential, a **security-review issue in
   `projectbluefin/common`** is required before provisioning or referencing
   it; stop at the [human security gate](human-gates.md).
3. **Existing cross-repo bots use their reviewed App identity.** MERGERAPTOR
   and BLUEFINBOT are existing bot identities, not a reason to register a new
   App or extend credentials to another repository.
4. **Signing in `common` is keyless.** `SIGNING_SECRET` was retired; never add
   it to a new workflow or treat its old allowlist entry as current usage.
5. **Infrastructure keys** remain owned by the repository and human admins
   that provisioned them; do not assume this document grants access.
6. **Fail fast when an existing credential is absent.** An owning workflow
   must diagnose the missing name before the step that uses it. Do not fall
   back to a PAT, skip the protected action or reuse another repository's key.

## Enforcement

- **CI check:** `projectbluefin/actions`' `pat-ban.yml` checks added YAML lines
  in that repository. Its allowlist is not a factory-wide policy or proof a
  credential is still needed; `common` has no equivalent local pre-commit hook.
- **Human gate:** A human considering a new credential needs a security-review
  issue before any provisioning. Agents stop; they never propose or add it.
- **Unreviewed use:** The reported names above remain findings for their
  owners to verify, not additions to the approved set.

## What to do instead of a PAT

| Need | Existing GitHub primitive |
|---|---|
| Push to GHCR | `github.token` with `packages: write` where granted |
| Open/update PRs | `github.token` with `pull-requests: write` where granted |
| Create issues | `github.token` with `issues: write` where granted |
| Cross-repo dispatch | An already-provisioned MERGERAPTOR App token, when the owning workflow is authorized |
| Read private packages | `github.token` only when the owning repo grants access |

Never force-push to a protected branch or bypass its ruleset.

## Red Flags

- A diff introduces `secrets.NEW_THING` or revives `SIGNING_SECRET`.
- A green PAT-ban check in `actions` is treated as factory-wide approval.
- A missing credential is replaced with a PAT, silent skip, or admin bypass.

## Verification

- [ ] Compare proposed auth with the owning repository's current workflow.
- [ ] No new credential names, secret references or PATs were added or proposed.
- [ ] Existing credential failures stop for a human security decision.
