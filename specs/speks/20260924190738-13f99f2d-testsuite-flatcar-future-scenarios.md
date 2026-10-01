---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: 20260924190738-13f99f2d-testsuite-flatcar-future-scenarios

## Overview

The Flatcar suite’s three currently inert scenarios become real install, Ignition and update-policy checks rather than permanent @future documentation. Test authors can land working content before the separate e2e.yml suite-entrypoint change makes the tests runnable in CI. Source: [testsuite#703](https://github.com/projectbluefin/testsuite/issues/703).

## Requirements

- [ ] **Exercise installation and boot**
  The Flatcar install/boot scenario performs a real installation and verifies the installed system boots.
- [ ] **Check Ignition provisioning**
  The Ignition scenario verifies a configured value appears in the resulting system.
- [ ] **Check disabled updates**
  The update_strategy=off scenario verifies update policy is off in the installed system.
- [ ] **Keep scenario inventory current**
  Future tags are removed only when the scenario has executable steps; suite counts and matching skill guidance are updated.
- [ ] **Pass repository gates**
  New Flatcar coverage passes existing lint and unit-test checks.

## Constraints

- The source baseline was 13 scenarios, 10 active and 3 @future on 2026-08-07; recount at implementation time.
- The flatcar suite is not currently selectable through e2e.yml until testsuite#704; do not claim CI execution before that dependency.
- Own changes in tests/flatcar/features/** and keep other suite work independent.

## Acceptance Criteria

- [ ] **Exercise installation and boot**
  A supported VM run executes the @install @boot scenario without @future and confirms the installed guest state.
- [ ] **Check Ignition provisioning**
  A VM run shows the expected Ignition-applied setting rather than only matching a step stub.
- [ ] **Check disabled updates**
  A VM run confirms the target update configuration is disabled without a fake success.
- [ ] **Keep scenario inventory current**
  behave --dry-run tests/flatcar/features has no undefined steps; suite-map and docs/qa-review match the resulting active/future count.
- [ ] **Pass repository gates**
  ruff check tests/ --select E,F,W --ignore E501 and python3 -m pytest tests/unit/ -q pass.

## Technical Approach

- Current scenario locations in tests/flatcar/features/lifecycle.feature are the source anchors: install/boot line 19, Ignition line 28, update_strategy=off line 38.
- The three steps can be written independently; expose the suite via #704 rather than duplicating reusable-workflow changes here.

## Success Metrics

- All three formerly future scenarios run with real behavior and the documented count matches the executable suite.

## Non-Goals

- No generic retry/quarantine mechanism, unrelated Flatcar scenarios or fake hardware stubs.
