---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: 20260924190738-c2c05954-testsuite-three-lane-bluefin-migration

## Overview

Bluefin maintainers can demonstrate that an installed ublue-os/bluefin stable image migrates to projectbluefin/bluefin stable and boots its new deployment in each supported transport lane. A screenshot and target-digest evidence distinguish a real migrated boot from a test that restarted the old kernel. Source: [testsuite#227](https://github.com/projectbluefin/testsuite/issues/227).

## Requirements

- [ ] **Boot installed deployments through firmware**
  Migration tests reboot a bootc-installed disk using UEFI/OVMF so the new deployment is selected.
- [ ] **Validate registry-pull lane**
  The rechunker lane switches to the target via the standard registry transport.
- [ ] **Validate local chunked lane**
  The zstd:chunked lane pulls with Podman then switches from containers-storage.
- [ ] **Gate unified-storage lane by capability**
  The experimental unified-storage lane runs on bootc versions that support it and skips honestly elsewhere.
- [ ] **Capture visible migration proof**
  Each supported lane retains a post-migration screenshot with linked workflow and source/target refs.

## Constraints

- testsuite#227 remains on hold; #229 UEFI proof gates the still-open #232 workflow. #228 is the closed SSH return-code fix, not the UEFI spike. Do not treat direct QEMU kernel boot as valid migration coverage.
- The source image is ublue-os/bluefin and target projectbluefin/bluefin; `ublue-os/*` access is read-only.
- Use real bootc behavior and current transport flags as observed in the tested environment, not an unverified stored invocation.

## Acceptance Criteria

- [ ] **Boot installed deployments through firmware**
  After bootc switch and reboot, the VM reports the new deployment rather than the old direct-kernel boot args.
- [ ] **Validate registry-pull lane**
  The switched image boots and the target digest, boot status and screenshot are captured.
- [ ] **Validate local chunked lane**
  The switched local image boots and reports the expected digest and artifact.
- [ ] **Gate unified-storage lane by capability**
  On bootc >=1.16 the lane runs and boots; on older stable it is explicitly skipped with a version reason.
- [ ] **Capture visible migration proof**
  A reviewer can match the screenshot, installed deployment digest and workflow to the selected lane.

## Technical Approach

- Use OVMF pflash so systemd-boot selects the post-switch BLS entry. Existing e2e.yml direct `-kernel/-initrd/-append` cannot prove that.
- Live child state differs from the source checklist: #228 SSH return-code fix, #229 UEFI spike, #230 parameterized steps, #231 zstd:chunked scenario and #233 screenshot artifact are CLOSED; #232 workflow matrix is OPEN. Keep the existing work and finish only its unproven end-to-end behavior.

## Success Metrics

- Three runnable lanes produce matching new deployment proof and screenshots, or a documented capability-based skip for unified storage.

## Non-Goals

- No writes to ublue-os repos and no claim that direct-kernel QEMU reboot tests the new bootloader.
