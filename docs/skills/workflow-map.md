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
| `docs-quality.yml` | PR gate: skill frontmatter presence and Trail of Bits CI integration | Keeping skill docs complete and well-formed |
| `build.yml` | Builds and publishes the `common` OCI layer on merge. **Supply chain gap:** currently uses key-based cosign signing inline — migration to shared `sign-and-publish` + `scan-image` tracked in [common#513](https://github.com/projectbluefin/common/issues/513) / [actions#86](https://github.com/projectbluefin/actions/issues/86). | Changing how the shared layer is built or pushed |
| `pr-e2e.yml` | Pre-merge composed-image gate for the PR's common layer (composes + runs common suite via `run-testsuite.yml`) | Changing how PR-time downstream composition is tested |
| `e2e.yml` | Post-merge common-suite validation against Bluefin stable and Bluefin LTS. Dakota matrix entry is currently skipped ([issue #497](https://github.com/projectbluefin/common/issues/497) — build machine broken). | Changing shipped-layer validation after merge |
| `run-testsuite.yml` | Local wrapper that centralizes the pinned `projectbluefin/testsuite` SHA | Updating the shared testsuite pin or common-side testsuite wiring |
| `promotion-candidate-e2e.yml` | Weekly smoke/common check against `bluefin:testing` and `bluefin:lts-testing` | Adjusting common-side signal before downstream Tuesday promotions |
| `skill-drift.yml` | Warns when implementation changes land without matching docs/skills updates | Adjusting doc-drift coverage or path mapping |
| `sync-codeowners.yml` | Keeps CODEOWNERS/policy state in sync | Governance / CODEOWNERS automation work |
| `sync-labels.yml` | Syncs `labels.json` (67 labels) to all factory repos — requires `MERGERAPTOR_APP_ID` + `MERGERAPTOR_PRIVATE_KEY` secrets (see issue #511) | Adding/retiring labels or debugging label drift |
| `release.yml` | Monthly/versioned OCI release flow. **Planned improvements:** git-cliff changelog + e2e prerequisite gate — see [`automation-audit/release-with-cliff.yml`](../factory/automation-audit/release-with-cliff.yml) for the ready-to-deploy replacement. Tracked in [common#513](https://github.com/projectbluefin/common/issues/513). | Changing versioned layer release behavior |
| `lifecycle-caller.yml` | Issue/PR lifecycle — slash commands, widget, label guard, stale sweep. Calls common `lifecycle.yml`. | Changing factory lifecycle automation |

## Mental model

### Validation and policy

`validate.yml`, `validate-brewfiles.yaml`, and `skill-drift.yml` are about catching repo-local mistakes **before merge**.

### Shared-layer build and release

`build.yml` and `release.yml` are about shipping the `common` layer itself.

### Downstream behavior checks

`pr-e2e.yml`, `e2e.yml`, `run-testsuite.yml`, and `promotion-candidate-e2e.yml` exist because `common` only proves itself when composed into downstream images.

### Factory operations

`lifecycle-caller.yml`, `sync-codeowners.yml`, and `sync-labels.yml` are factory-policy workflows rather than image-test workflows. Lifecycle ownership itself lives in `common`'s reusable `.github/workflows/lifecycle.yml`.

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
