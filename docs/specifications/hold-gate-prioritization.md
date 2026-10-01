---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: hold-gate-prioritization

## Overview

Human review capacity is limited, so security repairs and approved release gates can wait beside non-urgent coverage and documentation PRs. This draft preserves the unadopted proposal landed by [common#1188](https://github.com/projectbluefin/common/pull/1188) for [common#1043](https://github.com/projectbluefin/common/issues/1043), including the expedite finding in [common#1082](https://github.com/projectbluefin/common/issues/1082). The issue closed when the *proposal document* merged; no priority tier or deadline is operative until maintainers decide.

## Requirements

- [ ] **Order review by verified impact**
  Reviewers can distinguish security, supply-chain and org-wide integrity risks from release blockers and routine tests/docs using evidence from each current PR.
- [ ] **Surface approved release promotions**
  A release-ready promotion with actual approval is presented promptly rather than hidden behind low-risk PRs; its owner can explicitly disposition a blocker.
- [ ] **Avoid reviewing superseded work**
  Before spending a human review slot on an aged PR, the reviewer checks whether an equivalent change already merged and presents any collision for a human verdict.
- [ ] **Keep ordinary work moving**
  Test-only and documentation PRs can still be reviewed with the existing easy-wins mode after urgent blockers are considered; priority metadata cannot silently stop their queue.
- [ ] **Measure the tradeoff**
  Reviewers can compare first-review times, release-gate delay and aged-PR depth against a fresh baseline before extending a pilot.

## Constraints

- Proposed **P0** (security, cryptographic verification, shared/base-image integrity), **P1** (approved release gates, user-visible regressions and dependency blockers), and **P2** (test additions, docs and non-breaking refactors) are *candidate review order*, not workflow labels or accepted policy. Classification requires the real blast radius; a test PR touching production is not automatically P2.
- The source proposed first review within 24–48 hours for P0, 3–5 days for P1, a 48-hour release-gate expedite after approval, and weekly P2 sweeps. These time targets require maintainer approval and current capacity evidence before use.
- Preserve all seven workflow labels, human review/merge decisions, CI and branch protection. Do not introduce `hold-p0`/`hold-p1`/`hold-p2`, another merge gate, or auto-close a stale PR. Any queue mutation follows the existing human-verdict process.
- Historic August–September 2026 counts (33→95 open hold-gated PRs, then contraction) are source context, not current measurements. This specification is separate from [reviewer capacity](reviewer-ladder.md) and [agent filing throttle](agent-lane-throttle.md).

## Acceptance Criteria

- [ ] **Risk ordering is reproducible**
  For a live sample including a security fix, an approved promotion and a test-only change, a reviewer can cite the PR evidence and explain the order without inventing new GitHub state.
- [ ] **Expedite respects approval**
  An approved `release/ready` or promotion PR is brought to a maintainer within the adopted window; an unapproved or red PR does not bypass checks or the human merge gate.
- [ ] **Staleness is checked before disposition**
  An aged PR that duplicates a merged change is identified with the merged commit; closing it still requires its own human verdict, while a non-duplicate remains reviewable.
- [ ] **Normal work is not suppressed**
  With no urgent blocker, test/docs PRs are presented small-first through existing easy-wins mode; no tier changes their labels, approvals or merge eligibility.
- [ ] **Pilot effect is visible**
  Fresh baseline and pilot observations include per-tier first-review age, promotion turnaround, PRs awaiting review and time spent on superseded changes.

## Technical Approach

A maintainer first chooses whether to adopt any tiering, expedite target and reviewer owner. A reversible pilot can display the evidence and candidate order in the existing human-decides, agent-lands [review cards](../skills/pr-review/SKILL.md); the draft must not change their behavior before sign-off. The source's suggested PR-body priority headings or commit trailers are optional review metadata, not new labels or a parallel state machine. Check against current `main` before proposing that a PR is obsolete; only a human verdict closes it.

## Success Metrics

- Compared with a newly measured baseline, the approved security and release-gate work receives first human review within adopted targets without bypassing checks.
- Lower-risk PRs remain reviewable, and reviewers avoid spending time on already-landed work; measure both tails rather than assuming old backlog snapshots still apply.

## Non-Goals

- Enacting the proposal by publishing this draft or by the closure of its source issue.
- A new label taxonomy, automated merge, unilateral PR closure, reviewer permission grant, or CI gate for review order.
- Treating an agent's priority claim or a historical queue count as maintainer approval.
