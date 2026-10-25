---
name: workflow-map
version: "3.0"
last_updated: "2026-09-13"
id: workflow-map
one_line_purpose: Understand what each GitHub workflow in common does.
entry_point: docs/skills/workflow-map.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [workflows, ci, reference]
description: >-
  What each GitHub workflow in common is for. Use when editing workflows,
  debugging CI, or understanding pipeline stages.
metadata:
  type: reference
---

# Common workflow map

Load this when you need to understand **what each GitHub workflow in `projectbluefin/common` is for** and which one to edit.

`common` is a **shared OCI layer repo**, not a standalone product image repo. Its workflows exist to protect the layer that flows into `bluefin`, `bluefin-lts`, and `dakota`.

## The twelve workflows

Every file in `.github/workflows/`, with its `name:` and triggers as written in the file.

| File | `name:` | Triggers | What it does |
|---|---|---|---|
| `validate.yml` | Validate PR | `pull_request` (main), `merge_group` | The policy gate: PR-title conventional-commit check, submodule drift, `just check`, shellcheck over `system_files/**/*.sh`, `scripts/check-oci-refs.py`, dconf lock/override parity, then `pre-commit run --all-files` |
| `build.yml` | Build | `pull_request` (main), `push` (main), `merge_group`, `workflow_dispatch` | Builds and publishes the `common` OCI layer. Two-arch matrix `build_push` (x86_64 on `ubuntu-24.04`, aarch64 on `ubuntu-24.04-arm`) via rootless `buildah-build`, then `sudo skopeo copy` into root storage so `push-image` (root `podman push`) finds it. A `manifest` job assembles the multi-arch manifest, tags it, signs keyless, and attests SLSA L2 |
| `unit-tests.yml` | Unit Tests | `pull_request`/`push` on main (path-filtered to `system_files/**`, `tests/**`, `scripts/validate-brewfiles.sh`, `Justfile`), `merge_group`, `workflow_dispatch` | `pytest --cov-fail-under=80` plus the `bats` suites, and shellcheck for the extensionless `system_files` scripts |
| `validate-brewfiles.yaml` | Validate Brewfiles | `pull_request` only, path-filtered to the Brewfile tree, `scripts/validate-brewfiles.sh`, its bats file, and the `Justfile` | Real Homebrew: `bash scripts/validate-brewfiles.sh`. Networked, so it stays out of `just check` |
| `validate-chairlift-config.yaml` | Validate ChairLift Config | `pull_request` (path-filtered), `schedule: 17 7 * * 1`, `workflow_dispatch` | `python3 tests/check-chairlift-config` against the schema of the ChairLift release the `frostyard/tap` cask pins — `CHAIRLIFT_SCHEMA_REF = "v0.10.1"`, a single constant in `tests/check-chairlift-config` |
| `run-testsuite.yml` | Run Testsuite | `workflow_call` only | The **single owner of the testsuite SHA pin**: `projectbluefin/testsuite/.github/workflows/e2e.yml@8d9ca0b3…`. Takes `image` and `suites` |
| `pr-e2e.yml` | PR E2E | `pull_request` (main), `merge_group` | Composes the PR's common layer onto `BASE_IMAGE: ghcr.io/projectbluefin/bluefin:testing`, pushes it, and calls `run-testsuite.yml` with `suites: common` |
| `e2e.yml` | E2E | `push` (main, paths-ignore docs/markdown/workflows), `workflow_dispatch` | Post-merge, **advisory**. Matrix of `bluefin:testing` + `dakota:testing`, `suites: common`, via `run-testsuite.yml`. Opens or updates one tracking issue on failure |
| `promotion-candidate-e2e.yml` | Promotion Candidate E2E | `schedule: 0 3 * * 2`, `workflow_dispatch` | Tuesday run of `smoke,common` against `bluefin:testing` + `bluefin:lts-testing`. Files a blocker issue on failure |
| `release.yml` | Monthly Release | `schedule: 0 0 1 * *`, `workflow_dispatch` | Cadence-guarded GitHub Release. See [release-promotion](release-promotion/SKILL.md) — it publishes **no** image |
| `scorecard.yml` | Scorecard supply-chain security | `branch_protection_rule`, `schedule: 17 8 * * 3`, `push` (main) | OpenSSF Scorecard; uploads SARIF to the Security tab |
| `copilot-setup-steps.yml` | Copilot Setup Steps | `workflow_dispatch`, `push`/`pull_request` filtered to **itself** | Installs `just` + `pre-commit` and prints their versions. A tooling smoke test for the Copilot agent environment; it gates nothing |

Three workflows call `./.github/workflows/run-testsuite.yml`: `pr-e2e.yml`, `e2e.yml`, `promotion-candidate-e2e.yml`. That is the only local reusable edge.

> **Workflows that do not exist in `common` and must not be re-added:**
> - `backfill-pipeline.yml` — issue widget backfill. If needed, run as a local script; do not add CI plumbing for a one-shot task.
> - `skill-drift.yml` — retired across the factory; the shared reusable it called was deleted. Process conventions are not CI gates. See [`ci-tooling/references/pre-commit-conventions.md`](ci-tooling/references/pre-commit-conventions.md).
> - `docs-quality.yml` — skill frontmatter enforcement belongs in agent review, not CI.
> - `renovate-automerge.yml` — deleted in [#783](https://github.com/projectbluefin/common/pull/783). Renovate uses `platformAutomerge: true` in root `renovate.json`; GitHub's native auto-merge + merge queue replaces it. Do not re-add a workflow-based automerge mechanism.
> - `lifecycle-caller.yml` — `common` has no lifecycle caller. Lifecycle automation lives in `projectbluefin/bonedigger` and is consumed by the image repos via `bonedigger.yml`. Do not add a common-owned caller.
> - `sync-codeowners.yml` — does not exist in any factory repo. Do not document or re-add it.
> - `notify-downstream` as a job in `build.yml` — removed. Propagation is pull-based; see [release-promotion/references/downstream-propagation.md](release-promotion/references/downstream-propagation.md).

## What gates publication, and what does not

The `main` ruleset (`main — merge queue`, id 17513003) requires exactly three status checks. Their names are the job `name:` values in `validate.yml` and `build.yml`; if you rename a job, the queue waits forever for a check that will never arrive.

| Check | Source | Required by the ruleset? |
|---|---|---|
| `validate` | `validate.yml` job `validate` | yes |
| `Build and push image (x86_64)` | `build.yml` `build_push` matrix | yes |
| `Build and push image (aarch64)` | `build.yml` `build_push` matrix | yes |
| PR E2E | `pr-e2e.yml` | **no** — pre-merge signal, not a required check |
| E2E | `e2e.yml` | **no** — runs after the layer is already pushed |

Approval and merge-queue rules for that ruleset live in [governance.md](governance.md); do not restate them here.

Verify the check list with:

```bash
gh api repos/projectbluefin/common/rulesets --jq '.[].id' \
  | xargs -I{} gh api repos/projectbluefin/common/rulesets/{} \
      --jq '[.rules[]|select(.type=="required_status_checks")
             |.parameters.required_status_checks[]?.context]'
```

When `e2e.yml` is red, read the failing matrix entry before assuming the defect is in `system_files/`. It exercises downstream `*-testing` images, so a bootc, bootupd, or kernel regression in an image `common` does not own surfaces here as a red `common` run.

`validate-chairlift-config.yaml` is a separate workflow on purpose: `just check` must stay hermetic, so no networked gate belongs in the repo-wide PR check. Its weekly cron is what catches upstream schema drift between commits.

## Which skill to load next

| If the work is about... | Load |
|---|---|
| Workflow pins, Renovate, pre-commit | [`ci-tooling/SKILL.md`](ci-tooling/SKILL.md) |
| Pre/post-merge or promotion-candidate tests | [`e2e-ci/SKILL.md`](e2e-ci/SKILL.md) |
| Release cadence, artifact signing, downstream propagation | [`release-promotion/SKILL.md`](release-promotion/SKILL.md) |
| Image names and published tags | [`image-registry.md`](image-registry.md) |
| CODEOWNERS, ruleset, approvals | [`governance.md`](governance.md) |

## Hard rule

When editing workflows here, preserve the repo boundary:

- `common` validates the **shared layer**
- downstream image repos validate their **image-specific** behavior
- reusable CI logic should live in `projectbluefin/actions`, not be duplicated inline unless the logic is truly `common`-specific
