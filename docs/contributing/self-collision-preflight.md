# Self-Collision Preflight — Contribution Strategy (Planning Draft)

> **Status**: hold-gated planning artifact. Human review required before adoption.
> Filed by the strategist agent. Tracks [common#1060](https://github.com/projectbluefin/common/issues/1060);
> pairs with the hold-gate prioritization rubric
> ([common#1043](https://github.com/projectbluefin/common/issues/1043),
> [`hold-gate-rubric.md`](hold-gate-rubric.md)) and the demand-side throttle
> ([common#1052](https://github.com/projectbluefin/common/issues/1052),
> [`agent-lane-throttle.md`](agent-lane-throttle.md)).
>
> Nothing below changes agent filing behavior, workflow behavior, or hold-gate
> enforcement until a maintainer adopts it. It proposes one preflight step an
> agent evaluates at developer time; it adds no CI check, no label, and no
> automation.

## Vocabulary

- **Agent lane** — as defined in
  [`agent-lane-throttle.md`](agent-lane-throttle.md#vocabulary): a class of agent
  work identified by who files it and what it produces, not by a workflow label.
- **Self-collision** — two open PRs from the *same* lane whose file clusters
  intersect. Distinct from a cross-lane competing pair, where two different lanes
  file against the same ground.
- **File cluster** — the set of paths a PR changes, read from the PR itself:
  `gh pr view <N> --json files`.

## Problem

The hold-gated protocol lists open PRs at kick time precisely so a lane can prove
its new filing is disjoint from work already in flight. Within one lane that
check failed: the quality lane opened duplicate PRs covering identical clusters
while its own earlier PR sat in the hold queue.

| Earlier PR | Duplicate PR | Shared cluster | Gap |
|---|---|---|---|
| finpilot#285 (2026-08-27) | finpilot#303 (2026-08-30) | `build/clean-stage.sh` + `build/copr-helpers.sh` BATS tests, both touch `Justfile` | 3 days |
| finpilot#296 (2026-08-30 07:48Z) | finpilot#299 (2026-08-30 09:52Z) | `Justfile` `tag-images` recipe BATS coverage | 2 hours |

Each pair cost four review slots for two pieces of work. A lane that re-claims
ground it already holds makes queue depth overstate real work-in-flight, and
forces a reviewer to adjudicate which duplicate to keep — a comparison the lane
had the evidence to make at kick time and the reviewer does not.

### What the queue has already absorbed

All four PRs are resolved as of 2026-09-23, so the named collisions are no
longer open work:

| PR | Outcome |
|---|---|
| finpilot#285 | merged 2026-09-04 |
| finpilot#296 | merged 2026-09-05 |
| finpilot#299 | merged 2026-09-06 |
| finpilot#303 | closed 2026-09-06 without merge |

The queue did adjudicate them — at the cost this proposal exists to avoid, not
through any rule that prevented the second filing.

### Re-audit: the naive rule would catch the wrong thing

[common#1060](https://github.com/projectbluefin/common/issues/1060) proposes
"a lane may not open a PR whose file cluster intersects its own open hold-gated
PRs." Re-auditing every open app-authored PR across the ten repositories tracked
in [common#1058](https://github.com/projectbluefin/common/issues/1058) on
2026-09-23 (**31 open app-authored PRs**) found **no confirmed intra-lane
duplicate cluster**. Every file-cluster intersection that exists is legitimate
work that a hard prohibition would have blocked:

| Intersecting pair | Same lane? | Why it is not a duplicate |
|---|---|---|
| bluefin#1227 / bluefin#1310 | `app/mergeraptor` | Distinct dependency digest bumps (`projectbluefin/common:latest` vs `ublue-os/brew:latest`) that share `image-versions.yml` |
| server#238 / server#239 | `app/mergeraptor` | Distinct dependency digest bumps (`projectbluefin/actions` vs `taiki-e/install-action`) that share `.github/workflows/build.yml` |
| dakota-iso#142 / dakota-iso#146 | `app/hivecommons-hive` | A cosign-verification security fix and a host-side config SSOT refactor that both touch `justfile` |
| common#1186 / common#1187 | human (`repires`) | Two human PRs closing different issues (#1161, #1160) that both touch `Justfile` and `.github/workflows/unit-tests.yml` |

The discriminator in the real finpilot duplicates was not the shared file — it
was the shared *intent and closing issue*. This matches the rule the factory
already applies at review time: the same file is not the same work, and a
competing pair is a candidate for resolution only after the actual hunks are
compared
([`common-rationalizations.md`](../skills/pr-review/references/common-rationalizations.md),
[`duplicate-cluster.md`](../skills/pr-review/references/duplicate-cluster.md)).

A prohibition keyed on file intersection alone would therefore have blocked four
legitimate filings while catching zero of the two real duplicates. The gap is
not the absence of a prohibition — it is the absence of a *required, evidenced
comparison* before the second PR is opened.

## Proposal: one preflight step

Before opening a PR, a lane must intersect the files it intends to change
against the open PRs it already holds on the target repository, and record the
result.

**1. List this lane's own open PRs with their file clusters.**

```bash
gh pr list --repo projectbluefin/<repo> --state open --author <lane-identity> \
  --json number,title,files \
  --jq '.[] | "\(.number)\t\(.title)\t\([.files[].path] | join(","))"'
```

**2. Intersect** that output against the paths in the new change.

**3. On intersection, compare the hunks and the closing-issue sets** — not the
titles, and not the shared path. `gh pr diff <N>` works for fork heads.

- **Same work already open** → comment on that PR. Do not open a second one.
- **Different work, overlapping files** → name the other PR and the shared path
  in the new PR body, so the reviewer can order the two instead of discovering
  the overlap mid-sweep.

**4. Record the result in the new PR body** — either the explicit "no overlap
with this lane's open PRs" statement or the named overlap from step 3. An
unrecorded check is indistinguishable from a skipped one.

This is deliberately a *disclosure* rule, not a prohibition. It leaves the
"is this the same work?" judgment with the lane, which is where the evidence is,
and it makes that judgment visible to the reviewer rather than silently
duplicated.

## Compliance with the seven-label contract

The preflight is a **filing-time convention, not a workflow state**:

- It adds no label, removes no label, and changes no transition in
  [`label-workflow.md`](../skills/label-workflow.md).
- It introduces no new overlay and no new queue.
- It is evaluated by the agent at the moment it decides whether to open a PR —
  the same class as the attribution trailers in
  [`agentic-model.md`](../factory/agentic-model.md) — not by a CI check. Per that
  same contract, a process convention must not become a bespoke blocking CI job.

## Operating metrics

Draft measures, to be baselined at adoption:

- **Self-collision pairs opened per week** — baseline: 2 pairs in 3 days
  (finpilot, 2026-08-27 → 2026-08-30); 0 confirmed org-wide on 2026-09-23.
- **Review slots spent adjudicating self-collisions** — baseline: 4 slots for 2
  work items in the finpilot pairs. Target 0.
- **Preflight disclosure rate** — share of new agent PRs whose body records the
  intersection result. A rule that is never recorded is not being run.

## What this document deliberately does not do

- No closure, relabelling, or reverting of any currently open PR. The four
  finpilot PRs were dispositioned by review; nothing here reopens that.
- No change to the hard rules in
  [`agentic-model.md`](../factory/agentic-model.md), and no change to any lane's
  runtime behavior, until a maintainer adopts it.
- No new script, workflow, CI gate, or label.
- No duplication of the review-time resolution procedure — that stays
  [`duplicate-cluster.md`](../skills/pr-review/references/duplicate-cluster.md),
  which remains human-gated.

## Related

- [common#1060](https://github.com/projectbluefin/common/issues/1060) — self-collision finding (this doc's tracker)
- [common#1043](https://github.com/projectbluefin/common/issues/1043) — hold-gate prioritization rubric ([`hold-gate-rubric.md`](hold-gate-rubric.md))
- [common#1052](https://github.com/projectbluefin/common/issues/1052) — agent-lane output throttle ([`agent-lane-throttle.md`](agent-lane-throttle.md))
- [common#1054](https://github.com/projectbluefin/common/issues/1054) — obsolescence detection for superseded hold-gated PRs
- [common#1058](https://github.com/projectbluefin/common/issues/1058) — reviewer coverage map / repo-concentration data
- [`duplicate-cluster.md`](../skills/pr-review/references/duplicate-cluster.md) — review-time resolution procedure
- [`common-rationalizations.md`](../skills/pr-review/references/common-rationalizations.md) — why a shared file is not proof of duplication
