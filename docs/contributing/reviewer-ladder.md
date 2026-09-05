# Reviewer Ladder — Contribution Strategy (Planning Draft)

> **Status**: hold-gated planning artifact. Human review required before adoption.
> Filed by the strategist agent. Tracks common#1029; Phase 0 item of the org-wide
> roadmap (common#1073).

## Problem

Review capacity is the org's binding constraint, and the contributor ladder has
no rung between "opens PRs" and "maintainer" that grows it.

Verified state as of 2026-09-05:

- **88 open hold-gated agent PRs** across 9 repos compete for the same small
  pool of human reviewers (common#1043: no prioritization rubric).
- Queue growth is **repo-concentrated, not volume-driven** — common, server,
  actions, and dakota-iso show ~zero review throughput while other repos drain
  (common#1058).
- Human-filed issues starve alongside: 74 issues in triage, 32 aged >60 days
  (common#1029); 50 human issues waiting, 17 aged >90 days (common#1067).
- Downstream release impact: bluefin stable frozen 47 days (stable-20260720),
  bluefin-lts 29 days stale, common missed its v2026.09 monthly tag, while
  dakota — with active review attention — ships daily (common#1078).

The ROADMAP (common#1073) puts "reviewer-scaling rung" in Phase 0. This document
is the concrete proposal for that rung.

## Proposal: a four-rung ladder

| Rung | Role | Scope | Grants |
|------|------|-------|--------|
| 0 | Contributor | any | fork PRs |
| 1 | **Triager** | per-repo | label, dedupe, reproduce, close-as-duplicate |
| 2 | **Domain Reviewer** | per-repo, per-domain | approving review on hold-gated PRs within an owned domain (e.g. justfiles, CI workflows, tests); cannot merge |
| 3 | Maintainer | per-repo | merge, release |

Rungs 1–2 are the new rungs. Both are **additive permissions**, reachable
without full maintainer trust, and directly attack the two measured
bottlenecks: triage age (rung 1) and hold-gate depth (rung 2).

### Promotion criteria (observable, no nomination-by-vibes)

- **Contributor → Triager**: 5+ merged PRs in the repo **or** 10 substantive
  triage actions (reproduction notes, dedupe links, label corrections) on
  others' issues. Any maintainer confirms; no vote.
- **Triager → Domain Reviewer**: 30 days as Triager **and** 10 reviewed
  hold-gated PRs in the claimed domain with maintainer sign-off on review
  quality. Domain is recorded in the repo's contributor doc.
- **Domain Reviewer → Maintainer**: existing org process; unchanged.

### Why domain-scoped review

common#1058 shows throughput is near-zero in specific repos, not uniformly
low. Domain-scoped reviewers let a trusted contributor unblock, say,
`justfiles` in common or `workflows` in dakota-iso without granting org-wide
merge rights — matching permission scope to the measured bottleneck.

### Interaction with the hold-gate

Agent-filed hold-gated PRs require human review before merge. A Domain
Reviewer's approval satisfies the *review* requirement; a maintainer still
merges. This preserves the hold-gate's safety property while multiplying
review bandwidth — the scarce resource.

## Operating metrics

Adoption is measurable against the ROADMAP success table (common#1073):

- Hold-gated PR count (baseline: 88 on 2026-09-05) — target: declining trend
- Median hold-gated PR review latency — target: < 7 days
- Human-issue triage age (baseline: 32 issues >60d, 17 >90d) — target: 0 >60d
- Zero-throughput repos from common#1058 — target: ≥1 merged agent PR/repo/month

## What this document deliberately does not do

- No workflow/CI changes (ci-maintainer lane).
- No changes to merge protection or CODEOWNERS (maintainer decision).
- No agent-lane throttling mechanics (tracked separately in common#1052).

## Related

- common#1029 — reviewer-scaling rung finding (this doc's tracker)
- common#1073 — org-wide ROADMAP.md (Phase 0 parent)
- common#1058 — reviewer coverage map / repo-concentration data
- common#1067 — user-issue triage starvation
- common#1043 — hold-gate prioritization rubric
- common#1078 — release cadence breakdown (downstream symptom)
