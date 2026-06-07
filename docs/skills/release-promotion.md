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
- [Weekly gated release model](#weekly-gated-release-model)
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
| OCI image signing | Key-based (`SIGNING_SECRET`) | Migrate to keyless via `sign-and-publish` — [common#513](https://github.com/projectbluefin/common/issues/513) |
| SBOM | None | Adopt `sign-and-publish` (includes syft) — [actions#86](https://github.com/projectbluefin/actions/issues/86) |
| SLSA L2 provenance | None | Adopt upgraded `sign-and-publish` — [actions#86](https://github.com/projectbluefin/actions/issues/86) |
| CVE scanning | None | Adopt `scan-image` composite action — [actions#86](https://github.com/projectbluefin/actions/issues/86) |
| Changelog quality | `git log` heredoc | Migrate to `git-cliff` — [common#513](https://github.com/projectbluefin/common/issues/513) |

## Verifying a published artifact

### Verify cosign signature (current — key-based)

```bash
cosign verify \
  --key https://raw.githubusercontent.com/projectbluefin/common/main/cosign.pub \
  ghcr.io/projectbluefin/common:latest
```

### Verify GitHub attestation (after common#513 ships)

```bash
gh attestation verify \
  oci://ghcr.io/projectbluefin/common:latest \
  --repo projectbluefin/common
```

### Verify SBOM attachment (after actions#86 ships)

```bash
# List attached referrers (SBOM, signatures, attestations)
oras discover ghcr.io/projectbluefin/common:latest

# Pull the SBOM
cosign verify-attestation \
  --type cyclonedx \
  ghcr.io/projectbluefin/common:latest | jq .payload | base64 -d | jq .
```

## Weekly gated release model

As of 2026-06-06, all three image repos fire releases on **Tuesday at 06:00 UTC** and require maintainer approval before the release is created.

| Repo | Workflow | Gate |
|---|---|---|
| **bluefin** | `scheduled-stable-release.yml` | `production` environment — `@projectbluefin/maintainers` |
| **bluefin-lts** | `scheduled-lts-release.yml` | `production` environment — `@projectbluefin/maintainers` |
| **dakota** | `weekly-testing-promotion.yml` (calls `release.yml` as sub-workflow) | `production` environment — `@projectbluefin/maintainers` |

### Verifying the environment gate is real

`environment: production` in a workflow YAML is only effective if the GitHub environment has `required_reviewers` configured. To verify:

```bash
gh api repos/projectbluefin/{repo}/environments/production \
  --jq '.protection_rules[] | select(.type=="required_reviewers") | .reviewers[].reviewer.slug'
```

Expected output: `maintainers`. All three repos confirmed: `required_reviewers: maintainers` + `prevent_self_review: true` (verified 2026-06-07).

### Repo architecture differences (intentional)

The three image repos use different promotion models by design — these are NOT inconsistencies:

| Repo | Testing buffer | Renovate target | Branch model |
|---|---|---|---|
| bluefin | `testing` git branch (PRs must target it) | `testing` | testing → main → :stable |
| bluefin-lts | No `testing` branch — main IS the integration branch | `main` | main → lts (promotion branch) → :lts |
| dakota | No testing branch — BST tracks sources via `track-bst-sources.yml` | `main` (GHA only) | main builds → :testing tag → weekly promote to :stable |

Bluefin-lts's `lts` branch is a promotion branch (like `stable`), not an equivalent of bluefin's `testing` buffer.



1. Schedule fires Tuesday 06:00 UTC → GitHub notifies `@projectbluefin/maintainers`
2. Any maintainer clicks **Review deployments** in the Actions UI and approves
3. The release job proceeds once approved (GitHub enforces this natively — no bot logic needed)
4. `workflow_dispatch` is available on all three for out-of-band cuts

### Approval requirement

GitHub Environment protection requires **any 1** reviewer from the listed team to approve (GitHub does not support a "require N" count natively for environments). In practice, social convention is 2 acks. If a stricter gate is needed, a two-stage environment chain (`gate-1` → `gate-2`) can be added.

### Blocking an individual release

Add a `do-not-release` label convention: before the Tuesday run, a maintainer can cancel the in-progress workflow run for that repo specifically. The other two repos are not affected.

### Context sourcing (dakota and bluefin)

Unlike `bluefin-lts` which dispatches fresh builds, the bluefin and dakota scheduled release workflows find the **latest successful build/publish run** at approval time and pull its SHA, SBOM, and digest from there. This means the release tags the most recently built image, not necessarily the one built that Tuesday.

## Promotion pipeline consistency epic (#516)

The three image repos (bluefin, bluefin-lts, dakota) currently use inconsistent pipeline models. Epic [#516](https://github.com/projectbluefin/common/issues/516) tracks bringing them into alignment on a shared "build once, promote the artifact" model.

**Known gaps being tracked:**

| Issue | Repo | Gap | Status |
|---|---|---|---|
| [#517](https://github.com/projectbluefin/common/issues/517) | bluefin-lts | Rebuilds from source for production — `:lts` never tested as shipped | Open — blocked on bluefin-lts PR #73 |
| [#518](https://github.com/projectbluefin/common/issues/518) | bluefin | `:testing` tag pushed before e2e | ✅ Closed |
| [#519](https://github.com/projectbluefin/common/issues/519) | bluefin-lts | No 7-day promotion floor | ✅ Implemented (7-day floor present in `scheduled-lts-release.yml`) |
| [#520](https://github.com/projectbluefin/common/issues/520) | dakota | Weekly promotion ran Sunday, not Tuesday | ✅ Closed |
| [#521](https://github.com/projectbluefin/common/issues/521) | dakota | No cosign verify before final promotion | ✅ Closed |
| [#522](https://github.com/projectbluefin/common/issues/522) | dakota | No full e2e at weekly promotion time | ✅ Closed |
| [#523](https://github.com/projectbluefin/common/issues/523) | common | No shared release-pipeline.md spec | Open |
| [#524](https://github.com/projectbluefin/common/issues/524) | all repos | No TOCTOU SHA guard before final skopeo copy | ✅ Closed |
| — | bluefin | No `environment: production` on weekly stable promotion | ✅ Fixed 2026-06-07 (bluefin PR #432) |
| — | bluefin-lts | TODO(#94): missing `environment: production` on promote job | ✅ Fixed 2026-06-07 (bluefin-lts PR #114) |
| — | bluefin-lts | `renovate-automerge.yml` missing `--base main` filter | ✅ Fixed 2026-06-07 (bluefin-lts PR #114) |
| — | bluefin-lts | `pr-e2e-smoke.yml` ran on all PRs including CI-only changes | ✅ Fixed 2026-06-07 (bluefin-lts PR #115) |
| — | dakota | `weekly-testing-promotion.yml` used inline `curl` cosign install | ✅ Fixed 2026-06-07 (dakota PR #730) |
| — | bluefin, bluefin-lts | Duplicate `generate-release.yml` (local SBOM+release-card) vs `reusable-release.yml` in actions | ✅ Fixed 2026-06-07 (bluefin PR #438, bluefin-lts PR #118) |
| — | bluefin-lts | `scheduled-lts-release.yml` used fragile dispatch+poll (`gh workflow run` → sleep → `gh run list` poll → `gh run watch`) | ✅ Fixed 2026-06-07 (bluefin-lts PR #118 — replaced with `workflow_call` to `reusable-release.yml`) |
| — | bluefin, bluefin-lts, dakota | Local `renovate.yml` duplicated runner logic; `renovate-automerge.yml` duplicated PR-lookup+merge logic | ✅ Fixed 2026-06-07 (all three repos PR merged — call `reusable-renovate.yml` + `reusable-renovate-automerge.yml` from actions) |

**⚠️ bluefin-lts PR #73 (`feat/shared-workflow-migration`)** is pending review and rewrites the LTS build workflows + renames all LTS images. Do not implement #517 until #73 merges.

## Related docs

| Topic | Doc |
|---|---|
| CI workflow purposes | [workflow-map.md](workflow-map.md) |
| E2E gates | [e2e-ci.md](e2e-ci.md) |
| Promotion gates (QA model) | [../qa/PROMOTION_GATES.md](../qa/PROMOTION_GATES.md) |
| Supply chain tooling (shared) | [projectbluefin/actions#86](https://github.com/projectbluefin/actions/issues/86) |

---

## Troubleshooting the testing→main squash promotion

`promote-testing-to-main.yml` squash-merges `testing` onto `main` by doing:

```bash
git checkout -B auto/promote-testing-to-main origin/main
git merge --squash origin/testing
git commit -m "chore: promote testing to main"
git push --force origin auto/promote-testing-to-main
```

### UD (Updated/Deleted) conflict

**Symptom:** `promote-testing-to-main.yml` fails with `Automatic merge failed` and `git status` shows lines like:

```
UD .github/workflows/generate-release.yml
UD .github/workflows/scheduled-stable-release.yml
```

`UD` means: **testing deleted** the file, but **main still has it** (or vice versa). This happens when a PR removes a workflow from `testing` (e.g., consolidating to a reusable in `projectbluefin/actions`) but the deletion hasn't reached `main` yet.

**Resolution:** Accept the deletions from `testing` — they represent the intended state:

```bash
cd ~/src/bluefin
git fetch projectbluefin main testing
git checkout -B fix/rebuild-squash-promo projectbluefin/main
git merge --squash projectbluefin/testing  # will fail with UD conflict

# For each UD file, accept the deletion from testing:
git rm .github/workflows/generate-release.yml
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
