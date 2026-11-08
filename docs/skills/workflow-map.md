---
name: workflow-map
version: "2.4"
last_updated: "2026-10-07"
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

`common` builds the shared OCI layer. Workflow YAML is authoritative for
triggers, runner versions, permissions, and dependency pins.

| Workflow | Responsibility |
|---|---|
| [validate.yml](../../.github/workflows/validate.yml) | Just syntax, shellcheck, submodule drift, image references, dconf parity, pre-commit |
| [unit-tests.yml](../../.github/workflows/unit-tests.yml) | All Python and Bats suites; Bazaar coverage gate |
| [validate-brewfiles.yaml](../../.github/workflows/validate-brewfiles.yaml) | Networked Homebrew metadata validation |
| [validate-chairlift-config.yaml](../../.github/workflows/validate-chairlift-config.yaml) | ChairLift config against the schema selected by its release pin |
| [build.yml](../../.github/workflows/build.yml) | Per-architecture layer builds, publication, multi-arch manifest, signing and attestations |
| [pr-e2e.yml](../../.github/workflows/pr-e2e.yml) | Compose the PR layer into a downstream test image before merge |
| [e2e.yml](../../.github/workflows/e2e.yml) | Advisory post-merge checks of downstream testing images; failure reporting |
| [run-testsuite.yml](../../.github/workflows/run-testsuite.yml) | Shared testsuite entrypoint and pin |
| [promotion-candidate-e2e.yml](../../.github/workflows/promotion-candidate-e2e.yml) | Scheduled downstream promotion-candidate checks |
| [release.yml](../../.github/workflows/release.yml) | Scheduled/manual versioned layer releases |
| [scorecard.yml](../../.github/workflows/scorecard.yml) | OpenSSF security reporting |
| [prow.yml](../../.github/workflows/prow.yml) | Issue/PR commands and merge-queue routing; see [labels](label-workflow.md) |
| [bazaar-featured-refresh.yml](../../.github/workflows/bazaar-featured-refresh.yml) | Refresh the featured-app row by PR, without auto-merge |

## Boundaries

- `common` validates the shared layer; downstream repositories own their
  image-specific behavior. Reusable factory CI belongs in `projectbluefin/actions`.
- Required checks must report for every eligible PR and merge-group ref.
  Skip expensive steps, not required jobs, for documentation-only changes.
- Keep `just check` hermetic. Networked Brewfile and ChairLift checks stay separate.
- Post-merge E2E is advisory: it tests downstream images, not the layer just
  published. Inspect the failing image before assigning ownership.
- Query live branch rulesets before changing required check names or landing
  work; this index is not a copy of branch protection.

## Tests and references

CI derives suites from `tests/test_*.py` and `tests/*.bats`. Register new suites
in the `Justfile` too; `test_suite_registration.bats` checks that local path.
Python dependencies are pinned in `tests/requirements.txt`.

Use [CI tooling](ci-tooling/SKILL.md) for action pins and pre-commit,
[E2E](e2e-ci/SKILL.md) for composition tests, and
[release promotion](release-promotion/SKILL.md) for release behavior.
