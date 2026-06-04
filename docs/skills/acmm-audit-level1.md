---
name: acmm-audit-level1
description: "ACMM Level 1 audit — blindspots, feedback mechanisms, structural obstacles, and Level 2 recommendations. Continuously revised."
---

# ACMM Level 1 Audit — Project Bluefin Factory

**Initial date:** 2026-06-04  **Last revised:** 2026-06-04 (follow-up pass)
**Framework:** AI Codebase Maturity Model (arXiv:2604.09388)
**Level:** 1 (Assisted) → bridge to Level 2 (Instructed)
**Scope:** `common`, `bluefin`, `bluefin-lts`, `dakota`, `actions`, `testsuite`

---

## Executive Summary

The projectbluefin factory is a six-repo OCI image pipeline operated increasingly by AI agents. It has strong **documentation discipline** and a growing **skills infrastructure**, but several critical architectural boundaries are invisible to an unguided AI model — creating predictable regression vectors. This audit identifies those blindspots, maps the current feedback mechanisms, flags structural obstacles, and prescribes the Level 2 skill artifacts needed to close the open-loop context leak.

The core mission — **Agentic OS Components / operating system factory** — must be the first thing any agent reads. `common` is the org brain. That framing must be explicit in every entry point.

---

## 1. AI Usage Blindspots

These are the highest-probability regression sites where an AI without full codebase context will confidently generate broken changes.

### BS-1.1 · `common` skill-drift enforcement was missing and is now live

**Repo:** common  **Issue:** [#413](https://github.com/projectbluefin/common/issues/413)

`bluefin`, `bluefin-lts`, and `dakota` already had `skill-drift.yml` wired. `common` — the **canonical skills hub** — was the holdout, so implementation PRs could land here with no prompt to update docs. That gap is now closed in `common`, but the lesson remains: the skills hub must enforce its own hygiene first.

**Immediate fix:** Land `.github/workflows/skill-drift.yml` in `common` (done) and continue parity work in the remaining repos.

---

### BS-1.2 · `bluefin` Containerfile Stage 1 / Stage 2 cache boundary

**Repo:** bluefin  **Issue:** [#472](https://github.com/projectbluefin/common/issues/472)

The Containerfile splits into two `RUN` directives with ARG declarations placed intentionally *between* them to avoid busting Stage 1's cache on every commit. An AI asked to "add a package" will naturally append to Stage 2 or move the ARG declarations upward — silently breaking 20–80 minutes of cache savings on every CI build. No test detects this; the only feedback is CI wall-clock time.

**Immediate fix:** Inline comments already added to `bluefin/Containerfile` marking the boundary. Codify in `bluefin/docs/build.md` which numbered scripts belong to which stage.

---

### BS-1.3 · `copr-helpers.sh` security invariant looks like dead code

**Repo:** bluefin  **Issue:** [#471](https://github.com/projectbluefin/common/issues/471)

`copr_install_isolated()` performs: enable → **immediately disable** → install with `--enablerepo`. The disable step is a **security boundary** — it prevents an active COPR from injecting fake versions of Fedora packages into subsequent `dnf5 install` calls. An AI reading this pattern will classify the `disable` call as redundant cleanup and remove it. No pre-commit or CI check validates this invariant.

**Immediate fix:** Add a security comment block to `copr-helpers.sh`. Create `bluefin/docs/skills/copr-security.md`.

---

### BS-1.4 · `actions` @v1 tag affects all consumers simultaneously

**Repo:** actions  **Issue:** [#473](https://github.com/projectbluefin/common/issues/473)

`projectbluefin/actions@v1` is consumed by `bluefin`, `bluefin-lts`, `aurora` (ublue-os), and `bazzite` (ublue-os). The consumer validation protocol (open draft PR in a consuming repo, verify CI green, *then* merge) is documented in prose but has no PR checklist item, no cross-org visibility for `aurora`/`bazzite`, and `skill-drift-check.yml` warns but does not block.

**Immediate fix:** Add PR checklist to `actions/.github/pull_request_template.md`. Create `actions/docs/skills/consumer-validation.md`.

---

### BS-1.5 · ublue-os → projectbluefin image ref migration is incomplete

**Repo:** common, bluefin  **Issue:** [#468](https://github.com/projectbluefin/common/issues/468)

Production OCI images are **still published at `ghcr.io/ublue-os/bluefin*`**. An AI doing a "modernization" pass replacing `ublue-os` refs with `projectbluefin` will break e2e workflows, PR smoke gates, and the runtime registry path used by `ublue-rollback-helper`. No code-level guard prevents this. Memory/documentation only.

**Existing skill:** `docs/skills/image-registry.md` — verify it is linked from every AGENTS.md entry point.

---

### BS-1.6 · `bluefin` git remote trap — confirmed incident 2026-06-01

**Repo:** bluefin  **Issue:** [#476](https://github.com/projectbluefin/common/issues/476)

In `projectbluefin/bluefin`, `origin` points to `ublue-os/bluefin` (the upstream, not the fork). A bare `git push` or `git push origin` sends commits to the wrong org. This has already happened. The correct remote is `projectbluefin`. Documented in `AGENTS.md` but no pre-push hook enforces it — the push succeeds silently.

**Immediate fix:** Add a `.git/hooks/pre-push` script to `bluefin` that blocks pushes to `origin`. Install via `docs/build.md` dev setup section.

---

### BS-1.7 · dconf lock/override parity has no automated check

**Repo:** common  **Issue:** [#470](https://github.com/projectbluefin/common/issues/470)

`system_files/bluefin/etc/dconf/db/distro.d/` and the `*.gschema.override` file must stay in sync with the lock file. Editing one without the other produces either a locked key with no override (dconf error at boot) or an override that users can silently revert. The E2E suite is the only downstream check — it runs **post-merge**.

**Existing skill:** `docs/skills/dconf-consistency.md` — ensure it is loaded before any GNOME settings task.

---

### BS-1.8 · Dakota build paradigm contamination from bluefin context

**Repo:** dakota  **Issue:** [#475](https://github.com/projectbluefin/common/issues/475)

Dakota uses **BuildStream 2 (BST)**. There are no `dnf5` commands, no Fedora RPMs, no COPR. Everything is `.bst` element files. An AI primed with `common` or `bluefin` context will attempt `dnf5 install`, create Containerfile stages, or reference `copr-helpers.sh` — all completely inapplicable. Dakota's own `Containerfile` (used only for final OCI assembly) and matching `Justfile` names create further confusion.

**Immediate fix:** Create `dakota/docs/skills/not-bluefin.md` as a required-first-read skill explicitly listing prohibited patterns from bluefin context.

---

### BS-1.9 · bluefin-lts CentOS/Fedora contamination — COPR is Fedora-only

**Repo:** bluefin-lts  **Issue:** [#474](https://github.com/projectbluefin/common/issues/474)

`bluefin-lts` is built on **CentOS Stream 10**. COPR does not exist on CentOS. An AI with bluefin context will use `copr-helpers.sh` patterns or add `dnf5 copr enable` — these silently fail or break the image. Akmods come from `ghcr.io/ublue-os/akmods-*:centos-10` (not `coreos-stable`), and `FEDORA_AKMODS_VERSION` ARGs in the LTS Containerfile create additional cross-contamination risk.

**Immediate fix:** Create `bluefin-lts/docs/skills/centos-vs-fedora.md`.

---

### BS-1.10 · Lifecycle bot still fragmented across 5 repos

**Repo:** org-wide  **Issue:** [#409](https://github.com/projectbluefin/common/issues/409)

The `filed → approved → queued → claimed → done` state machine still runs on three different engines across five repos: bonedigger (bluefin, common), actionadon (dakota, knuckle), and nothing (bluefin-lts). `common` is no longer missing lifecycle automation, but the factory is still fragmented and `bluefin-lts` remains uncovered. This is still one of the biggest operational risks to a multi-agent factory.

**Immediate fix:** Add `bonedigger.yml` to `bluefin-lts`, then align the remaining engines on a single contract.

---

### BS-1.11 · Floating GitHub Action tags — parity still incomplete outside `common`

**Repo:** common  **Issue:** [#477](https://github.com/projectbluefin/common/issues/477)

`common`, `bluefin`, `bluefin-lts`, and `actions` now have the `no-floating-action-tags` pre-commit hook. `actionlint` still only catches syntax errors, not SHA pinning, so repos without the hook remain vulnerable to `@v3` / `@main` regressions copied from GitHub examples.

**Existing skill:** `docs/skills/ci-tooling.md` covers the hook pattern. The remaining work is parity in repos that still lack the hook.

---

## 2. Current Feedback Mechanisms

These are the active feedback loops that currently arrest error cascades.

| Gate | Trigger | What it catches |
|---|---|---|
| `validate.yml` (common) | PR to `main` | just syntax, shellcheck, pre-commit, submodule drift |
| `pre-commit` (common) | commit | JSON/YAML/TOML format, trailing whitespace, merge conflicts, private keys, actionlint |
| `validate-brewfiles.yaml` (common) | PR to `main` | Brewfile validity |
| `build.yml` (common) | merge to `main` | OCI build integrity |
| `e2e.yml` (common) | post-merge | End-to-end: bluefin, bluefin-lts, dakota images |
| `pr-smoke.yml` (bluefin) | PR | Containerfile build smoke |
| `pr-validation.yml` (bluefin) | PR | `just check`, `pre-commit`, `no-floating-action-tags` |
| `skill-drift.yml` (bluefin, bluefin-lts, actions, dakota) | PR | Detects implementation changes without doc updates |
| `copr-health-monitor.yml` (bluefin) | scheduled | COPR repo availability check |
| `behave --dry-run` (testsuite) | PR | Step phrase/feature file sync |
| `ruff check` (testsuite) | PR | Python lint |
| `shellcheck` (common, bluefin) | PR | Shell syntax |
| `actionlint` (pre-commit) | commit | GitHub Actions YAML validity |
| `bootc container lint` (bluefin Containerfile) | build | bootc image structural lint |

### Critical gaps

- **No pre-merge composition test** for `common`: a `common` change lands before downstream bluefin/lts/dakota builds validate it (issue [#405](https://github.com/projectbluefin/common/issues/405)).
- **No full installability gate** before `testing → stable` promotion (issue [#423](https://github.com/projectbluefin/common/issues/423)). `common` now has scheduled `smoke,common` coverage on `bluefin:testing` and `bluefin:lts-testing`, but there is still no installer/bootc-install gate.
- **No bonedigger signal** wired into promotion decisions (issue [#424](https://github.com/projectbluefin/common/issues/424)).
- **`bluefin-lts` still has no repo-local post-merge e2e** (issue [#425](https://github.com/projectbluefin/common/issues/425)). `common` now adds a common-side weekly smoke/common check on `:lts-testing`, but downstream parity is still incomplete.

---

## 3. Structural Obstacles

Code structures that will cause an unguided AI to generate confidently wrong implementations.

### SO-3.1 · `ublue-rollback-helper` — three-way coordinated state machine

**File:** `system_files/bluefin/usr/bin/ublue-rollback-helper`  **Issue:** [#469](https://github.com/projectbluefin/common/issues/469)

~80 lines of stateful shell implementing an interactive TUI with:
- LTS/non-LTS split branching on `IMAGE_TAG` containing "lts"
- **Three coordinated arrays**: `IMAGES`, `CHANNELS`, and the `filter` regex — all must change together when adding a new variant (e.g., `nvidia-lts`, a new channel)
- Runtime registry path derived from `image-info.json` at `IMAGE_VENDOR`
- `gum choose` / `gum confirm` interactive prompts with no tests

ShellCheck runs in CI but cannot catch semantic logic errors in the channel/tag branching. Adding a variant by touching only one of the three arrays silently produces broken runtime behavior.

**Fix:** Add BATS unit tests mocking `gum`, `skopeo`, `bootc`. Create `docs/skills/rollback-helper.md`. Add inline comments marking the three places that must change together.

---

### SO-3.2 · `system_files/shared/` looks editable but is not

**File:** `system_files/shared/`  **Skill:** `docs/skills/submodule-boundary.md`

`system_files/shared/` is a **read-only** bind-mount from the `aurorafin-shared` submodule. `system_files/bluefin/` is the editable local path. These two directories look identical at the filesystem level. An AI that edits `system_files/shared/` directly will produce a change that `validate.yml`'s submodule drift check rejects — but only at PR time, not at commit time.

**Existing skill:** `docs/skills/submodule-boundary.md` covers this. Ensure it is the first skill loaded for any `system_files/` task.

---

### SO-3.3 · `copr-helpers.sh` enable → disable looks like dead code

**File:** `build_files/shared/copr-helpers.sh` (bluefin)

See BS-1.3 above. The structural obstacle is that the correct pattern (`enable`, `disable`, `install --enablerepo`) is indistinguishable from a buggy implementation to any AI that does not know the security reason. "Dead code removal" is a natural refactor suggestion.

---

### SO-3.4 · Dakota `Containerfile` ≠ bluefin `Containerfile`

**Repo:** dakota

Dakota's `Containerfile` performs only the **final OCI assembly** step. It does not contain build logic. Package installation happens entirely in `.bst` element files via BuildStream. The presence of a file named `Containerfile` and a file named `Justfile` creates strong anchor bias toward bluefin's patterns.

---

### SO-3.5 · `common` Containerfile is a **base layer**, not an image

**File:** `Containerfile` (common)

`common`'s `Containerfile` produces an intermediate OCI layer consumed by downstream image repos via `FROM ghcr.io/projectbluefin/common:latest AS common` → `COPY --from=common`. It is not a bootable image. Changes here silently affect all three downstream images. An AI treating it as a self-contained image will introduce breakage that appears only in bluefin/lts/dakota builds.

---

### SO-3.6 · `@v1` floating tag in `actions` — blast radius is org-wide

**Repo:** actions

`projectbluefin/actions@v1` is a mutable floating tag. Merging to `main` and force-pushing `@v1` immediately affects **every consuming repo simultaneously**: bluefin, bluefin-lts, aurora (ublue-os), bazzite (ublue-os). An AI that merges without running the consumer validation protocol will deploy a breaking change silently across the entire org.

---

### SO-3.7 · `CODEOWNERS` TRIAGERS sentinel is a commented placeholder

**File:** `.github/CODEOWNERS` (common)  **Issue:** [#417](https://github.com/projectbluefin/common/issues/417)

The TRIAGERS sentinel block is commented out. This means triage-level permissions are not enforced — any contributor can implicitly approve certain files. An AI that reads CODEOWNERS as authoritative will be misled about who can merge what.

---

## 4. Recommendations for Level 2 (Instructed)

Ordered by blast radius × probability of regression.

### R-1 · Close the lifecycle fragmentation gap (P0)

**Target:** `common`, `bluefin-lts`  **Issue:** [#409](https://github.com/projectbluefin/common/issues/409)

`common` now has `bonedigger.yml`; `bluefin-lts` still does not. Finish the parity work there, then align the remaining lifecycle engines on one contract so agents do not have to memorize repo-specific claim behavior.

---

### R-2 · Wire `skill-drift.yml` into `common` (P0)

**Target:** `common`  **Issue:** [#413](https://github.com/projectbluefin/common/issues/413)

`common` is the canonical skills hub. It now enforces its own documentation hygiene with `skill-drift.yml`, so the next step is keeping the path mapping and adjacent skill docs current whenever workflow coverage changes.

**Supporting skill file:** `docs/skills/skill-drift.md` explains how to satisfy the check and what counts as a real skill update.

---

### R-3 · Add `no-floating-action-tags` hook to `common` (P1)

**Target:** `common`  **Issue:** [#477](https://github.com/projectbluefin/common/issues/477)

The local `pygrep`-based `no-floating-action-tags` hook is now present in `common/.pre-commit-config.yaml`. Keep the supporting docs and parity matrix accurate, and carry the same guard into any remaining repo that still lacks it.

---

### R-4 · Create `docs/skills/rollback-helper.md` (P1)

**Target:** `common`  **Issue:** [#469](https://github.com/projectbluefin/common/issues/469)

Document the three-way coordination requirement in `ublue-rollback-helper`. Until BATS tests exist, this skill doc is the only guard against the variant-addition pattern breaking silently.

**Required content:**
- The three arrays that must change together: `IMAGES`, `CHANNELS`, filter regex
- LTS/non-LTS branch semantics
- Runtime registry path derivation from `image-info.json`
- Mock pattern for testing `gum` interactivity

---

### R-5 · Create `bluefin/docs/skills/copr-security.md` (P1)

**Target:** `bluefin`  **Issue:** [#471](https://github.com/projectbluefin/common/issues/471)

Explain the `enable → disable → install --enablerepo` invariant as a security boundary. Link from `copr-helpers.sh` header comment. Add to `bluefin/docs/SKILL.md` routing table under "COPR".

---

### R-6 · Create `bluefin-lts/docs/skills/centos-vs-fedora.md` (P1)

**Target:** `bluefin-lts`  **Issue:** [#474](https://github.com/projectbluefin/common/issues/474)

**Required content:**
- No COPR on CentOS Stream 10 — use EPEL for third-party packages
- Correct akmods tag: `centos-10` not `coreos-stable`
- `FEDORA_AKMODS_VERSION` ARG purpose and scope (Fedora-sourced akmods for specific hardware only)
- CI guard: fail if `copr enable` appears in any CentOS build script

---

### R-7 · Create `dakota/docs/skills/not-bluefin.md` (P1)

**Target:** `dakota`  **Issue:** [#475](https://github.com/projectbluefin/common/issues/475)

Make this the **first skill in dakota's routing table**. Contents:

| Bluefin pattern | Dakota reality |
|---|---|
| `dnf5 install <pkg>` | Create a `.bst` element in `elements/` |
| `copr-helpers.sh` | Does not exist, not applicable |
| Containerfile build logic | BuildStream `.bst` elements only |
| `build_files/` shell scripts | `elements/*.bst` YAML |
| `system_files/` overlay | Installed via BST install commands |

---

### R-8 · Create `actions/docs/skills/consumer-validation.md` (P1)

**Target:** `actions`  **Issue:** [#473](https://github.com/projectbluefin/common/issues/473)

**Required content:**
- Blast-radius table: who consumes `@v1` (bluefin, bluefin-lts, aurora, bazzite)
- Step-by-step: open draft PR in `projectbluefin/bluefin` pinned to feature SHA → CI green → merge to `main` → human force-pushes `@v1`
- PR checklist item text (copy into `pull_request_template.md`)
- Out-of-org consumers (`aurora`, `bazzite`) — why agents cannot validate them directly

---

### R-9 · Add pre-merge composition test for `common` (P1)

**Target:** `common`  **Issue:** [#405](https://github.com/projectbluefin/common/issues/405)

`common` PRs currently merge before downstream validation. Add a PR gate that triggers a downstream build of `bluefin:testing` (using `repository_dispatch` or workflow call) and blocks merge until it succeeds.

---

### R-10 · Add `docs/factory/` directory to `common` (P2)

**Target:** `common`  **Issue:** [#403](https://github.com/projectbluefin/common/issues/403)

Create `docs/factory/README.md` as the factory entry point. Every agent entering the org should find the full operating model here. Required sections:
- "This is an OS factory. The product is bootc OCI images."
- Repo map with data flow
- Agentic model: how agents claim, work, verify
- Migration status: parity matrix across 5 repos
- Links to all per-repo AGENTS.md files

---

## 5. Parity Matrix Snapshot (2026-06-04)

| Artifact | common | bluefin | bluefin-lts | dakota | actions | testsuite |
|---|---|---|---|---|---|---|
| AGENTS.md | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| pre-commit | ✅ | ✅ | ✅ | ❌ | — | — |
| skill-drift.yml | ✅ | ✅ | ✅ | ✅ | ✅ | — |
| no-floating-action-tags hook | ✅ | ✅ | ✅ | ❌ | ✅ | — |
| bonedigger lifecycle | ✅ | ✅ | ❌ | ❌ | — | — |
| Renovate config | ❌ | ✅ | ✅ | ❌ | ✅ | ✅ |
| Post-merge e2e | ✅ | ✅ | ❌ | partial | — | — |
| Installability gate | ⚠️ testing-stream smoke/common only | ❌ | ❌ | ❌ | — | ❌ |
| CODEOWNERS active | ✅ | ✅ | ✅ | ✅ | — | — |
| docs/skills/ populated | ✅ | ✅ | partial | ✅ | ✅ | ✅ |

---

## 6. Issue Batch — Priority Order for Level 2 Transition

Work these in order. Each builds on the one before.

| Priority | Issue | Repo | Type | Unblocks |
|---|---|---|---|---|
| P0 | [#409](https://github.com/projectbluefin/common/issues/409) | org-wide | lifecycle bot | all agent operations |
| P1 | [#468](https://github.com/projectbluefin/common/issues/468) | common | image-registry guard | prevents org-migration breaks |
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
| P2 | [#403](https://github.com/projectbluefin/common/issues/403) | common | factory/README.md | org entry point |
| P2 | [#404](https://github.com/projectbluefin/common/issues/404) | org-wide | infra parity epic | agent reliability |
| P2 | [#405](https://github.com/projectbluefin/common/issues/405) | org-wide | QA epic | quality gates |

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
