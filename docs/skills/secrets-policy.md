---
name: secrets-policy
version: "1.0"
last_updated: "2026-09-23"
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

## Approved secrets (frozen set)

Additions require a **security review issue** in `projectbluefin/common` before the secret is provisioned or referenced in any workflow.

| Secret | Type | Where | Purpose |
|---|---|---|---|
| `GITHUB_TOKEN` | Built-in (automatic) | All repos | Default — use this first |
| `MERGERAPTOR_APP_ID` | GitHub App ID | common, dakota, bonedigger | MERGERAPTOR bot identity |
| `MERGERAPTOR_PRIVATE_KEY` | GitHub App private key | common, dakota, bonedigger | MERGERAPTOR bot auth |
| `CASD_CLIENT_KEY` | TLS client certificate key | dakota | BuildStream remote CAS auth |
| `SIGNING_SECRET` | cosign private key | common | Legacy key-based image signing — pending keyless migration (#513) |

### In use, not yet listed above

These secret names are referenced by factory workflows today but have no recorded
security review. Listing them records **observed usage, not approval** — each still
needs the security review issue from Rule 2 before it counts as part of the frozen
set.

| Secret | Referenced by | Status |
|---|---|---|
| `CLOUDFLARE_API_TOKEN` | `projectbluefin/documentation` (`deploy-countme-worker.yml`) | Not provisioned org-wide; worker deploy has failed every run since 2026-07-21 — see #1091 |
| `CLOUDFLARE_ACCOUNT_ID` | `projectbluefin/documentation` (`deploy-countme-worker.yml`) | Not provisioned org-wide — see #1091 |
| `BLUEFINBOT_TOKEN` | `projectbluefin/actions` | In use; security review pending |
| `SYSUPDATE_SIGNING_KEY` | `projectbluefin/server` | In use; security review pending |

## Rules

1. **No new PATs.** If you think you need a PAT, you don't. Use `GITHUB_TOKEN` or a GitHub App token.
2. **No new secrets without a security review issue.** File an issue in `projectbluefin/common` describing the security review before provisioning or referencing any new secret name.
3. **GitHub App tokens for cross-repo bot operations.** MERGERAPTOR and BLUEFINBOT are the approved bots. Adding a new bot requires maintainer approval.
4. **`SIGNING_SECRET` is frozen.** It will be removed when keyless signing migration (#513) lands. Do not reference it in any new workflow.
5. **Infrastructure keys** (`CASD_CLIENT_KEY`, Cloudflare R2 keys) are reviewed at provisioning time by org admins and frozen thereafter.
6. **Fail fast when a credential is absent.** A workflow that consumes a
   non-`GITHUB_TOKEN` secret must check for it **before** the step that uses it and
   exit with a message naming every missing secret. An absent secret then produces a
   one-line diagnosis instead of a mid-deploy failure with an opaque error:

   ```yaml
   - name: Preflight — required secrets
     env:
       CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
       CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
     run: |
       missing=()
       for name in CLOUDFLARE_API_TOKEN CLOUDFLARE_ACCOUNT_ID; do
         [ -n "${!name}" ] || missing+=("$name")
       done
       if [ ${#missing[@]} -gt 0 ]; then
         echo "::error::Missing required secrets: ${missing[*]}" >&2
         echo "See docs/skills/secrets-policy.md — provisioning is a human gate." >&2
         exit 1
       fi
   ```

   Reference the policy, not a workaround: a failed preflight means the credential
   has not been provisioned, which is a human security decision (Rule 2), never a
   reason to fall back to a PAT or to silently skip the deploy.

## Enforcement

- **CI gate:** `pat-ban.yml` in `projectbluefin/actions` blocks any PR that introduces a `secrets.XXX` reference not in the approved list above.
- **Human gate:** Any new secret addition is a Design gate — stop and request maintainer approval.
- **Not automated in this repo:** there is no pre-commit hook that scans for new
  secret names. The approved-list check is enforced only by the `pat-ban.yml` CI
  gate, and the "in use, not yet listed" rows above are the current evidence that
  the inventory can drift from reality between reviews.

## What to do instead of a PAT

| You want to... | Use instead |
|---|---|
| Push to GHCR | `github.token` with `packages: write` |
| Open/update PRs | `github.token` with `pull-requests: write` |
| Create issues | `github.token` with `issues: write` |
| Cross-repo dispatch | MERGERAPTOR App token (already provisioned) |
| Force-push to protected branch | Admin bypass via org ruleset |
| Read private packages | `github.token` (org members get automatic read) |
