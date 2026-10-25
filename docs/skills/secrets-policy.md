---
name: secrets-policy
version: "1.1"
last_updated: "2026-09-13"
id: secrets-policy
one_line_purpose: Verify secrets and credentials against the approved inventory.
entry_point: docs/skills/secrets-policy.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
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

## Approved secrets

The authoritative list is the `APPROVED` array in
[`projectbluefin/actions/.github/workflows/pat-ban.yml`](https://github.com/projectbluefin/actions/blob/main/.github/workflows/pat-ban.yml).
Read it there; this table is a convenience copy and the workflow wins.

| Secret | Type | Where | Purpose |
|---|---|---|---|
| `GITHUB_TOKEN` | Built-in (automatic) | All repos | Default — use this first |
| `MERGERAPTOR_APP_ID` | GitHub App ID | common, dakota, bonedigger | MERGERAPTOR bot identity |
| `MERGERAPTOR_PRIVATE_KEY` | GitHub App private key | common, dakota, bonedigger | MERGERAPTOR bot auth |
| `BLUEFINBOT_APP_ID` | GitHub App ID | org | BLUEFINBOT identity |
| `BLUEFINBOT_PRIVATE_KEY` | GitHub App private key | org | BLUEFINBOT auth |
| `CASD_CLIENT_KEY` | TLS client certificate key | dakota | BuildStream remote CAS auth |
| `SIGNING_SECRET` | cosign private key | common | Legacy key-based image signing |
| `DISCORD_RELEASES_WEBHOOK` | Webhook URL | org | `#releases` forum notifications |

`pat-ban.yml` also tolerates the `R2_*` Cloudflare keys, which it marks as
`iso` only and out of scope for the factory.

## Rules

1. **No new PATs.** If you think you need a PAT, you don't. Use `GITHUB_TOKEN` or a GitHub App token.
2. **No new secrets without a security review issue.** File an issue in `projectbluefin/common` describing the security review before provisioning or referencing any new secret name.
3. **GitHub App tokens for cross-repo bot operations.** MERGERAPTOR and BLUEFINBOT are the approved bots. Adding a new bot requires maintainer approval.
4. **`SIGNING_SECRET` is frozen.** Do not reference it in any new workflow. It
   is superseded whenever keyless signing lands.
5. **Infrastructure keys** (`CASD_CLIENT_KEY`, Cloudflare R2 keys) are reviewed at provisioning time by org admins and frozen thereafter.

## Enforcement

- **CI gate, `projectbluefin/actions` only.** `pat-ban.yml` diffs a PR against
  its base and exits 1 on any `secrets.XXX` reference outside its `APPROVED`
  array. It is triggered by `on: pull_request: branches: [main]` and has **no
  `workflow_call`**, so it is not reusable and no other repo can call it.
  `common` has no caller and is **not** covered.
- **Pre-commit.** The only secret-shaped hooks in `.pre-commit-config.yaml` are
  upstream `detect-private-key` and the local `no-discord-token` pygrep. Neither
  validates secret *names* against the approved list.
- **Human gate.** Everywhere except `projectbluefin/actions`, this policy is
  enforced by review alone. Treat a new secret as a Security gate — see
  [human-gates.md](human-gates.md).

## What to do instead of a PAT

| You want to... | Use instead |
|---|---|
| Push to GHCR | `github.token` with `packages: write` |
| Open/update PRs | `github.token` with `pull-requests: write` |
| Create issues | `github.token` with `issues: write` |
| Cross-repo dispatch | MERGERAPTOR App token (already provisioned) |
| Force-push to protected branch | Nothing — `main`'s ruleset sets `non_fast_forward` with no bypass actors |
| Read private packages | `github.token` (org members get automatic read) |

## Verification

- [ ] The approved list here still matches the workflow:

  ```bash
  gh api repos/projectbluefin/actions/contents/.github/workflows/pat-ban.yml \
    --jq '.content' | base64 -d | sed -n '/APPROVED=(/,/)/p'
  ```

- [ ] `pat-ban.yml` is still not reusable (no `workflow_call` trigger) and no
      workflow in this repo calls it: `grep -rn 'pat-ban' .github/` is empty.
- [ ] `.pre-commit-config.yaml` still has no hook that checks secret names:
      `grep -n 'no-new-secrets' .pre-commit-config.yaml` is empty.
