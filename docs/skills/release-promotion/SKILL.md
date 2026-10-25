---
name: release-promotion
version: "2.0"
last_updated: "2026-09-13"
id: release-promotion
one_line_purpose: Cut releases and verify promotion/hotfix artifacts.
entry_point: docs/skills/release-promotion/SKILL.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [release, promotion, staging]
description: >-
  Monthly release cadence, hotfix procedure, and artifact verification for
  projectbluefin/common. Use when cutting a release or verifying signed
  artifacts.
metadata:
  type: reference
---

# Release and promotion — common

Load this when cutting a release, evaluating whether a monthly tag is safe to create, doing a hotfix, or verifying signed artifacts.

## What `release.yml` actually is

**File:** `.github/workflows/release.yml`, `name: Monthly Release`. Two jobs, `check` then `release`.

**Triggers:** `schedule: '0 0 1 * *'` (the 1st of every month, 00:00 UTC) and `workflow_dispatch`. Nothing else — no `workflow_run`, no push, no PR. Cross-repo cadences live in [`agentic-model.md`](../../factory/agentic-model.md#release-cadences).

**The `check` job** sets `due=false` and stops the run when either guard trips:

| Guard | Query |
|---|---|
| A release was published in the last 20 days | `gh release list --limit 1 --json publishedAt` |
| Any open PR against `main` carries `hold` | `gh pr list --search "label:hold" --base main` |

The label is `hold`, not `do-not-merge`.

**The `release` job** (only when `due == 'true'`):

1. Checks out with `fetch-depth: 0`
2. Installs `git-cliff` — bootstraps rustup if needed, then `cargo install --locked git-cliff`. Not `taiki-e/install-action`, whatever `cliff.toml`'s header comment says
3. Computes `TAG="v$(date +'%Y.%m')"`
4. Creates the GitHub Release via `ncipollo/release-action`

### What it does NOT do

**`release.yml` never touches a registry.** It does not build, push, retag, promote, or sign any OCI image. That is the single most misleading thing an agent can assume about this repo.

The `common` image is published by `build.yml` on every merge to `main`: `latest` + `YYYYMMDD` + `<sha7>`, signed in the same run. See [image-registry.md](../image-registry.md). A monthly tag is a changelog marker over commits that were already published weeks earlier.

There is no `:testing` → `:stable` promotion for `common`, no promotion PR, and no squash-promotion branch. Those exist in `bluefin` and `bluefin-lts` and are documented in [`e2e-ci/references/never-stall-design.md`](../e2e-ci/references/never-stall-design.md).

---

## Before you tag

`release.yml`'s own guards are the 20-day window and `label:hold`. Everything below is a human judgement call the workflow does not make for you:

| Criterion | How to check |
|---|---|
| Post-merge E2E green on the latest `main` commit | `gh run list --workflow e2e.yml --branch main --limit 1` |
| No open blocker filed by the Tuesday promotion-candidate run | `gh issue list --repo projectbluefin/common --search "Promotion Candidate E2E in:title state:open"` |
| No open `blocked` issues | `gh issue list --repo projectbluefin/common --label blocked --state open` |

If a criterion fails, do not tag. File or escalate the blocker and wait.

---

## Emergency hotfix release

When a critical fix needs a versioned tag outside the monthly window:

1. Merge the fix to `main` via the normal PR process — the fix ships in `common:latest` as soon as `build.yml` completes, independently of any tag
2. Check the criteria above
3. Run `release.yml` via `workflow_dispatch`. Note the 20-day guard still applies; if the last release is newer than that, the run exits without tagging and you need `gh release create` by hand
4. The tag format is `vYYYY.MM` — a second release in the same month collides with the existing tag

---

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Cutting the release ships the fix." | The fix shipped when `build.yml` pushed `common:latest`. The tag is a changelog marker. |
| "`workflow_dispatch` forces a release." | The `check` job runs on dispatch too. Under 20 days since the last release, or one `hold` PR open, and it exits `due=false`. |
| "E2E is green, so we can tag." | `e2e.yml` is advisory and tests downstream `*-testing` images, not the layer you are tagging. |
| "The release promotes `:latest` to something stable." | `common` has no stable stream. `latest` is the most recent merge, always. |

## Red Flags

- A doc or agent describing a `common` promotion PR, squash-promotion branch, or `:testing` → `:stable` step — none of that exists here
- `release.yml` gaining registry permissions or a `skopeo`/`cosign` step — image publishing belongs in `build.yml`
- A hardcoded SHA or tag in this file that is not re-derived from `release.yml` or `build.yml`

## Verification

- [ ] The cadence guards quoted here still match `release.yml`'s `check` job
- [ ] For artifact verification: run `gh attestation verify` (keyless, post-2026-06-11), not key-based cosign verify
- [ ] After a hotfix: notify downstream repos — propagation is pull-based and can stall, see [downstream-propagation.md](references/downstream-propagation.md)

## References

| File | Description |
|---|---|
| [references/supply-chain.md](references/supply-chain.md) | Signing, SBOM, SLSA, CVE scanning; which job holds which permission; artifact verification commands. |
| [references/downstream-propagation.md](references/downstream-propagation.md) | How a merged `common` change reaches bluefin, bluefin-lts, and dakota — and why the fast path currently needs a manual trigger. |
| [references/troubleshooting.md](references/troubleshooting.md) | Troubleshooting the downstream testing→main squash promotion. Not a `common` pipeline. |
