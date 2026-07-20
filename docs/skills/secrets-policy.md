---
name: secrets-policy
version: "1.0"
last_updated: "2026-07-20"
tags: [secrets, security, ci]
description: >-
  Approved secrets inventory for the Bluefin factory. Use when adding a secret,
  reviewing workflow auth, or verifying whether PATs or a new credential are
  allowed.
metadata:
  type: policy
---

# Secrets Policy — Project Bluefin Factory

**PATs (Personal Access Tokens) are banned.** This is a hard rule with no exceptions.

## Rationale

PATs are user-scoped credentials that:
- Expire or get revoked silently, causing cascading CI failures
- Can't be audited per-workflow (one token, unlimited scope)
- Leave a blast radius tied to an individual's account
- Are forbidden by the supply chain security model (SLSA L2+)

GitHub App tokens and the built-in `GITHUB_TOKEN` provide the same capabilities with narrower scope, automatic rotation, and full audit trails.

## Approved secrets (frozen set)

Additions require a **security review issue** in `projectbluefin/common` before the secret is provisioned or referenced in any workflow.

| Secret | Type | Where | Purpose |
|---|---|---|---|
| `GITHUB_TOKEN` | Built-in (automatic) | All repos | Default — use this first |
| `MERGERAPTOR_APP_ID` | GitHub App ID | common, dakota, bonedigger | MERGERAPTOR bot identity |
| `MERGERAPTOR_PRIVATE_KEY` | GitHub App private key | common, dakota, bonedigger | MERGERAPTOR bot auth |
| `CASD_CLIENT_KEY` | TLS client certificate key | dakota | BuildStream remote CAS auth |
| `SIGNING_SECRET` | cosign private key | common | Legacy key-based image signing — pending keyless migration (#513) |

## Rules

1. **No new PATs.** If you think you need a PAT, you don't. Use `GITHUB_TOKEN` or a GitHub App token.
2. **No new secrets without a security review issue.** File an issue in `projectbluefin/common` tagged `kind/security` before provisioning or referencing any new secret name.
3. **GitHub App tokens for cross-repo bot operations.** MERGERAPTOR and BLUEFINBOT are the approved bots. Adding a new bot requires maintainer approval.
4. **`SIGNING_SECRET` is frozen.** It will be removed when keyless signing migration (#513) lands. Do not reference it in any new workflow.
5. **Infrastructure keys** (`CASD_CLIENT_KEY`, Cloudflare R2 keys) are reviewed at provisioning time by org admins and frozen thereafter.

## Enforcement

- **CI gate:** `pat-ban.yml` in `projectbluefin/actions` blocks any PR that introduces a `secrets.XXX` reference not in the approved list above.
- **Pre-commit:** The `no-new-secrets` hook (`.pre-commit-config.yaml`) runs locally before commit.
- **Human gate:** Any new secret addition is a Design gate — stop and request maintainer approval.

## What to do instead of a PAT

| You want to... | Use instead |
|---|---|
| Push to GHCR | `github.token` with `packages: write` |
| Open/update PRs | `github.token` with `pull-requests: write` |
| Create issues | `github.token` with `issues: write` |
| Cross-repo dispatch | MERGERAPTOR App token (already provisioned) |
| Force-push to protected branch | Admin bypass via org ruleset |
| Read private packages | `github.token` (org members get automatic read) |
