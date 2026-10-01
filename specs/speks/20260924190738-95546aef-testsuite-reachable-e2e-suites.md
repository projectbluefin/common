---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: 20260924190738-95546aef-testsuite-reachable-e2e-suites

## Overview

Consumers of testsuite’s reusable e2e workflow can request the security, hardware, lifecycle, Flatcar, NVIDIA and installer suites already in the repository instead of maintaining unreachable test files. Availability and expected hardware blockers remain explicit so a selectable suite is not mistaken for passing coverage. Source: [testsuite#704](https://github.com/projectbluefin/testsuite/issues/704).

## Requirements

- [ ] **Expose runnable suites**
  The reusable workflow accepts security, hardware, lifecycle, Flatcar and installer suites as declared inputs.
- [ ] **Keep NVIDIA truthfully gated**
  The NVIDIA suite is selectable only under its @hardware_blocked/hardware-emulation conditions.
- [ ] **Scale scenario distribution**
  Shard scheduling handles suite sizes beyond the old smoke/common-only split.
- [ ] **Publish truthful input docs**
  The suites input description, reference docs and suite map agree on every available suite and documented expected-fail state.
- [ ] **Prove consumed workflow behavior**
  Existing downstream callers continue to work while the new input and shard logic pass tests.

## Constraints

- Reusable e2e.yml is consumed across repos: human CI-interface/breakage review is required before modifying inputs or shard behavior.
- The source body’s old 1-triage statement conflicts with its current agent-queue label; routing remains with the owning workflow, not this spec.
- Wait for or coordinate #698 job summaries, #691 release gate and #697 installer post-boot changes to avoid overriding contested e2e.yml.

## Acceptance Criteria

- [ ] **Expose runnable suites**
  A consumer selects each suite and sees its scenarios scheduled or an explicit linked blocker.
- [ ] **Keep NVIDIA truthfully gated**
  Without supported GPU hardware the suite reports its blocked reason, not a green result from zero executed scenarios.
- [ ] **Scale scenario distribution**
  A large common and one new suite execute without duplicate or missing scenarios.
- [ ] **Publish truthful input docs**
  Docs/skills remove stale #43/#44 blockers; references/inputs-outputs.md lists the same accepted input values as e2e.yml.
- [ ] **Prove consumed workflow behavior**
  tests/unit/test_e2e_workflow.py and real selected suite workflows pass or carry a linked expected-fail issue.

## Technical Approach

- Owned paths are .github/workflows/e2e.yml, tests/unit/test_e2e_workflow.py and docs/skills/ci-ops/e2e-workflow/**.
- Original suite-map baseline: security 15, hardware 13, NVIDIA 12 @future, Flatcar 13, lifecycle 27 plus installer; refresh counts from current source at implementation.

## Success Metrics

- Every requested suite either runs observable scenarios or exposes a specific blocker, never a zero-scenario green.

## Non-Goals

- No new workflow state labels and no claim that suite reachability alone proves hardware coverage.
