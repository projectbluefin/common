---
name: workflow-map
version: "2.2"
last_updated: "2026-08-02"
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

## Workflow groups

| Workflow | Purpose | When to touch it |
|---|---|---|
| `validate.yml` | Main PR gate: submodule drift, `just check`, shellcheck, image-registry guard, dconf parity, pre-commit | Tightening repo-local validation or policy guards |
| `validate-brewfiles.yaml` | Validates Brewfile correctness | Changing Brewfile structure or Brewfile validation rules |
| `validate-chairlift-config.yaml` | Checks `/usr/share/chairlift/config.yml` against the schema of the pinned ChairLift release (`CHAIRLIFT_SCHEMA_REF`, currently `v0.10.1`); path-filtered plus a weekly cron | Changing the ChairLift maintainer config, cask pin, or upstream schema assumptions |
| `unit-tests.yml` | Runs `pytest` + `bats` on `system_files/**`, `tests/**`, and the `Justfile`. Triggers on PR, push to `main`, and `merge_group`. | Adding or changing unit tests, or changing the paths they cover |
| `build.yml` | Builds and publishes the `common` OCI layer on merge. Runs parallel per-arch jobs (x86_64 on `ubuntu-24.04`, aarch64 on `ubuntu-24.04-arm`). Build uses rootless `buildah-build`; after build, `sudo skopeo copy` promotes the image into root storage so `push-image` (which uses `sudo podman push`) can find it. Then a `manifest` job assembles the multi-arch manifest, logs into GHCR, signs with keyless OIDC, generates SBOM, and attests SLSA L2. Downstream propagation is handled by Renovate (bluefin/bluefin-lts, ~3h) and dakota's daily cron — there is no direct dispatch from this workflow. | Changing how the shared layer is built or pushed |
| `pr-e2e.yml` | Pre-merge composed-image gate for the PR's common layer (composes + runs common suite via `run-testsuite.yml`) | Changing how PR-time downstream composition is tested |
| `e2e.yml` | Post-merge, **advisory** common-suite validation. Tests the downstream `*-testing` images (`bluefin:testing`, `dakota:testing`) — not the layer just built. Triggers on `push: main` in parallel with `build.yml`, is **not** a required check, and does **not** gate publication: `common:latest` is pushed regardless of the result. On failure it opens or updates a single tracking issue. **Bluefin LTS is deliberately excluded** while [bluefin-lts#492](https://github.com/projectbluefin/bluefin-lts/issues/492) is open — it failed every run, and GitHub does not allow `continue-on-error` on a reusable-workflow call, so it could not be soft-failed in place. LTS is still covered weekly by `promotion-candidate-e2e.yml`. | Changing shipped-layer validation after merge |
| `run-testsuite.yml` | Local wrapper that centralizes the pinned `projectbluefin/testsuite` SHA | Updating the shared testsuite pin or common-side testsuite wiring |
| `promotion-candidate-e2e.yml` | Weekly smoke/common check against `bluefin:testing` and `bluefin:lts-testing` | Adjusting common-side signal before downstream Tuesday promotions |
| `scorecard.yml` | Weekly OpenSSF Scorecard analysis. Runs on schedule and on push to main. Uploads SARIF to the GitHub Security tab. | Adjusting security posture reporting |
| `release.yml` | Monthly/versioned OCI release flow. Triggered **only** by the monthly cron (`0 0 1 * *`) and `workflow_dispatch` — there is no `workflow_run` trigger on `E2E`. A cadence guard skips the run when the last release is under 20 days old or a `do-not-merge` PR is open against `main`. Uses git-cliff for changelog generation ([common#592](https://github.com/projectbluefin/common/pull/592)). | Changing versioned layer release behavior |

> **Workflows that do not exist in `common` and must not be re-added:**
> - `backfill-pipeline.yml` — issue widget backfill. If needed, run as a local script; do not add CI plumbing for a one-shot task.
> - `skill-drift.yml` — retired across the factory; the shared reusable it called was deleted. Process conventions are not CI gates. See `ci-tooling.md` § Skill drift detection.
> - `docs-quality.yml` — skill frontmatter enforcement belongs in agent review, not CI.
> - `renovate-automerge.yml` — deleted in [#783](https://github.com/projectbluefin/common/pull/783). Renovate uses `platformAutomerge: true` in `renovate.json`; GitHub's native auto-merge + merge queue replaces it. Do not re-add a workflow-based automerge mechanism.
> - `lifecycle-caller.yml` — `common` has no lifecycle caller. Lifecycle automation lives in `projectbluefin/bonedigger` and is consumed by the image repos via `bonedigger.yml`. Do not add a common-owned caller.
> - `sync-codeowners.yml` — does not exist in any factory repo. Do not document or re-add it.

## Mental model

### Validation and policy

`validate.yml` and `validate-brewfiles.yaml` are about catching repo-local mistakes **before merge**.

`validate-chairlift-config.yaml` validates against an external upstream schema
that can drift without a common commit. It fetches ChairLift's page, group, and
field names and fails closed because unknown keys disable the whole
application. It reads the tag the `frostyard/tap` cask pins rather than
upstream `main`, so it cannot green-light a key the shipped binary rejects.
It is a separate workflow on purpose: `just check` must stay hermetic, so no
networked gate belongs in the repo-wide PR check.

### Shared-layer build and release

`build.yml` and `release.yml` are about shipping the `common` layer itself.

### Downstream behavior checks

`pr-e2e.yml`, `e2e.yml`, `run-testsuite.yml`, and `promotion-candidate-e2e.yml` exist because `common` only proves itself when composed into downstream images.

Only **`pr-e2e.yml` gates publication**: it composes the PR's own layer and runs the common suite before merge. `e2e.yml` runs *after* the layer is already pushed and is advisory.

That distinction matters when `e2e.yml` is red. It exercises downstream `*-testing` images, so a failure can originate in a downstream base image that `common` does not own and cannot fix — a bootc, bootupd, or kernel regression in `bluefin-lts` surfaces here as a red `common` run. Read the failing matrix entry before assuming the defect is in `system_files/`.

### What gates publication, and what does not

| Check | Required? | Effect on `common:latest` |
|---|---|---|
| `validate` | yes (ruleset) | blocks merge |
| `Build and push image (x86_64 / aarch64)` | yes (ruleset) | blocks merge |
| `pr-e2e.yml` | pre-merge | blocks merge |
| `e2e.yml` | **no** | none — the layer is already published |

Verify with:

```bash
gh api repos/projectbluefin/common/rulesets --jq '.[].id' \
  | xargs -I{} gh api repos/projectbluefin/common/rulesets/{} \
      --jq '[.rules[]|select(.type=="required_status_checks")
             |.parameters.required_status_checks[]?.context]'
```

### Factory operations

`common` runs no factory-policy workflows. Lifecycle automation (issue intake,
labels, report handling) lives in `projectbluefin/bonedigger` and is consumed
by `bluefin`, `bluefin-lts`, and `dakota` through their own `bonedigger.yml`
callers. Do not add a common-owned lifecycle caller or duplicate lifecycle
logic here.

Verify this list against the checkout before trusting it:

```bash
ls .github/workflows/
```

## Which skill to load next

| If the work is about... | Load |
|---|---|
| Workflow pins, floating-tag guard | `ci-tooling/SKILL.md` |
| Pre/post-merge or promotion-candidate tests | `e2e-ci/SKILL.md` |
| Release cadence, promotion criteria, artifact signing | `release-promotion/SKILL.md` |
| CODEOWNERS or governance policy | `governance.md` |
| Queue state / lifecycle | `pr-review/SKILL.md` (merge queue section) and Hive context if needed |

## Hard rule

When editing workflows here, preserve the repo boundary:

- `common` validates the **shared layer**
- downstream image repos validate their **image-specific** behavior
- reusable CI logic should live in `projectbluefin/actions`, not be duplicated inline unless the logic is truly `common`-specific
