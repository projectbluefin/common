# Reviewer Ladder — Contribution Strategy (Planning Draft)

> **Status**: hold-gated planning artifact. Human review required before adoption.
> Filed by the strategist agent. Tracks [common#1029](https://github.com/projectbluefin/common/issues/1029);
> Phase 0 item of the org-wide roadmap ([common#1073](https://github.com/projectbluefin/common/pull/1073)).
>
> Nothing below changes GitHub roles, branch protection, CODEOWNERS, workflow behavior,
> or hold-gate enforcement until a maintainer adopts it.

## Problem

Reviewer coverage is the binding constraint in several repos, and the contributor
ladder has no rung between "opens PRs" and "maintainer" that grows it. Org-wide
throughput is healthy, but reviewer coverage is uneven across repos.

Reported state, using snapshots dated 2026-08-27 through 2026-09-05:

- **88 open hold-gated agent PRs** across 10 repos compete for limited
  per-repo reviewer coverage ([common#1043](https://github.com/projectbluefin/common/issues/1043): no
  prioritization rubric; the repo-concentration breakdown is in [common#1058](https://github.com/projectbluefin/common/issues/1058)).
- The lowest throughput is concentrated in common (4 merges), server (1),
  actions (0), and dakota-iso (0) while other repos drain ([common#1058](https://github.com/projectbluefin/common/issues/1058),
  last-7-day snapshot).
- Human-filed issues starve alongside: 74 issues in `1-triage`, 32 aged >60
  days ([common#1029](https://github.com/projectbluefin/common/issues/1029),
  2026-08-27 snapshot); 50 human-authored issues in triage, 17 aged >90
  days ([common#1067](https://github.com/projectbluefin/common/issues/1067),
  2026-08-31 snapshot).
- Downstream release impact at the 2026-09-04 snapshot: bluefin stable frozen
  46 days (stable-20260720), bluefin-lts 28 days stale, common missed its
  v2026.09 monthly tag, while dakota stable was current (0 days old)
  ([common#1078](https://github.com/projectbluefin/common/issues/1078)).

The ROADMAP ([common#1073](https://github.com/projectbluefin/common/pull/1073))
puts "reviewer-scaling rung" in Phase 0. This document is the concrete proposal
for that rung.

## Proposal: a four-rung ladder

| Rung | Role | Scope | Proposed grants |
|------|------|-------|--------|
| 0 | Contributor | any | fork PRs |
| 1 | **Triager** | per-repo | label, dedupe, reproduce, close-as-duplicate |
| 2 | **Domain Reviewer** | per-repo, per-domain | approving review on hold-gated PRs within an owned domain (e.g. justfiles, CI workflows, tests); cannot merge |
| 3 | Maintainer | per-repo | merge, release |

All permissions in this table are proposals, not current repository policy.

Rungs 1–2 are the new rungs. Both are **additive permissions**, reachable
without full maintainer trust, and directly attack the two measured
bottlenecks: triage age (rung 1) and hold-gate depth (rung 2).

### Promotion criteria (observable, no nomination-by-vibes)

- **Contributor → Triager** (proposed): 5+ merged PRs in the repo **or** 10
  substantive triage actions (reproduction notes, dedupe links, label
  corrections) on others' issues. A maintainer would confirm; no vote.
- **Triager → Domain Reviewer** (proposed): 30 days as Triager **and** 10
  reviewed hold-gated PRs in the claimed domain with maintainer sign-off on
  review quality. The domain would be recorded in the repo's contributor doc.
- **Domain Reviewer → Maintainer**: existing org process; unchanged.

### Why domain-scoped review

[common#1058](https://github.com/projectbluefin/common/issues/1058) shows
throughput is uneven across specific repos, not uniformly low. Domain-scoped
reviewers could let a trusted contributor unblock, say, `justfiles` in common
or `workflows` in dakota-iso without granting org-wide merge rights — matching
permission scope to the measured bottleneck.

### Interaction with the hold-gate

Agent-filed hold-gated PRs currently require human review before merge. Under
this draft, a Domain Reviewer's approval would satisfy the review requirement,
while a maintainer would still merge. This is a proposal only: it does not
change current permissions, branch protection, CODEOWNERS, or workflow
enforcement.

## Operating metrics

Adoption can be measured alongside the ROADMAP success table
([common#1073](https://github.com/projectbluefin/common/pull/1073)); these are
draft operating measures:

- Open hold-gated PR count (baseline: 88 on 2026-09-05) — ROADMAP target: <40
  and shrinking
- Median hold-gated PR review latency — draft target: <7 days
- Human-issue triage age — ROADMAP baseline: 50+ issues >30d on 2026-09-02,
  target: 0; supporting snapshots report 32 issues >60d on 2026-08-27 and
  17 >90d on 2026-08-31
- Zero-throughput repos ([common#1058](https://github.com/projectbluefin/common/issues/1058))
  — draft target: ≥1 merged agent PR per repo/month

## What this document deliberately does not do

- No workflow/CI changes (ci-maintainer lane).
- No changes to merge protection or CODEOWNERS (maintainer decision).
- No agent-lane throttling mechanics (tracked separately in [common#1052](https://github.com/projectbluefin/common/issues/1052)).

## Related

- [common#1029](https://github.com/projectbluefin/common/issues/1029) — reviewer-scaling rung finding (this doc's tracker)
- [common#1073](https://github.com/projectbluefin/common/pull/1073) — org-wide ROADMAP.md (Phase 0 parent)
- [common#1058](https://github.com/projectbluefin/common/issues/1058) — reviewer coverage map / repo-concentration data
- [common#1067](https://github.com/projectbluefin/common/issues/1067) — user-issue triage starvation
- [common#1043](https://github.com/projectbluefin/common/issues/1043) — hold-gate prioritization rubric
- [common#1078](https://github.com/projectbluefin/common/issues/1078) — release cadence breakdown (downstream symptom)
