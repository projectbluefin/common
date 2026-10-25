---
name: e2e-ci
version: "1.2"
last_updated: "2026-09-13"
id: e2e-ci
one_line_purpose: Debug pre/post-merge E2E CI for common.
entry_point: docs/skills/e2e-ci/SKILL.md
category: test-authoring
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [e2e, testing, ci]
description: >-
  Pre/post-merge E2E CI for common. Use when debugging E2E failures,
  understanding the PR gate flow, or diagnosing masked brew-setup issues.
metadata:
  type: reference
---

# E2E CI

## When to Use

Use when debugging E2E failures, understanding the PR gate flow, diagnosing
masked `brew-setup` issues, or wiring E2E as a gate in a promotion pipeline.

## When Not to Use

Do not use this skill for lab/KubeVirt testing (see
[`../lab-testing/SKILL.md`](../lab-testing/SKILL.md)), or for generic GitHub
Actions authoring unrelated to the `common` test workflows.

## Post-merge E2E

**File:** `.github/workflows/e2e.yml`

- Triggers on `push` to `main` (paths-ignore markdown, `docs/**`, and `.github/workflows/**`) and `workflow_dispatch`
- Calls the local `.github/workflows/run-testsuite.yml` wrapper, which centralizes the pinned `projectbluefin/testsuite` SHA
- Matrix of **two** downstream images, both with `suites: common`:
  - `ghcr.io/projectbluefin/bluefin:testing`
  - `ghcr.io/projectbluefin/dakota:testing`
- **Bluefin LTS is deliberately absent.** Its common suite failed every run (bootupd missing, `bootloader-update.service` failing, LockLayering blocking rpm-ostree) — [bluefin-lts#492](https://github.com/projectbluefin/bluefin-lts/issues/492). A permanently red advisory check teaches everyone to ignore it, and GitHub does not allow `continue-on-error` on a job that calls a reusable workflow, so the entry could not be soft-failed in place. LTS stays covered by `promotion-candidate-e2e.yml`. Restore the matrix entry when #492 is fixed
- Advisory only: it is not a required status check, and it runs after `common:latest` has already been pushed. On failure a `report-failure` job opens or updates one tracking issue
- Uses SSH-mode tests from the runner, so the common suite does not require a full GNOME session

## Pre-merge gate

**File:** `.github/workflows/pr-e2e.yml`

- Runs on PRs to `main` and on `merge_group`
- Builds the PR's `common` layer candidate first
- Composes a downstream test image from `BASE_IMAGE: ghcr.io/projectbluefin/bluefin:testing` by overlaying `/system_files/shared` and `/system_files/bluefin`
- Recompiles GSettings schemas in the composed image
- Pushes the composed image to GHCR and runs the local testsuite wrapper with `suites: common`

This is the pre-merge signal for common-layer changes, so regressions surface before merge instead of waiting for post-merge E2E. It is **not** a required check — the ruleset requires only `validate` and the two `Build and push image` jobs. See [workflow-map.md](../workflow-map.md).

> **Known tension:** a `:testing` base means unrelated downstream churn (for example a CLI tool missing from the current testing image) can fail a `common` PR that only changed the shared layer. A stable base would isolate that, but `bluefin:stable` is not what the workflow uses today. If you change it, change this section in the same commit.

## Promotion-candidate feedback loop

**File:** `.github/workflows/promotion-candidate-e2e.yml`

- Runs weekly on Tuesdays before the downstream Bluefin promotion workflows
- Tests the exact candidate tags used for promotion from common's side:
  - `ghcr.io/projectbluefin/bluefin:testing`
  - `ghcr.io/projectbluefin/bluefin:lts-testing`
- Runs `smoke,common` to add a boot/basic-usage signal on top of the shared-layer checks
- Uses the same local testsuite wrapper as PR/post-merge workflows, so the testsuite SHA stays aligned

This is **not** a full installer gate. It is the smallest safe repo-local improvement common can make without editing downstream image repos or installer pipelines.

## Known CI caveats and quarantines

- `brew-setup.service` is masked in CI, so Homebrew-installed CLI tools are not present unless explicitly provisioned during the job
- Everything else here is `projectbluefin/testsuite` internal state — quarantined scenarios, `@pending` placeholders, PATH mismatches. That list lives in the testsuite repo and changes without a `common` commit; read it there rather than mirroring it

## Testsuite SHA pin

`.github/workflows/run-testsuite.yml` is the only file in this repo that names the testsuite SHA, and all three callers go through it. When the pin lags behind testsuite `main`, quarantined scenarios may run and cause spurious failures. Renovate does not currently propose bumps for it — check testsuite `main` by hand when a testsuite fix you need has landed.

## Red Flags

- A change to any of the three testsuite callers that adds its own `projectbluefin/testsuite` ref instead of going through `run-testsuite.yml` — that forks the pin
- Restoring the `bluefin:lts-testing` entry to `e2e.yml` before [bluefin-lts#492](https://github.com/projectbluefin/bluefin-lts/issues/492) closes, re-establishing a permanently red advisory check
- Treating a red `e2e.yml` run as a `common` defect without first reading which matrix entry failed
- An unanchored `--certificate-identity-regexp` wildcard in cosign verify

## Verification

- [ ] `pr-e2e.yml`'s `BASE_IMAGE` and `e2e.yml`'s matrix match what this file says — both are single `grep`s
- [ ] `run-testsuite.yml` SHA pin matches the testsuite commit being relied on
- [ ] No workflow other than `run-testsuite.yml` references `projectbluefin/testsuite`
- [ ] cosign identity regexp is anchored with `^...$`

## References

| File | Description |
|---|---|
| [`references/promotion-patterns.md`](references/promotion-patterns.md) | **Downstream image repos, not `common`.** `promote-to-testing` job pattern, TOCTOU guard, cosign verify anchoring, cosign install on GHA runners. |
| [`references/never-stall-design.md`](references/never-stall-design.md) | **Downstream image repos, not `common`.** Promotion gate never-stall design: E2E on the testing branch, feedback trigger, jq selector, bluefin bootstrap. |
