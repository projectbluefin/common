---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: 20260924190738-28eb0070-utah-release-readiness

## Overview

Utah reaches releasable image and ISO quality with independently traceable package, desktop, upgrade and recovery evidence while preserving its Hummingbird bootc/RPM design. The linked Utah and Utah-packages issues remain the concrete audit slices rather than a second hidden backlog. Source: [utah#71](https://github.com/projectbluefin/utah/issues/71).

## Requirements

- [ ] **Resolve linked release blockers**
  Every linked P0/P1 Utah and Utah-packages slice is resolved or has an explicit maintainer-approved exception.
- [ ] **Gate the image on real behavior**
  One immutable Utah image digest passes package, desktop, VM, installer, upgrade and rollback checks.
- [ ] **Prove offline installation**
  A checksummed production ISO completes offline plain and encrypted installs.
- [ ] **Trace publication**
  Testing/stable tags and ISO releases resolve to the exact tested image digest and originating workflow run.

## Constraints

- Utah retains Hummingbird bootc/RPM architecture; Dakota is reference for evidence/promotion practices, not a mandated stack change.
- The source body contains literal escaped newlines; preserve and normalize all 21 task-list links when rewriting the issue.
- Do not claim a linked issue completed merely because a label or old tracker text changed.

## Acceptance Criteria

- [ ] **Resolve linked release blockers**
  Each of the 21 linked issue URLs is accounted for as closed with evidence or an approved, documented exception.
- [ ] **Gate the image on real behavior**
  Test results name the same digest and show each required lane completed.
- [ ] **Prove offline installation**
  Both installation variants boot from the published ISO and match its published checksum.
- [ ] **Trace publication**
  A reviewer follows image digest and workflow identity from passing gates through published tags and ISO artifacts.

## Technical Approach

- Audit slices: utah-packages#22–#25, #19–#21 and utah#10–#23 (21 URLs in the original); link their exact issue URLs at the top of the rewritten body.
- Keep the existing Hive Agent attribution as issue metadata; do not interpret the literal escaped formatting as missing tasks.

## Success Metrics

- One tested digest can be traced across image, ISO and publication gates without inconsistent source refs.

## Non-Goals

- No replatform to Dakota BuildStream, unapproved exception or placeholder release proof.
