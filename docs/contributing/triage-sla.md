# Triage SLA — Human-Issue Response Strategy (Planning Draft)

> **Status**: hold-gated planning artifact. Human review required before adoption.
> Filed by the strategist agent. Tracks [common#1067](https://github.com/projectbluefin/common/issues/1067);
> the demand-side complement to the reviewer-scaling rung
> ([reviewer-ladder.md](reviewer-ladder.md)) and the hold-gate prioritization
> rubric ([common#1043](https://github.com/projectbluefin/common/issues/1043)).
>
> Nothing below changes labels, workflow behavior, branch protection, or hold-gate
> enforcement until a maintainer adopts it.

## Problem

Human-filed issues starve in `1-triage` while agent-lane PRs are serviced.
Two snapshots of the same funnel:

- **2026-08-31** ([common#1067](https://github.com/projectbluefin/common/issues/1067)):
  68 issues in triage org-wide, **50 human-authored**; **17 untriaged for over
  90 days**; the oldest was [common#192](https://github.com/projectbluefin/common/issues/192)
  (PassKey support, 216 days).
- **2026-09-05** (issue refresh): triage queue grew to **77 issues** — 32 aged
  >60 days, **21 aged >90 days**; 53 of 77 (69%) concentrated in common (28)
  and dakota (25).

In the same window the hold-gated agent-PR queue went 95 → 88 — its first
contraction, meaning reviewer attention is arriving, but it is landing on agent
output rather than human-filed triage. A project that ships agent PRs daily
while a user's feature request waits 216 days for a first human read is
optimizing the wrong side of the contribution funnel: new contributors judge
project health by whether *their* issue gets a response.

This is distinct from [common#1037](https://github.com/projectbluefin/common/issues/1037)
(dakota *defect* backlog) and [common#959](https://github.com/projectbluefin/common/issues/959)
(agent *advisory* backlog); this finding covers org-wide **human-authored
issues in the triage stage**.

## Proposal 1: a triage SLA for human-authored issues

| Metric | Proposed SLA | Measured on |
|---|---|---|
| First human response to a human-authored issue in `1-triage` | **14 days** | count of human-authored triage issues older than SLA |

Definitions, kept deliberately simple so the number can be produced with one
query:

- **Human-authored**: opened by an account that is not a bot or the repository's
  automation identity. Bot-filed issues follow their own intake lanes and are
  out of scope.
- **First human response**: the first comment, label change, assignment, or
  close by a human (not a bot). A bot's automated acknowledgment does not stop
  the SLA clock.
- **SLA clock**: starts when the issue enters `1-triage`; stops at first human
  response. The `blocked` and `hold` overlays pause the clock while active —
  a blocked issue is not an ignored one.

The SLA is a **surfacing contract, not a resolution contract**: triage means a
human has read the issue and made a routing decision (answer, discuss, queue,
close, or mark blocked). It does not promise the work itself is done.

## Proposal 2: a review-allocation rule

When a repository's human-authored triage queue is **over** SLA (any
human-authored issue older than 14 days with no first human response), reviewer
hours go to triage first: an agent-lane PR batch is not picked up until the
breach is cleared. Concretely, in backlog review
([pr-review](../skills/pr-review/SKILL.md)):

1. **Triage cards before PR cards.** Human-authored `1-triage` issues over SLA
   are presented first in a backlog-review session, ahead of agent-lane PR
   cards.
2. **Oldest first.** Over-SLA cards are presented oldest-first; the 216-day
   case must be structurally impossible next year.
3. **Under SLA, no constraint.** Once the queue is under SLA, review time is
   unconstrained and normal prioritization (e.g. the hold-gate rubric proposed
   in [common#1043](https://github.com/projectbluefin/common/issues/1043))
   applies.

This is an **operating rule for the backlog-review skill first, not CI**: no
workflow gates a human reviewer. If the org later wants enforcement, the
mechanism belongs in the reusable lifecycle automation in
`projectbluefin/actions` (queue-feed ordering and/or an aging report), not in
this repository — `common` documents the contract and consumes the automation.

## Relationship to the seven-label contract

No new labels. The SLA uses only the existing `1-triage` label plus its age;
aging is *metadata*, not workflow state, exactly as priority tiers are review
metadata in the hold-gate rubric proposal. Automation that eventually surfaces
over-SLA issues would read age from the label timestamp — it must not introduce
an eighth label or comment-based state machine
([label-workflow](../skills/label-workflow.md)).

## Operating metrics

Draft measures, with baselines from the snapshots above:

- Human-authored `1-triage` issues older than SLA — baseline: 50 (2026-08-31);
  target: 0, and staying at 0 week over week.
- Median age to first human response on human-authored issues — baseline:
  unmeasured; establish with the first digest.
- Aged-90+ count — baseline: 17 (2026-08-31), 21 (2026-09-05); target: 0.
- Hold-gated agent PRs (supply side, tracked in
  [reviewer-ladder.md](reviewer-ladder.md)) — baseline: 88 (2026-09-05);
  ROADMAP target: <40.

## What this document deliberately does not do

- No workflow/CI changes; no changes to the seven-label contract.
- No new GitHub labels, projects, or automation in this repository.
- No changes to agent intake: bot-filed issues keep their lanes.
- No change to hold-gate enforcement or merge protection (maintainer decision).

## Related

- [common#1067](https://github.com/projectbluefin/common/issues/1067) —
  user-issue triage starvation finding (this doc's tracker)
- [reviewer-ladder.md](reviewer-ladder.md) — reviewer-scaling rung
  ([common#1029](https://github.com/projectbluefin/common/issues/1029)); the
  supply side of the same constraint
- [common#1043](https://github.com/projectbluefin/common/issues/1043) —
  hold-gate PR queue prioritization rubric (agent-lane ordering)
- [common#1073](https://github.com/projectbluefin/common/pull/1073) — org-wide
  ROADMAP.md proposal; placed "triage SLA" in Phase 0
- [common#1078](https://github.com/projectbluefin/common/issues/1078) —
  release cadence breakdown (downstream symptom)
