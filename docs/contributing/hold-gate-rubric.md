# Hold-Gate PR Prioritization Rubric — Contribution Strategy (Planning Draft)

> **Status**: hold-gated planning artifact. Human review required before adoption.
> Filed by the strategist agent. Tracks [common#1043](https://github.com/projectbluefin/common/issues/1043);
> Incorporates the release-gate expedite policy consolidated from [common#1082](https://github.com/projectbluefin/common/issues/1082);
> Aligned with Phase 0 of the org-wide roadmap ([common#1073](https://github.com/projectbluefin/common/pull/1073)).
>
> Nothing below changes GitHub roles, branch protection, CODEOWNERS, workflow behavior,
> or hold-gate enforcement until a maintainer adopts it.

## Problem

Human review capacity is the primary binding constraint across the factory. Autonomous agent lanes continuously produce findings and PRs, but review capacity drains the queue at a slower rate, causing hold-gated pull requests to accumulate and compete flatly for human attention.

Observed queue dynamics from multi-cycle snapshots (2026-08-27 through 2026-09-05):

- **Rapid accumulation**: Open hold-gated PRs grew from 33 (2026-08-27) → 61 (2026-08-29) → 74 (2026-08-29 kick) → peak of 95 (2026-08-31), with a median age of 10 days and the oldest standing at 69 days (`dakota#962`).
- **Flat competition**: Critical security fixes (e.g. `server#37` k3s kubeconfig 0600 permissions, `dakota-iso#142` cosign verification, `server#36` OTA signatures) sit unordered beside non-urgent test additions (e.g. `fsdk-containers#209`) and formatting tweaks.
- **Release-gate starvation ([common#1082](https://github.com/projectbluefin/common/issues/1082))**: Capacity freed during queue contractions has historically flowed to easy test/refactor PRs rather than release-blocking changes. Approved release promotions (e.g. `bluefin#1115` `ci(promote)`) carrying `release/ready` sat unmerged for 17+ days, contributing to downstream freeze states (Bluefin stable frozen 47 days, Bluefin-LTS 29 days, Common missing monthly release tag `v2026.09`).
- **Test coverage volume (~40% of queue)**: Queue analysis revealed that ~40% of open hold-gated PRs consist of BATS or unit test coverage. Evaluating each test PR as a bespoke high-friction decision stalls the queue; establishing a clear, standardized acceptance bar converts dozens of individual decisions into rapid standard approvals.
- **Silent obsolescence ([common#1054](https://github.com/projectbluefin/common/issues/1054))**: Without queue triage, hold-gated agent PRs sit for weeks and get silently superseded by human fixes merged directly to `main` (e.g. `common#1010` vs `common#1020`/`#1030`), wasting reviewer time on dead work.
- **Multi-repo diffusion**: The hold-gated queue spans 12 repositories and 4 product lines. No individual repository maintainer sees the full shape, so ordering cannot emerge ad-hoc per repo.

Complementary to the reviewer-scaling ladder ([common#1029](https://github.com/projectbluefin/common/issues/1029), [reviewer-ladder.md](reviewer-ladder.md)), which expands reviewer supply, this rubric addresses **review ordering**: ensuring that existing human review capacity is directed to the highest-risk and highest-impact pull requests first.

## Proposal: Three-Tier Prioritization Rubric

Hold-gated PRs are ordered into three priority tiers based on risk, blast radius, and unblocking impact:

```
┌────────────────────────────────────────────────────────────────────────┐
│  Tier P0 — Security, Supply Chain & Core Integrity                    │
│  • Permissions, secrets, polkit hardening, CVE fixes                  │
│  • Cosign / OTA signature verification, SHA-pinning regressions       │
│  • Org-wide blast radius: system_files/shared/**, root Containerfile   │
├────────────────────────────────────────────────────────────────────────┤
│  Tier P1 — Release Gates, Defect Fixes & Architectural Blockers        │
│  • Release-Gate Expedite Lane: approved release/ready PRs (<48h)       │
│  • User-facing defects, boot/hardware regressions, broken scanners    │
│  • SSOT / architectural refactors unblocking dependent clusters       │
├────────────────────────────────────────────────────────────────────────┤
│  Tier P2 — Tests, Documentation & Non-Breaking Refactors               │
│  • BATS and pytest coverage additions (~40% of queue volume)          │
│  • Documentation and skill updates (leverage doc-only push exception) │
│  • Routine refactors, formatting, and lint cleanliness                 │
└────────────────────────────────────────────────────────────────────────┘
```

---

### Tier P0: Security, Supply Chain & Core Integrity (Critical)

**Definition**: Vulnerabilities, security policy regressions, cryptographic verification, or defects with org-wide blast radius.

- **Examples**:
  - Permissions fixes on sensitive configs (`k3s` kubeconfig 0600, polkit rule hardening, sudo policy).
  - Supply-chain verification: cosign image signature verification, OTA signature checks, immutable SHA pinning in CI/Containerfiles.
  - Critical fixes in `system_files/shared/` or base image definitions that affect all variants (`bluefin`, `bluefin-lts`, `dakota`).
- **Review Precedence**: **Immediate**. P0 items take absolute priority in review sweeps.
- **Target SLA**: First maintainer review within **24–48 hours**.

---

### Tier P1: Release Gates, Defect Fixes & Architectural Blockers (High)

**Definition**: PRs that directly unblock releases, resolve active defects, or clear architectural dependencies blocking multiple downstream PRs.

- **Release-Gate Expedite Lane (consolidated from [common#1082](https://github.com/projectbluefin/common/issues/1082))**:
  - Any PR carrying the `release/ready` label or automated promotion PR (`ci(promote)`) that has received approval **jumps the hold-gate queue**.
  - Reviewers and maintainers must merge or explicitly disposition expedited PRs within **48 hours** to prevent downstream distribution freezes.
- **User-Facing Defects & Regressions**:
  - Scanner fixes for crash loops, broken user tooling (`ujust`, `bonedigger-report`), and hardware quirks (audio/video device matching, GPU initialization).
- **Single Source of Truth (SSOT) Blockers**:
  - Architectural PRs (e.g. `common#1045`, `bluefin#1148`) that establish canonical definitions and unblock clusters of waiting PRs.
- **Review Precedence**: Reviewed immediately after P0 queue is clear.
- **Target SLA**: Maintainer review within **3–5 days** (Expedite Lane: **48 hours**).

---

### Tier P2: Tests, Documentation & Non-Breaking Refactors (Standard / Batch)

**Definition**: Changes that add test coverage, enhance documentation, or clean up code without altering core functional behavior.

- **Scope**:
  - BATS and unit test coverage (which represents ~40% of the backlog).
  - Documentation and skill updates (note: pure doc changes to `docs/**` or `AGENTS.md` should use the doc-only push exception where applicable, avoiding PR review overhead).
  - Code hygiene, variable cleanup, and non-blocking refactors.
- **Standardized Acceptance Bar for Test PRs**:
  - To clear the ~40% test backlog efficiently without imposing bespoke review friction, test PRs that:
    1. Pass all automated CI checks (`Validate PR`, `Build`, `Unit Tests`, `PR E2E`),
    2. Contain only additions under `tests/**` following standard BATS/pytest conventions, and
    3. Do not modify production scripts or system files,
  - are reviewed via batch sweeps using the "easy-wins mode" (`additions + deletions` ascending) defined in [`docs/skills/pr-review/SKILL.md`](../skills/pr-review/SKILL.md).
- **Review Precedence**: Processed in scheduled batch sweeps once P0 and P1 queues are drained.
- **Target SLA**: Processed during weekly backlog sweeps.

---

## Queue Mechanics and Factory Integration

### Compliance with the Seven-Label Contract

The Project Bluefin factory operates strictly on seven canonical labels ([`docs/skills/label-workflow.md`](../skills/label-workflow.md)):
`1-triage`, `2-discussing`, `3-human-queue`, `3-clanker-queue`, `4-review`, `blocked`, and `hold`.

1. **No New Workflow State Labels**: Priority tiers (`P0`, `P1`, `P2`) are **review metadata and sorting signals**, NOT workflow states. They do not replace or alter `4-review` or the `hold` overlay.
2. **Metadata Signaling**:
   - Agent lanes and contributors indicate priority tier in the PR description under a dedicated `## Priority: P0 | P1 | P2` heading, accompanied by evidence.
   - Commit messages and trailers may include `Hive-Priority: P0 | P1 | P2`.
   - If repository automation surfaces sorting tags (such as `hold-p0`, `hold-p1`, `hold-p2`), these act exclusively as informational reviewer filters, never as workflow state machines.

### Preflight Obsolescence Check ([common#1054](https://github.com/projectbluefin/common/issues/1054))

Before reviewing an aged hold-gated PR:

1. **Check against `main`**: Inspect `git log` on `main` for the PR's claimed files and functions since the PR creation date.
2. **Detect collisions**: If a merged PR (human or agent) already landed equivalent functionality (e.g. `common#1010` superseded by `#1020` and `#1030`), close the stale PR with a comment pointing to the merged commit.
3. **Prevent queue inflation**: Do not burn reviewer cycles reviewing superseded diffs.

---

## Operating Metrics and Targets

In coordination with Phase 0 of the org-wide roadmap ([common#1073](https://github.com/projectbluefin/common/pull/1073)):

| Metric | Measured Baseline (Sept 2026) | Target |
|---|---|---|
| Open hold-gated PR inventory | 88–95 PRs | < 40 and declining |
| Median hold-gated PR age | 10 days (oldest 69d) | < 7 days |
| Tier P0 review latency | Unordered (up to 20d) | < 48 hours |
| Release-gate expedite turnaround | 17 days (`bluefin#1115`) | < 48 hours from approval |
| Stale / superseded PR latency | Open indefinitely | Closed within 7 days of collision |

---

## What this document deliberately does not do

- **Does not modify branch protection or CODEOWNERS**: Maintainers retain exclusive merge authority.
- **Does not bypass human review**: Hold-gated PRs still require human approval before merge.
- **Does not invent custom workflow states**: Preserves the 7-label contract of `label-workflow.md`.
- **Does not alter automated merge mechanics**: Auto-merge rules and merge queue behavior remain under `hive-automerge.md` and repository rulesets.

---

## Related

- [common#1043](https://github.com/projectbluefin/common/issues/1043) — Hold-gated PR queue prioritization rubric (this document's tracker)
- [common#1082](https://github.com/projectbluefin/common/issues/1082) — Release-gate expedite lane (consolidated into #1043)
- [common#1029](https://github.com/projectbluefin/common/issues/1029) / [common#1080](https://github.com/projectbluefin/common/pull/1080) — Reviewer-scaling ladder proposal ([reviewer-ladder.md](reviewer-ladder.md))
- [common#1028](https://github.com/projectbluefin/common/issues/1028) — Release-gate posture across product lines
- [common#1054](https://github.com/projectbluefin/common/issues/1054) — Stale hold-gated PR obsolescence detection
- [common#1058](https://github.com/projectbluefin/common/issues/1058) — Reviewer coverage map / repo concentration data
- [common#1073](https://github.com/projectbluefin/common/pull/1073) — Org-wide roadmap (Phase 0 parent)
- [docs/skills/pr-review/SKILL.md](../skills/pr-review/SKILL.md) — Backlog review procedure
- [docs/skills/label-workflow.md](../skills/label-workflow.md) — Factory seven-label contract
