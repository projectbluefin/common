# projectbluefin Organization Roadmap

**Status**: Planning artifact — hold-gated, pending human review and maintainer sign-off.
**Last updated**: 2026-09-02
**Scope**: All 11 repos across 4 product lines (bluefin, bluefin-lts, dakota, server) plus shared infrastructure (common, actions, testsuite, fsdk-containers, finpilot, dakota-iso, bootc-installer).

This document consolidates recurring strategic findings filed by the strategist agent into a single org-wide roadmap. It is the successor to the closed attempt in common#958, narrowed to actionable phases.

## Where we are (2026-09-02 snapshot)

- ~95 hold-gated agent PRs open across 11 repos; linear growth ~+15/day with near-zero review throughput.
- Release cadence is healthy (dakota stable ships daily; bluefin stable every ~12 days), but gate posture diverges per product line (common#1028).
- 50+ human-filed issues sit in triage; oldest aged >90 days (common#1067).
- Security fixes are landing piecemeal: 9+ sec-check PRs patching permissions/SHA-pinning repo by repo (common#1036).

## Phase 0 — Unblock the review pipeline (0–30 days)

The dominant strategic risk is not any single defect; it is that review throughput is the org bottleneck and agent lanes compound it.

1. **Adopt a hold-gate prioritization rubric** (common#1043): label PRs by risk/review-cost so scarce reviewer time goes to security and release-gate fixes first.
2. **Throttle agent output to reviewer capacity** (common#1052): cap new agent PRs per repo per day until the queue drains below a defined level.
3. **Add a reviewer-scaling rung to the contributor ladder** (common#1029): triage and review are the scalable entry points; recruit explicitly for them.
4. **Fix triage starvation** (common#1067): weekly triage sweep SLA for human-filed issues before agent work enters the queue.
5. **Obsolescence detection for superseded agent PRs** (common#1054): auto-close hold-gated PRs whose target code has already been fixed by a merged human PR.

## Phase 1 — Consolidate before scaling (30–90 days)

Agent lanes are independently re-solving the same problems in per-repo silos.

1. **Org-wide GitHub Actions security baseline** (common#1036): one reusable policy (top-level `permissions: {}`, SHA-pinned actions, pull_request_target restrictions) enforced from `actions/` instead of 9+ piecemeal fixes.
2. **Canonical image-identity/variant schema** (common#1056): 9 repos are "single-sourcing" image-name → metadata mapping independently; define one schema in common and converge.
3. **Shared tooling consolidation** (common#1040): diverged `generate_skill_index.py` copies and per-repo test scaffolding should live in `actions/scripts`.
4. **Release-gate posture policy** (common#1028): define org-wide stall/override rules so chronically red pipelines stop normalizing gate-skipped releases (see gate erosion, common#1057).
5. **Repo lifecycle/portfolio policy** (common#1041): criteria for active/maintenance/archived states; bootc-installer (30/30 red nightly runs, stale README URLs) is the test case.
6. **De-duplicate agent lanes** (common#1060, common#1033): duplicate hold-gated PRs for identical clusters (finpilot #285/#303, #296/#299; server PXE #22/#25/#26/#27) waste the scarcest resource — review time.

## Phase 2 — Product-defining decisions (90–180 days)

These are roadmap choices that shape what the project *is*, currently implicit or stalled:

1. **systemd-homed by default** (dakota#962, common#1050): 70 days in review with no design record. Decide explicitly — this is a user-facing identity model decision, not an implementation detail.
2. **Org-wide NVIDIA support policy** (common#1051): bluefin-lts intentionally diverges from upstream `nvidia-install.sh`; document whether divergence is policy or debt, and which variants carry NVIDIA support commitments.
3. **Dakota adoption blockers** (common#1037): 64 SLA-violating first-boot/login issues while stable ships daily. Decide the quality bar for calling dakota ready for general adoption.
4. **Quality-lane CI integration** (common#1046): orphaned and red test artifacts across 4 repos erode suite trust; coverage work only pays off if it runs in CI.

## Success metrics

| Metric | Current (2026-09-02) | Target (Phase 0 end) |
|---|---|---|
| Open hold-gated PRs | ~95 | < 40 and shrinking |
| Human issues in triage > 30d | 50+ | 0 |
| Sec baseline coverage | piecemeal (9+ one-off PRs) | enforced org-wide from actions/ |
| Image-identity schemas | 9 divergent | 1 canonical + converging repos |

## Related tracking issues

- common#1028, #1029, #1033, #1036, #1037, #1040, #1041, #1043, #1046, #1050, #1051, #1052, #1054, #1056, #1057, #1060, #1067
