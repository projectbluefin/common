---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: 20260924190738-4e622a28-testsuite-lab-coverage-prerequisites

## Overview

Test authors can see the lab-owned infrastructure dependencies that currently keep hardware and lifecycle scenarios inert, and can clear blocker tags once those dependencies really work. This coordination specification tracks dependencies; resulting GPU, TPM and image-ref infrastructure belongs in projectbluefin/lab, not testsuite. Source: [testsuite#706](https://github.com/projectbluefin/testsuite/issues/706).

## Requirements

- [ ] **Resolve GPU feasibility**
  Lab owners decide and document whether GPU passthrough can run the 12 NVIDIA scenarios, with an owned lab issue.
- [ ] **Provide measured-boot VM capability**
  A TPM/OVMF-capable VM configuration becomes available for Secure Boot and measured-boot scenarios.
- [ ] **Provide a second image ref**
  Lifecycle CI receives a stable alternate image reference for a real bootc switch.
- [ ] **Unblock suites only after proof**
  Each corresponding @future, @hardware_blocked or quarantine marker is removed only when its prerequisite is exercised.

## Constraints

- No testsuite-owned infrastructure files; VM specs, KubeVirt and workflow orchestration are owned by projectbluefin/lab.
- Do not create issues, PRs or comments in ublue-os/*; those repositories remain read-only.
- Reaching a suite via testsuite#704 is necessary but not proof GPU or TPM hardware exists.

## Acceptance Criteria

- [ ] **Resolve GPU feasibility**
  A lab-side issue or evidence-backed infeasibility decision is linked before removing @hardware_blocked.
- [ ] **Provide measured-boot VM capability**
  The lab VM runs a measured-boot scenario with TPM evidence and testsuite#705 links that environment.
- [ ] **Provide a second image ref**
  A lifecycle run actually switches to a different digest and reports it; no quarantined switch is counted as passed.
- [ ] **Unblock suites only after proof**
  The source scenario executes from CI and its previous blocker tag/issue link reflects the new state.

## Technical Approach

- Source table links GPU to 12 inactive NVIDIA scenarios, TPM to measured boot #705 and the alternate ref to tests/lifecycle/features/bootc.feature.
- This issue coordinates separately owned lab work rather than adding phantom test-only code.

## Success Metrics

- Previously blocked suites have real lab evidence and executable CI scenarios before blocker tags are removed.

## Non-Goals

- No duplicate lab infrastructure in testsuite and no assertion that disabled scenarios provide coverage.
