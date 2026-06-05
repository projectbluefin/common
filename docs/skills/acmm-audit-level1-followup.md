---
name: acmm-audit-level1-followup
description: "ACMM Level 1 follow-up audit findings (second-pass, 2026-06-04). Sections 7-9: deep structural review, updated parity matrix, and complete issue batch."
---

## 7. Follow-Up Findings — 2026-06-04 (Second-Pass Audit)

This section extends the initial audit with findings from a deeper structural review conducted on the same day. The mission framing is unchanged: **Project Bluefin is an Agentic OS Components factory.** `common` is the org brain. All findings below reinforce that identity.

---

### New Blindspots (BS-1.12 through BS-1.16)

#### BS-1.12 · `migration-status.md` is stale — agents will act on false data

**File:** `docs/factory/migration-status.md`  **Risk:** Silent misdirection of all agents doing parity work

`migration-status.md` is the "live parity matrix" every agent reads before working across repos. As of the second-pass audit it contains **at minimum two confirmed stale entries:**

1. `skill-drift.yml` column for `common` shows `❌ [#413]` — but `common` now has `skill-drift.yml` in `.github/workflows/`. **Status should be ✅.**
2. `bonedigger.yml lifecycle` column for `bluefin-lts` shows `❌ [#412]` — but `bluefin-lts` now has a functional `bonedigger.yml` using `projectbluefin/bonedigger/.github/workflows/lifecycle.yml@main`. **Status should be ✅.**

An agent reading the stale table will claim work that is already done, or open duplicate issues. Worse, it will skip loading the correct skills because it thinks the infrastructure doesn't exist yet.

**Fix:** Update `migration-status.md` immediately. Add a mandatory "verified as of" date field to the table header. Document the update protocol as: whenever a PR lands that closes a parity gap, the same PR must also update `migration-status.md`.

**Required constraint rule:** "Before claiming any parity gap issue, verify the live state of the target repo's workflows. `migration-status.md` may be stale. The file is not authoritative — direct repo inspection is."

---

#### BS-1.13 · `pr-e2e.yml` e2e job is disabled — the pre-merge gate is non-functional

**File:** `common/.github/workflows/pr-e2e.yml` line 115  **Risk:** Agents believe a pre-merge gate is active when it is not

The `e2e` job in `pr-e2e.yml` has `if: false # temporarily disabled — e2e suite is known broken`. The `compose` job still runs (builds and pushes the test image to GHCR), but no test scenarios execute against it. The `e2e-ci.md` skill documents this caveat correctly, but:

- `workflow-map.md` lists `pr-e2e.yml` as the "Pre-merge composed-image gate for the PR's common layer" without flagging that the gate is currently a no-op
- The parity matrix in `migration-status.md` and `factory/README.md` does not surface the disabled state
- An agent reading `pr-e2e.yml` header will see it triggers on `pull_request` and `merge_group` and assume e2e is running

**Concrete failure mode:** An agent merges a change to `system_files/bluefin/` believing pre-merge e2e caught any regressions. It did not. The only safety net is post-merge `e2e.yml` — which is too late.

**Fix:** Add a warning banner to `workflow-map.md` and `e2e-ci.md` (already has the note — verify it is prominent). Add a comment in the `pr-e2e.yml` `compose` job itself stating "Note: e2e job below is currently disabled — see e2e-ci.md". File an issue to re-enable when the GNOME smoke suite is fixed.

**Required constraint rule:** "Do NOT assume pre-merge e2e is protecting `common` PRs. As of 2026-06-04, the `pr-e2e.yml` e2e job is `if: false`. Only the `build.yml` job is a required gate."

---

#### BS-1.14 · testsuite `migration-test.yml` has no automated trigger

**File:** `testsuite/.github/workflows/migration-test.yml`  **Risk:** Migration regressions never auto-detected

`migration-test.yml` is `workflow_dispatch` only — there is no `schedule` or `push` trigger. Migration tests (bootc upgrade paths from version to version) only run when a human manually dispatches the workflow. This means:

- A change that breaks `bootc upgrade` paths will ship to users
- No agent working in `common` or `bluefin` will be warned by CI
- The only feedback is user-reported breakage post-promotion

**Fix:** Add a `schedule: cron: '0 8 * * 1'` trigger (weekly Monday) alongside the existing `workflow_dispatch`. The weekly cadence keeps the cost low while providing automated detection.

**Required constraint rule:** "Migration upgrade path testing is NOT in any required CI gate. Changes to bootc version pinning, `ostree-ext`, or image base digests carry invisible migration risk."

---

#### BS-1.15 · `bonedigger.yml` in factory uses floating `@main` tag — violates own policy

**File:** `bluefin-lts/.github/workflows/bonedigger.yml`  **Risk:** Pinning policy inconsistency; self-referential exception confusion

`bonedigger.yml` in `bluefin-lts` (and `bluefin`, `common`) calls:
```yaml
uses: projectbluefin/bonedigger/.github/workflows/lifecycle.yml@main
```

The `no-floating-action-tags` pre-commit hook exempts `projectbluefin/` refs, treating `@v1` and `@main` as "intentional managed tags." This is correct policy — but the exemption is invisible unless you read the hook regex and the policy comment. An AI auditing the repo will flag `@main` in `bonedigger.yml` as a violation and "fix" it by pinning to a SHA — which would break lifecycle automation if `bonedigger` does not use versioned releases.

**Fix:** Add a comment block in `bonedigger.yml` files: `# @main is intentional — projectbluefin/ internal refs are managed tags, exempt from the no-floating-action-tags hook (see docs/skills/ci-tooling.md)`. Ensure this is present in all repos where `bonedigger.yml` uses `@main`.

**Required constraint rule:** "The `no-floating-action-tags` hook exempts `projectbluefin/` refs. Do NOT pin `projectbluefin/bonedigger`, `projectbluefin/actions`, or `projectbluefin/actions` reusable workflows to SHAs in external repos — they are managed floating tags, not third-party dependencies."

---

#### BS-1.16 · `actions` blast-radius documentation covers `aurora`/`bazzite` in prose only

**File:** `actions/docs/skills/consumer-validation.md`  **Risk:** Agent cannot validate out-of-org consumers and has no automated fallback

`consumer-validation.md` correctly documents that `ublue-os/aurora` and `ublue-os/bazzite` are external consumers of `projectbluefin/actions@v1` with no CI visibility. However, no machine-readable contract or Justfile contract test exists to verify that an actions change would not break those consumers' Justfile recipe invocations.

The `consumer-guide.md` lists the Justfile recipe signatures but there is no automated schema test. An action change that renames a `with:` input or drops a default value will pass all `projectbluefin/` CI and break `aurora`/`bazzite` silently until a human notices.

**Fix:** Add a YAML schema test or `just verify-consumer-contract` recipe to `actions` that validates the current `action.yml` `inputs:` against a pinned snapshot of what `aurora` and `bazzite` pass. File an issue in `projectbluefin/actions` to track this.

**Required constraint rule:** "Renaming or removing any `inputs:` key in an `action.yml` requires checking `actions/docs/skills/consumer-guide.md` for the full consumer contract. Changes that break the contract must be versioned (new `@v2` tag), not silently shipped in `@v1`."

---

### Updated Feedback Mechanisms (Section 2 Supplement)

Additional gates discovered in the second-pass audit:

| Gate | Trigger | What it catches | Status |
|---|---|---|---|
| `consumer-validation.yml` (actions) | PR open/sync/ready | Missing consumer PR/CI evidence fields | ✅ Active |
| `skill-drift.yml` (common) | PR to main | Code changes without skill file updates | ✅ Active (was ❌ in initial pass) |
| `bonedigger.yml` (bluefin-lts) | issue events + daily | Issue lifecycle state machine | ✅ Active (was ❌ in initial pass) |
| `promotion-candidate-e2e.yml` (common) | weekly Tuesdays | smoke/common on `bluefin:testing` + `lts-testing` | ✅ Active |
| `pr-e2e.yml` compose job (common) | PRs to main | Builds composed test image | ✅ Active (compose only) |
| `pr-e2e.yml` e2e job (common) | PRs to main | Runs GNOME scenarios against composed image | ❌ **DISABLED** (`if: false`) |
| `migration-test.yml` (testsuite) | manual only | bootc upgrade path regressions | ⚠️ **No auto-trigger** |
| `factory-operations.yml` / production env (bluefin, bluefin-lts, dakota) | promotion workflow | 2-human approval gate before `:stable` | ✅ Active |

#### New critical gaps (supplement)

- **`pr-e2e.yml` e2e job is `if: false`** — this is the pre-merge composition gate; it exists as infrastructure but runs zero scenarios. Current required gate for `common` PRs is `build.yml` only.
- **`migration-test.yml` has no schedule trigger** — migration upgrade path coverage is manually triggered only (hive P1, `testsuite` issue #235).
- **`actions` consumer contract has no machine verification** — `aurora`/`bazzite` compatibility can silently break (BS-1.16).

---

### Updated Structural Obstacles (Section 3 Supplement)

#### SO-3.8 · `migration-status.md` staleness is a structural trust failure

**File:** `docs/factory/migration-status.md`

The factory's live parity matrix — which every agent reads at session start — can fall out of sync with reality silently. There is no automated check that `migration-status.md` stays accurate. When it drifts, agents read false state. This is not a cosmetic issue: it directly misdirects agent work allocation, causing duplicate claims and missed gaps simultaneously.

**Structural constraint:** Any workflow or AGENTS.md that references "the parity matrix" must also carry the warning: "Verify the live state directly — `migration-status.md` requires manual updates and may be stale."

---

#### SO-3.9 · Two separate parity matrices exist with no sync

**Files:** `docs/factory/migration-status.md` and `docs/factory/README.md` (both contain tables)

`README.md` has a snapshot matrix. `migration-status.md` has a more detailed matrix. Both can independently drift. An agent that reads only one of them will have a partial picture. There is no single authoritative source.

**Fix:** Make `README.md`'s matrix a summary reference with a "see migration-status.md for current state" note. All updates go to `migration-status.md` only. Validate parity between them in `validate.yml` or via a scheduled check.

---

### Updated Recommendations for Level 2 (Section 4 Supplement)

#### R-11 · ~~Fix `migration-status.md` stale entries~~ — RESOLVED

`migration-status.md` was deleted 2026-06-04. Factory infrastructure state is now documented as prose in `docs/factory/README.md` (single source of truth). Open gaps are tracked as linked issues in that file.

---

#### R-12 · Re-enable `pr-e2e.yml` e2e job or document recovery path explicitly (P1)

**Target:** `common` / `.github/workflows/pr-e2e.yml` and `docs/skills/e2e-ci.md`

The `if: false` guard has no associated issue or milestone. It is blocking a key Level 2 feedback loop. An agent encountering it has no path to resolution without additional context.

**Required actions:**
1. File a `common` issue: "Re-enable `pr-e2e.yml` e2e job after GNOME smoke suite fixed"
2. Add to the `if: false` comment: a link to that issue number
3. Add a `workflow-map.md` note: "`pr-e2e.yml` currently runs compose only (e2e disabled, see issue #NNN)"
4. When the GNOME smoke suite is fixed in `testsuite`, the recovery path is: remove `if: false`, verify PR CI, update `e2e-ci.md`

---

#### R-13 · Add weekly schedule trigger to `migration-test.yml` in testsuite (P1)

**Target:** `testsuite` / `.github/workflows/migration-test.yml`

**Required action:** Add:
```yaml
schedule:
  - cron: '0 8 * * 1'   # Monday 08:00 UTC
```

This is a hive P1 item. The fix is a single YAML addition. The companion work (pinning `behave`/`pyyaml` pip deps in the workflow) is also a P1 from the same hive scanner entry.

---

#### R-14 · Add inline exemption comments to all `bonedigger.yml` files using `@main` (P2)

**Target:** `common`, `bluefin`, `bluefin-lts` / `.github/workflows/bonedigger.yml`

Add a comment block explaining the `@main` exemption policy so agents do not "fix" it:
```yaml
# @main is intentional: projectbluefin/ refs are managed floating tags,
# exempt from the no-floating-action-tags hook.
# See docs/skills/ci-tooling.md — "What the hook exempts"
```

---

#### R-15 · Add Justfile contract test to `actions` for out-of-org consumer validation (P2)

**Target:** `actions` / new `just verify-consumer-contract` recipe

Create a snapshot file `docs/consumer-contract.yml` listing the `inputs:` for each action consumed by `aurora` and `bazzite` (derived from `consumer-guide.md`). Add a Justfile recipe:
```just
verify-consumer-contract:
    python3 scripts/check-consumer-contract.py
```
The script diffs current `action.yml` inputs against the snapshot and fails if any required input is missing or renamed.

---

## 8. Updated Parity Matrix (2026-06-04 follow-up)

| Artifact | common | bluefin | bluefin-lts | dakota | actions | testsuite |
|---|---|---|---|---|---|---|
| AGENTS.md | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| pre-commit | ✅ | ✅ | ✅ | ❌ | — | — |
| skill-drift.yml | ✅ | ✅ | ✅ | ✅ | ✅ | — |
| no-floating-action-tags hook | ✅ | ✅ | ✅ | ❌ | ✅ | — |
| bonedigger lifecycle | ✅ | ✅ | ✅ | ❌ | — | — |
| Renovate config | ❌ | ✅ | ✅ | ❌ | ✅ | ✅ |
| Post-merge e2e | ✅ | ✅ | ❌ | partial | — | — |
| Pre-merge composition e2e | ⚠️ compose only (e2e `if: false`) | ✅ | ❌ | ❌ | — | — |
| Installability gate | ⚠️ testing-stream smoke/common only | ❌ | ❌ | ❌ | — | ❌ |
| 2-human production gate | ✅ | ✅ | ✅ | ✅ | — | — |
| CODEOWNERS active | ✅ | ✅ | ✅ | ✅ | — | — |
| docs/skills/ populated | ✅ | ✅ | partial | ✅ | ✅ | ✅ |
| Migration-test auto-trigger | — | — | — | — | — | ❌ (manual only) |
| consumer contract machine-verified | — | — | — | — | ❌ | — |
| migration-status.md accurate | ❌ (stale entries) | — | — | — | — | — |

Changes from initial pass: bonedigger ✅ for bluefin-lts (was ❌), skill-drift ✅ for common (was ✅ — initial pass was correct; migration-status.md table was wrong), pre-merge e2e now shows ⚠️ state, production gate row added.

---

## 9. Complete Issue Batch — Updated Priority Order

| Priority | Issue | Repo | Type | Blocking |
|---|---|---|---|---|
| CRIT | hive advisory | bluefin-lts | ALL 5 build workflows failing | deployment |
| CRIT | hive advisory | testsuite | knuckle headless ISO smoke failing (7+ PRs blocked) | knuckle CI |
| P1 | [#235](https://github.com/projectbluefin/testsuite/issues/235) | testsuite | migration-test needs schedule trigger | upgrade regressions |
| P0 | [#409](https://github.com/projectbluefin/common/issues/409) | org-wide | lifecycle bot | all agent operations |
| P0 | new | common | migration-status.md stale fix | agent misdirection |
| P1 | new | common | pr-e2e.yml recovery path issue | pre-merge gate |
| P1 | [#468](https://github.com/projectbluefin/common/issues/468) | common | image-registry guard | org-migration breaks |
| P1 | [#476](https://github.com/projectbluefin/common/issues/476) | bluefin | pre-push hook | remote trap |
| P1 | [#471](https://github.com/projectbluefin/common/issues/471) | bluefin | copr-security skill | security invariant |
| P1 | [#472](https://github.com/projectbluefin/common/issues/472) | bluefin | Containerfile docs | cache boundary |
| P1 | [#474](https://github.com/projectbluefin/common/issues/474) | bluefin-lts | centos-vs-fedora skill | LTS contamination |
| P1 | [#475](https://github.com/projectbluefin/common/issues/475) | dakota | not-bluefin.md | build paradigm |
| P1 | [#473](https://github.com/projectbluefin/common/issues/473) | actions | consumer-validation skill | @v1 blast radius |
| P1 | [#469](https://github.com/projectbluefin/common/issues/469) | common | rollback-helper skill | TUI state machine |
| P1 | [#470](https://github.com/projectbluefin/common/issues/470) | common | dconf automated check | settings parity |
| P1 | [#425](https://github.com/projectbluefin/common/issues/425) | common | lts e2e gate | testing quality |
| P1 | [#423](https://github.com/projectbluefin/common/issues/423) | common | installability gate | promotion quality |
| P2 | new | actions | consumer contract machine test | aurora/bazzite safety |
| P2 | new | all bonedigger repos | @main exemption comments | agent confusion |
| P2 | [#403](https://github.com/projectbluefin/common/issues/403) | common | factory/README.md | org entry point |
| P2 | [#404](https://github.com/projectbluefin/common/issues/404) | org-wide | infra parity epic | agent reliability |
| P2 | [#405](https://github.com/projectbluefin/common/issues/405) | org-wide | QA epic | quality gates |

