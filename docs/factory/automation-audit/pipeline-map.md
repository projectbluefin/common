# Automation Audit — Pipeline Map

> Generated: 2026-06-09 | Scope: projectbluefin org (common, bluefin, bluefin-lts, dakota, actions, testsuite, iso)

## End-to-End Publishing Pipeline

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     PROJECT BLUEFIN PUBLISH PIPELINE                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  SOURCE TRIGGER                                                              │
│  ├── PR merge to testing branch (Renovate, feature PRs)                     │
│  ├── Push to main (common layer only)                                       │
│  └── Scheduled cron (daily promotion, monthly release)                      │
│                                                                              │
│  BUILD PHASE                                                                 │
│  ├── [AUTO] reusable-build.yml (actions) — multi-arch OCI build             │
│  ├── [AUTO] buildah-build + zstd:chunked compression                        │
│  ├── [AUTO] Trivy CVE scan (CRITICAL threshold)                             │
│  ├── [AUTO] push to ghcr.io/projectbluefin/<image>:testing                  │
│  └── [AUTO] cosign sign (key-based — gap: should be keyless)                │
│                                                                              │
│  TEST PHASE                                                                  │
│  ├── [AUTO] PR-level smoke (pr-smoke.yml / pr-e2e.yml)                      │
│  ├── [AUTO] Post-merge E2E (smoke,common suites)                            │
│  ├── [❌ MISSING] Installability gate (#423)                                │
│  ├── [❌ DISABLED] Dakota E2E (#497 — build machine broken)                 │
│  └── [AUTO] Promotion-candidate E2E (weekly, common repo)                   │
│                                                                              │
│  GATE PHASE                                                                  │
│  ├── [AUTO] promote-testing-to-main.yml creates squash PR                   │
│  ├── [AUTO] reusable-release-gate.yml checks (cosign, E2E, freshness)       │
│  ├── [👤 HUMAN] 2 maintainer reviews required (branch protection)           │
│  ├── [AUTO] Merge queue enqueue (when checks pass)                          │
│  └── [AUTO] Merge queue merges to main                                      │
│                                                                              │
│  RELEASE PHASE                                                               │
│  ├── [AUTO] execute-release.yml fires on merged promotion PR                │
│  ├── [AUTO] reusable-execute-release.yml (cosign verify → skopeo copy)      │
│  ├── [AUTO] Promotes :testing digest → :stable (bluefin) / :lts (lts)       │
│  ├── [AUTO] reusable-release.yml (SBOM + release card + GitHub Release)     │
│  └── [❌ MISSING] Downstream ISO rebuild trigger                            │
│                                                                              │
│  NOTIFICATION PHASE                                                          │
│  ├── [AUTO] GitHub Release published (triggers watchers)                    │
│  ├── [❌ MISSING] Downstream repo dispatch (iso rebuild)                    │
│  └── [❌ MISSING] Status page / deployment dashboard update                 │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Per-Repo Workflow Inventory

### common (15 workflows)

| Workflow | Trigger | Automation Level | Notes |
|---|---|---|---|
| `build.yml` | push main, PR, merge_group | ✅ Full | Builds+pushes common OCI layer |
| `release.yml` | monthly cron + dispatch | ✅ Full | Monthly GitHub Release |
| `validate.yml` | PR | ✅ Full | Gate: just check, shellcheck, pre-commit |
| `e2e.yml` | push main | ✅ Full | Post-merge composed-image test |
| `pr-e2e.yml` | PR | ✅ Full | Pre-merge composed-image test |
| `promotion-candidate-e2e.yml` | weekly cron | ✅ Full | Weekly promotion readiness check |
| `run-testsuite.yml` | called | ✅ Full | Testsuite SHA pin wrapper |
| `lifecycle-caller.yml` | issue/PR events | ✅ Full | Slash commands, widgets |
| `sync-labels.yml` | push labels.json | ⚠️ Partial | Requires MERGERAPTOR secrets (#511) |
| `sync-codeowners.yml` | push | ✅ Full | CODEOWNERS sync |
| `skill-drift.yml` | PR | ✅ Full | Docs/implementation parity |
| `docs-quality.yml` | PR | ✅ Full | Skill frontmatter validation |
| `backfill-pipeline.yml` | manual | ✅ Full (on-demand) | Widget injection |

### bluefin (26 workflows)

| Workflow | Trigger | Automation Level | Notes |
|---|---|---|---|
| `build-image-testing.yml` | push testing | ✅ Full | Main build pipeline |
| `promote-testing-to-main.yml` | push testing + daily + dispatch | ✅ Full | Creates promotion PR |
| `execute-release.yml` | merged promotion PR | ✅ Full | testing→stable + release notes |
| `post-testing-e2e.yml` | after build | ✅ Full | E2E gate |
| `e2e-dispatch.yml` | manual | ✅ Full | On-demand E2E |
| `pr-release-gate.yml` | PR to main | ✅ Full | Cosign verify gate |
| `pr-smoke.yml` | PR to testing | ✅ Full | Quick smoke test |
| `pr-validation.yml` | PR | ✅ Full | Pre-commit + just check |
| `renovate-automerge.yml` | workflow_run | ✅ Full | Auto-merges non-major deps |
| `nightly.yml` | cron | ✅ Full | Daily freshness |
| `cherry-pick-to-stable.yml` | label trigger | ✅ Full | Hotfix path |
| `cache-maintenance.yml` | schedule | ✅ Full | GHA cache cleanup |
| `clean.yml` | PR close | ✅ Full | PR artifact cleanup |
| `vulnerability-scan.yml` | schedule | ✅ Full | Scheduled Trivy scan |
| `check-cosign-key-rotation.yml` | schedule | ✅ Full | Key health check |
| `copr-health-monitor.yml` | schedule | ✅ Full | COPR repo health |
| `bonedigger.yml` | schedule | ✅ Full | Client reporting |
| `scorecard.yml` | schedule | ✅ Full | OpenSSF score |
| `lifecycle-caller.yml` | issue/PR events | ✅ Full | Issue lifecycle |
| `skill-drift.yml` | PR | ✅ Full | Doc parity |
| `moderator.yml` | issue/PR events | ✅ Full | Triage automation |
| `sync-main-to-testing.yml` | push main | ✅ Full | Branch sync |
| `release-reminder.yml` | schedule | ✅ Full | Stale promotion alert |
| `validate-renovate.yml` | PR | ✅ Full | Renovate config lint |
| `consumer-validate-generate-release-notes.yml` | dispatch | ✅ Full | Release note validation |

### bluefin-lts (similar pattern to bluefin)

Uses shared reusable workflows. Key difference: 7-day promotion floor. `scheduled-lts-release.yml` added the time floor.

### dakota (22 workflows)

| Workflow | Trigger | Automation Level | Notes |
|---|---|---|---|
| `build.yml` | push testing | ⚠️ Partial | BuildStream — needs build machine |
| `promote-testing-to-main.yml` | push testing + daily + dispatch | ✅ Full | OCI digest promotion |
| `execute-release.yml` | merged promotion PR | ✅ Full | testing→stable |
| `e2e.yml` | dispatch | ❌ Disabled | Needs #497 resolved |
| `publish.yml` | push main | ✅ Full | OCI publish |
| `track-bst-sources.yml` | schedule | ✅ Full | Source tracking |
| `track-next-junctions.yml` | schedule | ✅ Full | Upstream junction monitoring |
| `update-filemap.yml` | push | ✅ Full | File map generation |

### actions (19 workflows — reusable hub)

| Workflow | Purpose | Status |
|---|---|---|
| `reusable-build.yml` | Shared build+push+scan | ✅ Production |
| `reusable-execute-release.yml` | Shared promotion (cosign→skopeo) | ✅ Production |
| `reusable-release.yml` | Shared release notes + SBOM + card | ✅ Production |
| `reusable-release-gate.yml` | Shared pre-promotion checks | ✅ Production |
| `reusable-renovate.yml` | Shared Renovate runner | ✅ Production |
| `reusable-renovate-automerge.yml` | Shared automerge logic | ✅ Production |
| `reusable-sync-branches.yml` | Shared branch sync | ✅ Production |
| `reusable-release-reminder.yml` | Stale promotion alert | ✅ Production |
| `consumer-validation.yml` | Downstream compat test | ✅ Production |
| `migration-test.yml` | Upgrade path test | ✅ Production |
| `upgrade-test.yml` | Version upgrade validation | ✅ Production |

### testsuite (10 workflows)

Fully automated: `e2e.yml` (reusable), `nightly.yml`, `manual.yml` (dispatch), `migration-test.yml`, `unit-tests.yml`, `pr-validate.yml`, `build-runner.yml`.

### iso (9 workflows)

| Workflow | Trigger | Automation Level | Notes |
|---|---|---|---|
| `build-iso-stable.yml` | dispatch | 👤 Manual trigger | No event-driven rebuild |
| `build-iso-lts.yml` | dispatch | 👤 Manual trigger | No event-driven rebuild |
| `build-iso-lts-hwe.yml` | dispatch | 👤 Manual trigger | No event-driven rebuild |
| `build-iso-lts-hwe-testing.yml` | dispatch | 👤 Manual trigger | No event-driven rebuild |
| `build-iso-all.yml` | dispatch | 👤 Manual trigger | Umbrella workflow |
| `promote-iso.yml` | dispatch | 👤 Manual trigger | CloudFlare R2 promotion |
| `reusable-build-iso-anaconda.yml` | called | ✅ Reusable core | Build logic |
| `validate-renovate.yml` | PR | ✅ Full | Config lint |

## Automation Score

| Repo | Auto | Partial | Manual/Disabled | Score |
|---|---|---|---|---|
| common | 13 | 1 | 0 | 93% |
| bluefin | 26 | 0 | 0 | 100% |
| dakota | 18 | 1 | 1 | 90% |
| actions | 19 | 0 | 0 | 100% |
| testsuite | 10 | 0 | 0 | 100% |
| iso | 2 | 0 | 6 | 25% |
| **TOTAL** | **88** | **2** | **7** | **91%** |

## Critical Path Gaps (Blocking Full Automation)

| # | Gap | Impact | Tracked |
|---|---|---|---|
| 1 | ISO builds are fully manual (dispatch-only) | No automated rebuild on stable promotion | ❌ Not tracked |
| 2 | Dakota E2E disabled | No automated validation for dakota images | #497 |
| 3 | Installability gate missing | Can't verify install works before promotion | #423 |
| 4 | Bonedigger crash signal not wired | No automated rollback on user-reported crashes | #424 |
| 5 | Key-based signing (not keyless) | Requires secret rotation; no OIDC provenance | #513 |
| 6 | No SBOM on common build.yml | Supply chain gap | actions#86 |
| 7 | No SLSA L2 provenance | Supply chain gap | actions#86 |
| 8 | MERGERAPTOR secrets missing for sync-labels | Label sync fails silently | #511 |
