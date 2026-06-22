# Promotion Gates — Testing→Stable Release Pipeline

This document defines the gates that control promotion from `testing` to `stable`
release channels in Project Bluefin. **Implemented gates are marked ✅. Planned
but not yet wired are marked ❌ with tracking issues.**

## Overview

```
main branch
    ↓
[nightly builds → :$sha only, never :testing directly]
    ↓
:testing / :lts-testing tag  ← gated by post-build e2e (❌ not yet wired for bluefin/#518, ❌ lts rebuilds/#517)
    ↓
[post-merge e2e]              ← Gate 1 (bluefin-lts only) ✅
    ↓
[TOCTOU SHA guard]            ← Gate 1b ❌ not yet wired (#524)
    ↓
[installability gate]         ← Gate 2 ❌ not yet wired (#423)
    ↓
:stable / :lts-stable tag
    ↓
[bonedigger crash signal]     ← Gate 3 ❌ not yet wired (#424)
    ↓
general availability
```

> **⚠️ LTS tag rename pending:** `bluefin:lts-testing` is being renamed to `bluefin-lts:testing` by `projectbluefin/bluefin-lts` PR #73 (`feat/shared-workflow-migration`). Do not build new tooling targeting the old tag. See `image-registry.md` for the full rename table.

> **Promotion pipeline consistency:** Epic [#516](https://github.com/projectbluefin/common/issues/516) tracks the full set of pipeline gaps across bluefin, bluefin-lts, and dakota. See `release-promotion.md` for the gap table and implementation order.

---

## Gate 1: Post-Merge E2E ✅ (bluefin-lts only)

**Status:** Active in `bluefin-lts`. `bluefin` has a PR-level smoke gate.

**Location:** `bluefin-lts/.github/workflows/post-merge-e2e.yml`

**Trigger:** After merge to `testing` in bluefin-lts

**Tests:**
- Runs `smoke,common` testsuite suites against `:lts-testing`
- Validates basic boot, desktop, and app functionality

**Pass criteria:** All `smoke,common` scenarios pass.

**Failure behavior:** Workflow fails, blocking release generation.

**Known gaps:**
- `bluefin:lts` nightly suite is currently degraded — ZFS `/var` blocks the harness
  (testsuite#373). Post-merge results for LTS should be treated with caution until
  this is resolved.
- Migration upgrade path testing is **not** part of this gate (manual-only,
  `testsuite/migration-test.yml`). Changes to bootc version pins carry invisible
  migration risk.

---

## Gate 2: Installability Gate ❌ Not yet wired

**Status:** Design stage. Tracking: [#423](https://github.com/projectbluefin/common/issues/423)

**Current substitute:** `promotion-candidate-e2e.yml` in `common` runs `smoke,common`
weekly against `:testing` and `:lts-testing`. This is **not** an installer gate —
it does not exercise anaconda/knuckle installation, disk layout, or bootc-install.

**Planned implementation:**
- Spin up VM with 50 GB disk
- Run full knuckle/anaconda installation from OCI image
- Boot installed system
- Validate GNOME and systemd health

This gate does not exist today. Do not cite it as a blocker in promotion decisions.

---

## Gate 3: Bonedigger Crash Signal ❌ Not yet wired

**Status:** Design stage. Tracking: [#424](https://github.com/projectbluefin/common/issues/424)

**Current substitute:** Manual review of open issues before promotion decisions.

**Planned implementation:**
When bonedigger exposes an API, a promotion workflow step will query for open
`crash`/`panic` reports associated with the candidate image digest and block
promotion if unresolved critical issues are found.

This gate does not exist today. Do not cite it as a blocker in promotion decisions.

---

## Gate 4: Hardware Canary ❌ Design only

**Status:** Design stage. See [HARDWARE_CANARY.md](HARDWARE_CANARY.md) for background.

Volunteer-driven hardware testing via the issue template in `common` feeds
promotion decisions manually today. There is no automated fleet or CI integration.

---

## Actual Pre-Promotion Checklist (Today)

Until the gates above are wired, this is the real process:

1. **`build.yml` passes** — required merge gate for `common`
2. **`pr-e2e.yml` common suite passes** — pre-merge composed image test (common only)
3. **`promotion-candidate-e2e.yml` passes** — weekly smoke/common on `:testing` and `:lts-testing`
4. **`post-merge-e2e.yml` passes** — bluefin-lts only, smoke/common post-merge
5. **Manual check:** no open `hive/p0` issues blocking the promotion target
6. **2-human approval gate** — `factory-operations` environment in bluefin, bluefin-lts, and dakota requires two maintainer approvals before `:stable` tag is pushed

---

## Related Documents

- [HARDWARE_CANARY.md](HARDWARE_CANARY.md) — Hardware canary program design intent
- [../skills/e2e-ci.md](../skills/e2e-ci.md) — E2E CI internals for `common`
- [../factory/README.md](../factory/README.md) — Factory open gaps and parity matrix
