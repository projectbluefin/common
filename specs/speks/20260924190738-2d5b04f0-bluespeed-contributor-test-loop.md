---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: 20260924190738-2d5b04f0-bluespeed-contributor-test-loop

## Overview

A Bluefin contributor can report a real hardware failure, see Hive triage it and verify a fix on their own machine without owning a homelab. Bluespeed coordinates this opt-in loop while laptops remain bootc-image clients rather than cluster nodes. Source: [bluespeed#16](https://github.com/projectbluefin/bluespeed/issues/16).

## Requirements

- [ ] **Report with consent**
  A contributor can collect device evidence with ujust report and choose when to share a user-controlled gist.
- [ ] **Connect report to triage**
  Hive can turn a submitted report into an issue with a traceable source and proposed fix.
- [ ] **Verify on real hardware**
  Contributors can confirm or reject a PR fix on their own machine and attach that observation to the issue.
- [ ] **Show useful fleet context**
  The dashboard displays cluster health and contributor activity without conflating enrolled client laptops with nodes.

## Constraints

- Clients run bootc images and may install an OTel agent for enrollment; they must never be represented as k3s nodes.
- Reports remain user-controlled and opt-in, with no automated data transfer before explicit consent.
- Use the existing Flatcar, k3s, KubeStellar Console and Argo Workflows platform rather than mandating a homelab for every volunteer.

## Acceptance Criteria

- [ ] **Report with consent**
  A report contains the intended device evidence but nothing is published or linked before user consent.
- [ ] **Connect report to triage**
  A submitted example can be followed from report link through the issue to a candidate PR.
- [ ] **Verify on real hardware**
  A volunteer with only a laptop can submit a fix confirmation without enrolling as a k3s node.
- [ ] **Show useful fleet context**
  A single-control-box setup shows correct host, k3s VM/node and client distinctions.

## Technical Approach

- The issue’s loop is ujust report → Hive issue → PR hardware confirmation. Ghost/control-box runs the platform, VMs are cluster nodes and laptops consume images.
- OTel Collector and Prometheus provide telemetry and metrics, not a new reporter or issue backend.

## Success Metrics

- A contributor with no homelab can complete a report-to-verified-fix loop.

## Non-Goals

- No laptop k3s enrollment, mandatory hardware fleet or unsolicited telemetry.
