---
name: release-promotion
description: "Promotion criteria, monthly release cadence, hotfix procedure, and artifact verification for projectbluefin/common. Use when cutting a release, understanding the promotion pipeline, or verifying release artifacts."
metadata:
  type: runbook
---

# Release and promotion — common

Load this when cutting a release, evaluating whether a monthly tag is safe to create, doing a hotfix, or verifying signed artifacts.

## Contents
- [Promotion criteria](#promotion-criteria)
- [Monthly release cadence](#monthly-release-cadence)
- [Emergency hotfix release](#emergency-hotfix-release)
- [Supply chain — current state and planned improvements](#supply-chain--current-state-and-planned-improvements)
- [Verifying a published artifact](#verifying-a-published-artifact)
- [How common updates reach downstream :testing builds](#how-common-updates-reach-downstream-testing-builds)
- [PR-based release model (current)](#pr-based-release-model-current)
- [Troubleshooting the testing→main squash promotion](#troubleshooting-the-testingmain-squash-promotion)

---

## Promotion criteria

A `common` release is safe when **all** of the following are true:

| Criterion | How to verify |
|---|---|
| Post-merge E2E is green | Check `.github/workflows/e2e.yml` run on latest `main` commit |
| No open `do-not-merge` PRs targeting `main` | `gh pr list --repo projectbluefin/common --label do-not-merge` |
| No open P0 issues | `~/src/hive-status` — zero 🔴 blockers |
| Promotion-candidate E2E passed this week | Check `.github/workflows/promotion-candidate-e2e.yml` (runs Tuesdays) — no open blocker issue from it |

If any criterion fails, **do not tag a release**. File or escalate the blocker issue and wait.

> **Planned gate (common#513):** The monthly `release.yml` will be updated to run the promotion-candidate E2E as a required prerequisite job before creating the GitHub Release. Until that ships, the check above is manual.

## Monthly release cadence

- **Schedule:** 1st of every month at 00:00 UTC (`release.yml` cron)
- **Tag format:** `v<YEAR>.<MONTH>` — e.g., `v2026.06`
- **What it creates:** A GitHub Release with a changelog since the previous tag, pointing at the current `main` HEAD
- **What it does NOT do:** Promote or retag the OCI image — `:latest` is always the most recent merge to `main`

## Emergency hotfix release

When a critical fix needs a versioned tag outside the monthly window:

1. Merge the fix to `main` via normal PR process
2. Verify all promotion criteria above are met
3. Run `release.yml` manually via `workflow_dispatch` — it will tag the current `main` with the current month's tag (or create a patch tag manually with `gh release create`)
4. Notify downstream image repos if the fix affects their builds

## Supply chain — current state and planned improvements

> **Note:** Supply chain tooling for this repo is being centralized. Do not add inline signing, SBOM, or scanning logic to `build.yml`. All of that belongs in `projectbluefin/actions`.

| Practice | Current state | Tracking |
|---|---|---|
| OCI image signing | ✅ Keyless OIDC — live as of 2026-06-11 ([common#595](https://github.com/projectbluefin/common/issues/595)) | `SIGNING_SECRET` removed — do not reference in new workflows |
| SBOM | ✅ syft — bundled in `sign-and-publish` composite action | — |
| SLSA L2 provenance | ✅ GitHub Actions attestation — bundled in `sign-and-publish` | — |
| CVE scanning | ✅ Trivy gate — bundled in `sign-and-publish` | — |
| Changelog quality | ✅ `git-cliff` — live as of [common#592](https://github.com/projectbluefin/common/pull/592) | — |

### Keyless signing — required permissions

`sign-and-publish` composite action requires these permissions on the calling job:

```yaml
permissions:
  id-token: write        # OIDC token for keyless signing
  attestations: write    # GitHub SLSA L2 attestation
  packages: write        # push to GHCR
  security-events: write # Trivy CVE gate upload
```

Do **not** add `SIGNING_SECRET` to new workflows — keyless OIDC has replaced it.

## Verifying a published artifact

### Verify cosign signature (legacy — key-based, pre-2026-06-11)

```bash
cosign verify \
  --key https://raw.githubusercontent.com/projectbluefin/common/main/cosign.pub \
  ghcr.io/projectbluefin/common:latest
```

### Verify GitHub attestation (live — keyless, as of common#595)

```bash
gh attestation verify \
  oci://ghcr.io/projectbluefin/common:latest \
  --repo projectbluefin/common
```

### Verify SBOM attachment

```bash
# List attached referrers (SBOM, signatures, attestations)
oras discover ghcr.io/projectbluefin/common:latest

# Pull the SBOM
cosign verify-attestation \
  --type cyclonedx \
  ghcr.io/projectbluefin/common:latest | jq .payload | base64 -d | jq .
```

## How common updates reach downstream :testing builds

When `common/build.yml` publishes a new `common:latest`, downstream `:testing` builds are triggered by two canonical paths. There is **no** direct dispatch from `build.yml` — the `notify-downstream` job was removed (it used fragile cross-repo token dispatch that silently failed across 9+ commits of churn).

### bluefin and bluefin-lts (Renovate digest bump — canonical)

`projectbluefin/renovate-config` runs a self-hosted Renovate runner every 3 hours. When it detects a new `ghcr.io/projectbluefin/common:latest` digest it opens `chore(deps): update common digest` PRs against the `testing` branch in bluefin and bluefin-lts. These PRs automerge immediately (`automerge: true, schedule: ["at any time"]`), which triggers `build-image-testing.yml` → downstream build fires.

Max propagation delay: ~3 hours after `common:latest` publishes.

**To poke Renovate manually:**
```bash
gh workflow run renovate.yml --repo projectbluefin/renovate-config
```

### dakota (BST daily cron — canonical)

Dakota does **not** consume `common` as an OCI digest. It tracks common via a `git_repo` BST source in `elements/bluefin/common.bst` pinned to a git ref on `common/main`. `track-bst-sources.yml` in dakota runs daily at 06:00 UTC and accepts `workflow_dispatch`.

Max propagation delay: ~24 hours.

**To poke manually:**
```bash
gh workflow run track-bst-sources.yml --repo projectbluefin/dakota -f group=auto-merge
```

---

## PR-based release model (current)

As of 2026-06-09, all three image repos (bluefin, bluefin-lts, dakota) use a **PR-based squash promotion** model. There are no more scheduled release workflows.

### How it works

```
testing branch builds (Renovate, feature PRs)
       │
       ▼ push to testing
promote-testing-to-main.yml (daily + on push)
       │
       ├── creates/updates auto/promote-testing-to-main branch (squash of testing)
       ├── opens or updates the promotion PR (testing → main)
       ├── runs release gate checks (cosign verify, E2E)
       └── attempts to enqueue PR in merge queue
                │
                ▼ maintainer approves → PR merges
       execute-release.yml (on PR close)
               │
               ├── re-verifies cosign signatures
               ├── promotes :testing digest to :stable (via skopeo copy)
               └── calls reusable-release.yml for release notes + GitHub Release
```

### Schedule

`promote-testing-to-main.yml` runs on three triggers:
- Push to `testing` branch
- Daily `cron: '0 23 * * *'` (refreshes promotion PR even with no testing activity)
- `workflow_dispatch` (manual override)

The daily heartbeat ensures the promotion PR stays fresh and gate checks are re-run.

### Commit title surfaces — PR title vs merged release trigger

`reusable-promote-squash.yml` emits **two different titles** during promotion:

- Promotion branch commit: `chore: promote <source_branch> to <target_branch>`
- Promotion PR title: `ci(promote): <primary_image> <source_branch> → <target_branch> <date>`

This distinction matters for `execute-release.yml`.

All three image repos currently use GitHub squash settings:

- `squash_merge_commit_title: COMMIT_OR_PR_TITLE`
- `use_squash_pr_title_as_default: false`

Because the auto-promotion branch contains a **single commit**, the squash merge on the target branch keeps the commit subject (`chore: promote ...`) rather than the PR title (`ci(promote): ...`).

**Canonical rule:** `execute-release.yml` must match the commit message that lands on the target branch, not just the PR title.

Current correct trigger subjects:

| Repo / branch | Target-branch commit subject to match |
|---|---|
| bluefin `main` | `^chore: promote testing to main` |
| bluefin-lts `main` | `^chore: promote testing to main` |
| dakota `main` | `^chore: promote testing to main` |

`ci(promote): ...` is still the correct PR title format for the open promotion PR, but **`ci(promote)` alone is not a reliable `execute-release` trigger** under the current squash-merge settings.

### Repo variants

| Repo | source | target tag |
|---|---|---|
| bluefin | `testing` branch | `stable` |
| bluefin-lts | `testing` branch | `stable` |
| dakota | `testing` OCI tag | `stable` |

### E2E gate model

All three repos run with `run_e2e: false` in `promote-testing-to-main.yml`. The e2e quality gate runs separately via `post-testing-e2e.yml` (bluefin) rather than at the PR gate level.

**Why `run_e2e: false`:** The gate queries GitHub's runs API by `head_sha = <testing-branch-SHA>`. Workflows triggered via `workflow_run` are stored in the API under the **default branch (main) SHA**, so the gate never finds a match regardless of whether E2E passed. This is the structural mismatch documented in [e2e-ci.md — Promotion gate never-stall design](e2e-ci.md#promotion-gate--never-stall-design).

### Merge model

Promotion PRs auto-merge via the merge queue with **0 approvals required**. `Lint & syntax` is the only required check. `workflow_dispatch` is available on all three `promote-testing-to-main.yml` workflows for out-of-band promotion.

## Related docs

| Topic | Doc |
|---|---|
| CI workflow purposes | [workflow-map.md](workflow-map.md) |
| E2E gates | [e2e-ci.md](e2e-ci.md) |
| Supply chain tooling (shared) | Keyless cosign, SBOM, SLSA L2, Trivy via `projectbluefin/actions` composites |

---

## Troubleshooting the testing→main squash promotion

`promote-testing-to-main.yml` squash-merges `testing` onto `main` by doing:

```bash
git checkout -B auto/promote-testing-to-main origin/main
git merge --squash origin/testing
git commit -m "chore: promote testing to main"
git push --force origin auto/promote-testing-to-main
```

### Gate stuck — release/blocked with no E2E evidence

**Symptom:** The promotion PR has `release/blocked` and the sticky gate comment reads:
> No completed post-testing-e2e run found for suites smoke,common on this PR head SHA.

The gate queries `GET /repos/{repo}/actions/runs?head_sha={TESTING_SHA}`. It looks for a completed run matching `post-testing-e2e.yml` (bluefin) or `Post-Merge E2E — Testing Parity` (bluefin-lts) associated with that exact SHA.

**Root causes in priority order:**

1. **E2E workflow only fires on main branch builds, not testing** — check `branches:` filter on the `workflow_run` trigger in `post-testing-e2e.yml` / `post-merge-e2e.yml`. Must be `[main, testing]`.
2. **The fix is on `testing` but not yet on `main`** — `workflow_run` triggers use the default branch (main) workflow file. A fix to the branches filter only takes effect once it reaches main.
3. **Gate jq selector mismatch** — the `reusable-release-gate.yml` selector uses `contains("post-merge e2e")` (hyphenated). Any variation (space instead of hyphen) silently fails to match.

> **Previously documented root cause — now fixed:** `reusable-promote-squash.yml` used to hardcode `E2E_HEAD_BRANCH: main` instead of resolving from `inputs.source_branch`. This caused the gate to query post-testing-e2e runs with the wrong SHA. Fixed in June 2026 — the reusable now uses `E2E_HEAD_BRANCH: ${{ inputs.source_branch }}`.

**Manual escape for the current cycle (bluefin only):**

```bash
# Comment /e2e on the open promotion PR to manually trigger E2E evidence
# Must be done by a maintainer with write access
gh pr comment <N> --repo projectbluefin/bluefin --body "/e2e"
```

Once the E2E passes for the testing SHA and the gate clears, the promotion PR auto-enqueues. After that first promotion, the fix lands on main and the system is self-sustaining.

**LTS and dakota** have no circular dependency — their PRs target main directly. Merging the fix PR is sufficient.

### UD (Updated/Deleted) conflict

**Symptom:** `promote-testing-to-main.yml` fails with `Automatic merge failed` and `git status` shows lines like:

```
UD .github/workflows/scheduled-stable-release.yml
UD .github/workflows/weekly-testing-promotion.yml
```

`UD` means: **testing deleted** the file, but **main still has it** (or vice versa). This happens when a PR removes a workflow from `testing` (e.g., consolidating to a reusable in `projectbluefin/actions`) but the deletion hasn't reached `main` yet.

**Resolution:** Accept the deletions from `testing` — they represent the intended state:

```bash
cd ~/src/bluefin
git fetch projectbluefin main testing
git checkout -B fix/rebuild-squash-promo projectbluefin/main
git merge --squash projectbluefin/testing  # will fail with UD conflict

# For each UD file, accept the deletion from testing:
git rm .github/workflows/scheduled-stable-release.yml

git commit -m "chore: promote testing to main"
git push projectbluefin fix/rebuild-squash-promo:auto/promote-testing-to-main --force
```

Then re-run `promote-testing-to-main.yml` via `workflow_dispatch` — it will detect the squash branch already matches testing and proceed to the enqueue step.

**Verify it's pre-existing** before touching anything: check if the `promote-testing-to-main.yml` run that failed predates your own merged PR. If it does, the conflict is not yours to own — but you can still fix the squash branch.

### Merge queue enqueue blocked

After rebuilding the squash branch, if `enqueuePullRequest` fails with:

```
Required status check "PR Validation — testsuite/validate (pull_request)" is expected.
```

The PR's CI checks have not yet completed against the new squash-branch HEAD. Wait for the `PR Validation — testsuite` workflow run to finish, then retry the enqueue.

If the error is `At least 1 approving review is required`:

- The `github-actions[bot]` (app ID 15368) is **not** in the bypass actors for `main-review-required-with-renovate-bypass`. It cannot self-approve.
- An OrganizationAdmin must approve the PR. The workflow's enqueue step will retry after approval.
- As a last resort, use `gh pr merge <N> --squash --admin` to bypass (only valid for org admins).

### Source/target branch divergence on a shared file

**Symptom:** `Promote main to lts` (or any squash promote run) fails with:

```
Auto-merging build_scripts/scripts/kernel-swap.sh
Process completed with exit code 1
```

`reusable-promote-squash` builds a squash of the source branch onto the target. If both branches independently modified the same file relative to their common ancestor, git hits a true merge conflict and exits 1. This repeats on **every** promote run until the divergence is resolved.

**Resolution:** Align the target branch (e.g. `lts`) to use the same content as the source branch (`main`) for the conflicting file. Since `lts` is a promotion snapshot of `main` — not an independent development branch — it must never diverge on shared build scripts.

```bash
# Find the exact diff:
gh api repos/<org>/<repo>/compare/lts...main --jq '.files[] | select(.filename == "<file>") | .patch'

# Fix: open a PR to lts syncing the diverged lines to match main
# Then the next squash promotion will apply cleanly
```

**Prevention:** After any rename of a build flag or variable (e.g. `ENABLE_GDX` → `ENABLE_NVIDIA`), search ALL branches and ALL scripts that consume it before merging. See bluefin-lts PRs #245, #249.

### Zombie publish runs blocking the concurrency queue

**Symptom:** `Publish` workflow runs stuck `in_progress` for > 30 min; new publish runs sit in `pending` indefinitely. The factory status script shows `Publish [main]: never` despite successful builds.

**Root cause:** `cancel-in-progress: false` on the publish concurrency group means stuck runner jobs hold the group indefinitely.

**Resolution:**

```bash
# Find the zombie runs
gh run list --repo projectbluefin/dakota --status in_progress \
  --json databaseId,name,headBranch,createdAt | jq '.[]'

# Cancel each one
gh run cancel <databaseId> --repo projectbluefin/dakota

# Re-trigger the promote workflow to rebuild the stale squash if PR is CONFLICTING
gh workflow run <promote-workflow-id> --repo projectbluefin/dakota --ref testing
```

### Branch policy on `projectbluefin/actions`

`projectbluefin/actions` has a branch policy that blocks non-admin merges (including the agent token). PRs to `actions` always require a human to merge. After merge, the `@v1` tag must be force-pushed:

```bash
cd ~/src/actions
git tag -f v1 HEAD
git push --force origin v1
```

---

## Reusable workflow patterns (actions v1)

All image repos now delegate to shared reusables in `projectbluefin/actions`. Pin to the v1 SHA.

### Release generation — `reusable-release.yml`

Supports two SBOM modes:

| Mode | When to use | Key inputs |
|---|---|---|
| **Artifact mode** (default) | Build pipeline uploads a SBOM artifact (e.g. `reusable-build.yml` runs with `stream_name: stable`) | `build_workflow`, `build_branch`, `sbom_artifact` |
| **Inline mode** | No SBOM artifact (promote-from-testing weekly path, LTS weekly path) | `generate_sbom_inline: true`, `syft_version` (default v1.44.0) |

Use `checkout_ref` when the caller runs on `main` but the release should reflect a different branch (e.g. `checkout_ref: lts` for bluefin-lts).

**Critical**: `reusable-release.yml` always has `environment: production` on the `image-release` job — this is the R3 human gate. Do NOT remove it.

### Renovate runner — `reusable-renovate.yml`

Image repos keep their own `schedule`/`workflow_dispatch` wrapper and delegate the job:

```yaml
jobs:
  renovate:
    uses: projectbluefin/actions/.github/workflows/reusable-renovate.yml@<sha> # v1
    with:
      dry_run: ${{ inputs.dry_run == true }}
    secrets:
      renovate_token: ${{ secrets.RENOVATE_TOKEN }}
```

`persist-credentials: false` is enforced in the reusable — callers do not need to set it.

### Renovate auto-merge — `reusable-renovate-automerge.yml`

Image repos keep their `workflow_run` trigger (must reference the repo-specific CI workflow name) and delegate the PR lookup + squash-merge:

```yaml
on:
  workflow_run:
    workflows: ["<repo-specific CI workflow name>"]
    types: [completed]
permissions:
  contents: write
  pull-requests: write
jobs:
  automerge:
    if: github.event.workflow_run.conclusion == 'success'
    uses: projectbluefin/actions/.github/workflows/reusable-renovate-automerge.yml@<sha> # v1
    with:
      head_sha: ${{ github.event.workflow_run.head_sha }}
      # base_branch defaults to 'testing' — override only if needed
```

The `workflow_run` trigger CANNOT be in a reusable workflow — it must stay in the caller. Only the job logic is centralised.
