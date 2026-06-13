---
name: workflow-map
description: "What each GitHub workflow in projectbluefin/common is for — validation, E2E, release, and factory-policy boundaries. Use when deciding which .github/workflows/ file to edit, understanding CI pipeline stages, or debugging a workflow failure."
metadata:
  type: reference
---

# Common workflow map

Load this when you need to understand **what each GitHub workflow in `projectbluefin/common` is for** and which one to edit.

`common` is a **shared OCI layer repo**, not a standalone product image repo. Its workflows exist to protect the layer that flows into `bluefin`, `bluefin-lts`, and `dakota`.

## Workflow groups

| Workflow | Purpose | When to touch it |
|---|---|---|
| `backfill-pipeline.yml` | Manual workflow — injects the pipeline widget into existing issues that are missing it. Accepts optional comma-separated issue numbers; auto-discovers all missing-widget issues if left blank. | Backfilling the widget after lifecycle automation is wired to a repo |
| `validate.yml` | Main PR gate: submodule drift, `just check`, shellcheck, image-registry guard, dconf parity, pre-commit | Tightening repo-local validation or policy guards |
| `validate-brewfiles.yaml` | Validates Brewfile correctness | Changing Brewfile structure or Brewfile validation rules |
| `build.yml` | Builds and publishes the `common` OCI layer on merge. Runs parallel per-arch jobs (x86_64 on `ubuntu-24.04`, aarch64 on `ubuntu-24.04-arm`), exports each arch to a docker-archive for Trivy scanning, then a `manifest` job assembles the multi-arch manifest, signs with keyless OIDC, generates SBOM, and attests SLSA L2. On merge also dispatches `common-updated` events to downstream repos (`bluefin`, `bluefin-lts`, `dakota`). | Changing how the shared layer is built or pushed |
| `pr-e2e.yml` | Pre-merge composed-image gate for the PR's common layer (composes + runs common suite via `run-testsuite.yml`) | Changing how PR-time downstream composition is tested |
| `e2e.yml` | Post-merge common-suite validation against Bluefin LTS, Bluefin stable, and Dakota. Dakota entry is non-blocking (`continue-on-error: true`) until infra is confirmed stable ([issue #497](https://github.com/projectbluefin/common/issues/497)). | Changing shipped-layer validation after merge |
| `run-testsuite.yml` | Local wrapper that centralizes the pinned `projectbluefin/testsuite` SHA | Updating the shared testsuite pin or common-side testsuite wiring |
| `promotion-candidate-e2e.yml` | Weekly smoke/common check against `bluefin:testing` and `bluefin:lts-testing` | Adjusting common-side signal before downstream Tuesday promotions |
| `skill-drift.yml` | Warns when implementation changes land without matching docs/skills updates | Adjusting doc-drift coverage or path mapping |
| `sync-codeowners.yml` | Keeps CODEOWNERS/policy state in sync. Has a `dry_run` boolean `workflow_dispatch` input — always run with `dry_run: true` first to preview changes before applying. Workflow makes irreversible `PUT/DELETE /collaborators` API calls across 4 downstream repos. | Governance / CODEOWNERS automation work |
| `sync-labels.yml` | Syncs `labels.json` (67 labels) to all factory repos — requires `MERGERAPTOR_APP_ID` + `MERGERAPTOR_PRIVATE_KEY` secrets (see issue #511) | Adding/retiring labels or debugging label drift |
| `scorecard.yml` | Weekly OpenSSF Scorecard analysis. Runs on schedule and on push to main. Uploads SARIF to the GitHub Security tab. | Adjusting security posture reporting |
| `release.yml` | Monthly/versioned OCI release flow. Triggered by schedule, `workflow_dispatch`, or automatically when `E2E` completes green on main. Uses git-cliff for changelog generation ([common#592](https://github.com/projectbluefin/common/pull/592)). | Changing versioned layer release behavior |
| `lifecycle-caller.yml` | Issue/PR lifecycle — slash commands, widget, label guard, stale sweep. Calls `projectbluefin/actions/.github/workflows/lifecycle.yml@<SHA>` (moved from `common` in [#570](https://github.com/projectbluefin/common/issues/570), closed 2026-06-10). Do not add lifecycle logic inline here — all logic lives in the `actions` reusable. | Changing factory lifecycle automation |

> **Workflows that do not exist in `common` and must not be re-added:**
> - `backfill-pipeline.yml` — issue widget backfill. If needed, run as a local script; do not add CI plumbing for a one-shot task.
> - `skill-drift.yml` — process convention as CI gate; violates AGENTS.md policy. See `ci-tooling.md` § Skill drift detection.
> - `docs-quality.yml` — skill frontmatter enforcement belongs in agent review, not CI.

## Mental model

### Validation and policy

`validate.yml`, `validate-brewfiles.yaml`, and `skill-drift.yml` are about catching repo-local mistakes **before merge**.

### Shared-layer build and release

`build.yml` and `release.yml` are about shipping the `common` layer itself.

### Downstream behavior checks

`pr-e2e.yml`, `e2e.yml`, `run-testsuite.yml`, and `promotion-candidate-e2e.yml` exist because `common` only proves itself when composed into downstream images.

### Factory operations

`lifecycle-caller.yml`, `sync-codeowners.yml`, and `sync-labels.yml` are factory-policy workflows rather than image-test workflows. Lifecycle ownership lives in `projectbluefin/actions/.github/workflows/lifecycle.yml`. The `lifecycle-caller.yml` in each repo is a thin SHA-pinned caller — Renovate keeps that SHA current.

## Which skill to load next

| If the work is about... | Load |
|---|---|
| Workflow pins, skill-drift, floating-tag guard | `ci-tooling.md` |
| Pre/post-merge or promotion-candidate tests | `e2e-ci.md` |
| Release cadence, promotion criteria, artifact signing | `release-promotion.md` |
| CODEOWNERS or governance policy | `governance.md` |
| Queue state / lifecycle | `queue-dashboard.md` and Hive context if needed |

## Hard rule

When editing workflows here, preserve the repo boundary:

- `common` validates the **shared layer**
- downstream image repos validate their **image-specific** behavior
- reusable CI logic should live in `projectbluefin/actions`, not be duplicated inline unless the logic is truly `common`-specific
