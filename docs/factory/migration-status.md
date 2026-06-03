# Factory Migration Status

Last updated: 2026-06-02

This document tracks the migration of all 5 factory repos to the unified agentic model.

## Parity matrix

| Item | bluefin | bluefin-lts | common | dakota | knuckle |
|---|---|---|---|---|---|
| AGENTS.md | ✅ | ✅ | ✅ | ✅ | ✅ |
| hive/p0, hive/p1 labels | ✅ | ✅ | ✅ | ✅ | ✅ |
| queue/agent-ready, agent/blocked labels | ✅ | ✅ | ✅ | ✅ | ✅ |
| Squash-only merge | ✅ | ✅ | ✅ | ✅ | ❌ [#411] |
| 5 standard issue templates | ✅ | ✅ | ✅ | ✅ | ❌ [#416] |
| CODEOWNERS + triage sentinel | ✅ | ✅ | ✅ | ✅ | ❌ [#414] |
| hive sync workflow | ❌ [#407] | ❌ [#407] | ❌ [#407] | ✅ | ✅ |
| bonedigger.yml lifecycle | ✅ | ❌ [#412] | ❌ [#412] | ❌ [#412] | ❌ [#412] |
| skill-drift.yml | ✅ | ✅ | ❌ [#413] | ✅ | ❌ [#413] |
| .pre-commit-config.yaml | ✅ | ✅ | ✅ | ❌ [#415] | ❌ [#415] |
| Renovate config | ✅ | ✅ (main, intentional) | ❌ [#410] | ❌ [#410] | ❌ [#410] |

Issue links are to `projectbluefin/common`.

## bonedigger state

| Item | State |
|---|---|
| AGENTS.md | ❌ [#418] |
| hive labels | ❌ [#418] |
| auto-merge | ❌ [#418] |
| Factory integration | bluefin only; 4 repos missing [#412] |
| sync-templates namespace | ❌ wrong org [#408] |

## What's complete ✅

- All 5 repos: AGENTS.md, full label set, auto-merge, delete-branch-on-merge
- 4/5 repos (all except knuckle): squash-only, 5 issue templates, CODEOWNERS
- bluefin + bluefin-lts: pre-commit, skill-drift, Renovate
- dakota + knuckle: hive sync workflows (with label bug — see #406)
- bluefin: bonedigger lifecycle wired

## QA gaps (see docs/skills/qa.md for full details)

| Issue | Gap | Priority |
|---|---|---|
| #419 | software.feature tests GNOME Software, not Bazaar | P0 |
| #421 | No pre-merge composition gate for common | P0 |
| #423 | No installability gate before promotion | P1 |
| #420 | No regression contract across streams | P1 |
| #422 | Hardware-only bug classes invisible to gate | P1 |
| #424 | bonedigger not wired into promotion | P1 |
| #425 | bluefin-lts testing→stable gate too weak | P1 |

## Tracking epics

All open migration gaps are tracked in `projectbluefin/common`:
- [#403](https://github.com/projectbluefin/common/issues/403) epic: common as org brain
- [#404](https://github.com/projectbluefin/common/issues/404) epic: factory infra parity
- [#405](https://github.com/projectbluefin/common/issues/405) epic: factory QA model
