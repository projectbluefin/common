# ACMM Level 1 Audit — Project Bluefin Factory

**Date:** 2026-06-04
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
