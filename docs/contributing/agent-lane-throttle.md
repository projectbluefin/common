# Agent-Lane Output Throttle — Contribution Strategy (Planning Draft)

> **Status**: hold-gated planning artifact. Human review required before adoption.
> Filed by the strategist agent. Tracks [common#1052](https://github.com/projectbluefin/common/issues/1052);
> pairs with the prioritization rubric in [common#1043](https://github.com/projectbluefin/common/issues/1043).
>
> Nothing below changes GitHub roles, branch protection, CODEOWNERS, workflow behavior,
> label semantics, or hold-gate enforcement until a maintainer adopts it. It is written
> down for maintainer review rather than applied autonomously.

## Vocabulary

Two terms are used below and are defined here because neither appears in the
existing factory docs on their own:

- **Agent lane** — a class of agent work defined by who files it and what it
  produces, not by a workflow label. The lanes observed in the hold-gated queue
  are **sec-check** (security and supply-chain fixes), **ci-maintainer**
  (workflow and release-gate repairs), **quality** (test coverage), **scanner**
  (dependency and drift updates), and **strategist** (planning artifacts such as
  this file).
- **Demand-side throttle** — a rule that limits how much *new* work a lane may
  file while a review queue is above a threshold. It constrains filings, not
  merges. Nothing already open is closed, relabelled, or reverted.

## Problem

The review bottleneck has three levers. Supply is reviewer coverage
([common#1029](https://github.com/projectbluefin/common/issues/1029), drafted in
[`reviewer-ladder.md`](reviewer-ladder.md)). Ordering is which PR a reviewer
picks up first ([common#1043](https://github.com/projectbluefin/common/issues/1043),
drafted in [common#1188](https://github.com/projectbluefin/common/pull/1188)).
Neither addresses **demand**: how much unreviewed work the factory is allowed to
add to the queue in the first place.

Every open hold-gated PR is a standing cost against a fixed reviewer budget.
When the filing rate exceeds the review rate, the queue grows monotonically no
matter how the existing items are ordered. Queue depth is therefore not only a
symptom of the bottleneck — it is the mechanism.

Reported state, using the snapshots on
[common#1052](https://github.com/projectbluefin/common/issues/1052) and
[common#1058](https://github.com/projectbluefin/common/issues/1058):

- **85 open hold-gated PRs**, up from 33 in the preceding 48 hours and 74 less
  than 24 hours later — a filing rate with no matching review rate.
  ([common#1052](https://github.com/projectbluefin/common/issues/1052),
  2026-08-30 snapshot.)
- Concentration per repo at that snapshot: common 18, server 12, finpilot 9,
  dakota-iso 9, bluefin-lts 8, bluefin 7, testsuite 7, actions 6, dakota 5,
  fsdk-containers 4.
- **Redundant filings inside one repo.** server held four overlapping PXE
  installer PRs (#22, #25, #26, #27) at that snapshot, all filed 2026-08-21
  through 2026-08-27 and all competing for the same single reviewer. All four
  have since been closed without a fix landing. This is the demand-side failure
  in miniature: the queue is deep because multiple lanes filed against a repo
  whose review capacity had already been consumed.
- The downstream consequence is measured elsewhere: bluefin stable frozen 46
  days as of 2026-09-04, bluefin-lts 28 days stale, common missing its
  v2026.09 monthly tag ([common#1078](https://github.com/projectbluefin/common/issues/1078)).

A throttle does not clear the backlog. It stops the backlog from growing while
the supply and ordering fixes land, which is what makes those fixes measurable.

### The burst is the failure mode, not the steady state

The 2026-08-30 snapshot is a spike, and it is worth being precise about that,
because it changes what this proposal is for. Measured on 2026-09-23 the same
queue holds **32 open agent-filed PRs across 14 repos, with no repo above 6** —
below both proposed thresholds. The trajectory is:

| Date | Org-wide open agent PRs | Note |
|---|---|---|
| 2026-08-28 (approx.) | 33 | before the burst |
| 2026-08-29, +48h | 61 | +52 net in 48 hours |
| 2026-08-30 | 74 → 85 | +13 in under 24 hours |
| 2026-09-23 | 32 | drained; max 6 in any one repo |

The drain was not a throttle — none exists — it was review and merge. **121
hive-authored PRs were merged across the org in the week from 2026-09-16**, so
the merge side does clear a queue once reviewers have the capacity to work it.
What it did not do is prevent the queue from tripling in 48 hours in the first
place.

That is the argument for this proposal, stated narrowly: the review bottleneck
is not a constant backlog that a filing gate would slowly starve, it is an
intermittent burst that a filing gate can cap at the moment it starts. A
threshold-triggered, self-lifting throttle is dormant through the 2026-09-23
state and only binds during a repeat of the 2026-08-28 episode. It is burst
control, not a permanent ration.

## Proposal: a per-repo filing gate

When a repository's open hold-gated PR count is at or above a threshold, that
repository stops accepting **new filings from non-P0 lanes** until the queue
drains below it.

### Thresholds (proposed, not current policy)

| Scope | Threshold | Effect when met |
|---|---|---|
| Per repo | 8 open hold-gated PRs | Non-P0 lanes stand down for that repo |
| Org-wide | 60 open hold-gated PRs | Non-P0 lanes stand down everywhere |

Both numbers are proposals, not current policy, and both are deliberately
conservative: they sit well below the 2026-08-30 peak (85 org-wide, 9 repos at
or above 8) and below the ROADMAP target of <40, so the gate releases before the
target is reached rather than becoming a permanent ration. A maintainer tuning
these numbers changes one table.

At the 2026-09-23 snapshot the gate would be **dormant**: 32 open agent-filed
PRs across 14 repos, none above 6. That is the intended resting state — the
throttle exists for the burst, not for the baseline.

### Which lanes stand down

- **Non-P0 lanes that stand down:** quality (coverage), scanner (dependency and
  drift updates that are not security-relevant), and any refactor or
  documentation lane — including this strategist lane.
- **Lanes that may still file:** sec-check, and ci-maintainer work that repairs
  a release gate. A broken release gate is not competing with review capacity;
  it is the thing consuming it.
- **Exempt entirely:** human-filed PRs. This throttle governs agent filing only.
  The factory's stated problem is agent output crowding out human review, so
  constraining humans would invert the intent.

### Optional per-lane WIP caps (stricter, additive)

The 2026-08-30 comment on
[common#1052](https://github.com/projectbluefin/common/issues/1052) recommended
per-lane caps as a stricter alternative to a repo-wide gate: **scanner ≤5** and
**quality ≤8** open PRs per repo, in force until the org-wide queue drains below
40. These are compatible with the gate above — a lane cap binds even when the
repo is under threshold, and the repo gate binds even when a lane is under its
cap. A maintainer may adopt either, both, or neither.

### Reversibility

The throttle is self-clearing by construction:

- It is a function of queue depth, not a schedule. There is nothing to turn off
  manually and no expiry date to forget.
- It never closes, relabels, reverts, or deprioritizes an open PR. Queue depth
  falls only through review, merge, or human close — the actions the bottleneck
  is actually about.
- Standing down delays a filing; it does not cancel the work. A lane that stands
  down re-files once the repo drops below threshold, and the issue it would have
  filed is unchanged in the meantime.

## Pairing with the P0/P1/P2 rubric

The gate is only mechanical if "P0" is mechanical. The rubric proposed in
[common#1043](https://github.com/projectbluefin/common/issues/1043) supplies
exactly that vocabulary, and this document does not redefine it:

- A filing is **P0** — and therefore permitted while the throttle is active —
  when it is a security, supply-chain, or core-integrity fix. That is the
  rubric's own P0 tier.
- Everything the rubric places in **P1** and **P2** stands down while the
  throttle is active. P1 defects are delayed by this proposal, which is a real
  cost and the reason the thresholds are set to release early.

The two drafts are independent: either can be adopted without the other.
Adopting the rubric alone orders the queue but does not bound its growth;
adopting the throttle alone gates filings on a P0 definition that lives in the
rubric. Together they are the demand-side half of the review-bottleneck
response.

### Compliance with the seven-label contract

The throttle is a **filing gate, not a workflow state**. It adds no label,
removes no label, and changes no transition:

- It does not alter `1-triage`, `2-discussing`, `3-human-queue`,
  `3-clanker-queue`, `4-review`, `blocked`, or `hold`.
- It does not create a new overlay. The rubric's proposed `hold-p0` / `hold-p1`
  / `hold-p2` labels are reviewer filters there; this document does not propose
  labels of its own and does not depend on those existing.
- It is enforced at the moment an agent decides whether to open a PR — a
  developer-time convention evaluated by the agent, in the same class as the
  attribution trailers in
  [`agentic-model.md`](../factory/agentic-model.md), not a CI check. Per the
  same contract, a process convention must not become a bespoke blocking CI job.

## Operating metrics

Draft measures, to be baselined at adoption:

- **Open hold-gated PR count, org-wide** — baseline 85 on 2026-08-30; gate
  releases below 60; ROADMAP target <40 and shrinking.
- **Repos at or above threshold** — baseline 9 of 10 on 2026-08-30; target 0.
- **Filing rate vs. review rate** — the ratio this proposal exists to invert.
  Baseline: +52 net in 48 hours, then +13 in under 24 hours.
- **Stand-down events and their duration** — how often the throttle binds and
  how long each episode lasts. A throttle that is never active is either
  mistuned or unnecessary; one that never releases means the thresholds are
  wrong, not that the lanes should be silenced.
- **P1 delay** — median age at merge for P1 filings, before and after. This is
  the proposal's principal cost and should be tracked as one.

## What this document deliberately does not do

- No workflow, CI, or label changes — it proposes no new check, no new label,
  and no automation.
- No changes to merge protection, branch protection, or CODEOWNERS.
- No threshold enforcement mechanism. This draft states the rule; wiring it into
  any agent runtime or queue tool is a separate, maintainer-owned decision.
- No closure, relabelling, or reverting of any currently open PR.
- No reviewer-ladder or prioritization-rubric content — those are
  [`reviewer-ladder.md`](reviewer-ladder.md) and
  [common#1043](https://github.com/projectbluefin/common/issues/1043)
  ([draft PR](https://github.com/projectbluefin/common/pull/1188)).

## Related

- [common#1052](https://github.com/projectbluefin/common/issues/1052) — agent-lane output throttle finding (this doc's tracker)
- [common#1043](https://github.com/projectbluefin/common/issues/1043) — hold-gate prioritization rubric (supplies the P0/P1/P2 tiers)
- [common#1029](https://github.com/projectbluefin/common/issues/1029) — reviewer-scaling rung (supply-side counterpart)
- [common#1058](https://github.com/projectbluefin/common/issues/1058) — reviewer coverage map / repo-concentration data
- [`reviewer-ladder.md`](reviewer-ladder.md) — draft four-rung contributor ladder proposal
- [common#1078](https://github.com/projectbluefin/common/issues/1078) — release cadence breakdown (downstream symptom)
