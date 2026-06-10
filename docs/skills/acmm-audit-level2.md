---
name: acmm-audit-level2
description: "ACMM Level 2→3 bridge audit (historical archive). Factory reached Level 3 (Instructed) as of 2026-06-06. Use when reviewing the factory audit history or understanding the L2→L3 bridge requirements that were implemented."
metadata:
  type: reference
---

# ACMM Level 2 Audit — Project Bluefin Factory

> **Status (2026-06-06):** Factory has achieved **Level 3 (Instructed)**. This document records the Level 2 baseline assessment and the Level 3 bridge requirements that drove the upgrade. It is kept as historical context; it is not the current state.

**Framework:** AI Codebase Maturity Model (arXiv:2604.09388)
**Assessment:** Level 2 (Assisted) is **substantially met** with degraded confidence in promotion/testing reliability.
**Bridge target:** Level 3 (Instructed) — **achieved 2026-06-06**
**Scope:** `common`, `bluefin`, `bluefin-lts`, `dakota`, `actions`, `testsuite`
**Date:** 2026-06-05 (third pass — all L3 P1 issues filed)

---

## Contents
- [Executive Summary](#executive-summary)
- [Level 2 Criteria Evaluation](#level-2-criteria-evaluation)
- [1. AI Usage Blindspots](#1-ai-usage-blindspots)
- [2. Current Feedback Mechanisms](#2-current-feedback-mechanisms)
- [3. Structural Obstacles](#3-structural-obstacles)
- [4. Level 3 Bridge Requirements](#4-level-3-bridge-requirements)
- [5. Recommended Issue Batch](#5-recommended-issue-batch)
- [6. Doc Drift Findings](#6-doc-drift-findings-discovered-during-audit)
- [7. Supply Chain & Artifact Integrity](#7-supply-chain--artifact-integrity-level-3-preparation)
- [Appendix: Level Definitions](#appendix-level-definitions-arxiv26040938)

---

## Executive Summary

> **This is a historical baseline document.** The factory reached Level 3 (Instructed) on 2026-06-06. The text below records the L2 state as assessed on 2026-06-05. Use it to understand the bridge requirements that were implemented.

The projectbluefin factory was a six-repo OCI image pipeline assessed at Level 2 (Assisted) maturity: agents operated with human review, skill docs provided operational context, and feedback loops (CI gates, linters, e2e tests) arrested most error cascades before production.

**Core mission reminder:** This is an **Agentic OS Components / operating system factory**.
The product is bootc OCI images. `common` is the org brain. Every agent must internalize
this before making changes.

**What Level 2 means (arXiv:2604.09388):**
- AI tools are used interactively with human review
- Basic feedback loops exist (linters, tests, CI)
- Documentation aids AI usage but is not enforced programmatically
- Errors are caught by humans or by existing CI, not by AI-specific constraints

**What Level 3 (Instructed) adds:**
- Repository-specific constraint rules are machine-readable
- AI tools are given explicit instructions before operating
- Feedback loops include AI-specific guardrails
- Context is provided programmatically, not hoped-for

---

## Level 2 Criteria Evaluation

### Criteria Matrix

| ACMM L2 Criterion | Evidence | Repo(s) | Status | Level 3 Bridge |
|---|---|---|---|---|
| **AI tools used with human review** | 1-human PR approval required; `factory-operations` env requires 2 humans for promotion | all | ✅ | Enforce instruction loading before operation |
| **Basic CI feedback loops** | `just check`, pre-commit, validate.yml, build.yml, unit tests | common, bluefin, bluefin-lts, dakota | ✅ | Add AI-specific constraint validation |
| **Documentation aids AI usage** | 53+ skill docs, AGENTS.md in all 6 repos, factory README, agentic-model.md | all | ✅ | Make loading mandatory + machine-verified |
| **Linting catches common errors** | pre-commit (YAML/JSON/trailing-ws), actionlint, shellcheck, ruff | common, bluefin, bluefin-lts, dakota, actions, testsuite | ✅ | Add repo-specific semantic lints |
| **Tests validate behavior** | E2E (pre/post-merge), unit (BATS, pytest), compose gate, behave suites | common, bluefin, testsuite | ✅ | Wire installability + migration gates |
| **Errors caught before production** | skill-drift advisory, consumer-validation blocking, promotion-candidate weekly | common, bluefin, actions | ✅ | Make all advisory gates blocking |
| **Human accountability preserved** | `/approve`, merge approval, `hive/p0`/`p1`, production promotion, ublue-os prohibition | all | ✅ | Document as permanent human gates |

### Degraded Confidence Areas

| Area | Issue | Impact |
|---|---|---|
| Nightly LTS/GDX e2e reliability | testsuite#372, testsuite#373 | CI desensitization — agents dismiss real failures |
| Installability gate absent | common#423 | Broken installer paths reach testing→stable |
| Migration test manual-only | testsuite#232 (status/hold) | bootc upgrade regressions undetected |
| Bonedigger crash signal unwired | common#424 | Panic in lifecycle bot doesn't block promotion |

---

## 1. AI Usage Blindspots

### Cross-Repo Blindspots (Factory-Level)

#### CRB-1 · Build paradigm contamination across repos

An AI loaded with `common` or `bluefin` context will attempt `dnf5 install` in:
- **dakota** (BuildStream 2 — no dnf, no RPMs, no COPR)
- **bluefin-lts** (CentOS Stream 10 — no COPR, use EPEL)

**Constraint:** Load repo-specific "not-bluefin" skill before ANY cross-repo work.

#### CRB-2 · Registry namespace confusion

Production images: `ghcr.io/projectbluefin/bluefin*` (NOT `projectbluefin`)
CI/testing images: `ghcr.io/projectbluefin/bluefin:testing`

All image refs are now `ghcr.io/projectbluefin/` — the org migration is complete.
This breaks e2e workflows and production paths.

**Constraint:** Load `image-registry.md` before touching ANY image reference.

#### CRB-3 · Branch target divergence

| Repo | PR target | Wrong target consequence |
|---|---|---|
| bluefin | `testing` | PR to `main` causes immediate promotion bypass |
| bluefin-lts | `main` | PR to wrong branch; `main→lts` is the promotion path |
| common | `main` | Correct |
| dakota | `testing` | PR to `main` causes immediate promotion bypass |
| actions | `main` | Correct (consumer repos use `testing`) |
| testsuite | `main` | Correct |

#### CRB-4 · Common layer blast radius

`system_files/shared/` changes propagate to ALL downstream images (bluefin, bluefin-lts, dakota).
No pre-merge gate tests all three simultaneously — `pr-e2e.yml` only composes against bluefin.

**Constraint:** Changes to `system_files/shared/` require explicit consideration of all three consumers.

#### CRB-5 · Actions consumer contract coupling

Changes to `bootc-build/*/action.yml` inputs break `bluefin`, `bluefin-lts`, `aurora`, and `bazzite`.
The `consumer-validation.yml` gate enforces evidence but cannot prevent semantic breaks.

**Constraint:** Never remove/rename action inputs without version bump + coordinated consumer PRs.

### Repo-Specific Blindspots

#### BS-2.1 · `bluefin` Containerfile cache boundary (carried from L1)

ARG declarations between Stage 1 and Stage 2 RUN blocks are cache-intentional.
Adding packages or moving ARGs upward silently breaks 20–80 min of CI cache.
No automated test detects cache busting.

**Constraint:** Check `bluefin/docs/build.md` stage boundary notes before Containerfile edits.

#### BS-2.2 · `bluefin` git remote trap (carried from L1)

Bare `git push` from a cloned fork can send to the wrong repo — always use `gh pr create --repo projectbluefin/<repo>`.
No pre-push hook. Has already happened.

**Constraint:** Always `git push projectbluefin <branch>`. Never bare `git push`.

#### BS-2.3 · `bluefin-lts` build_scripts vs build_files boundary

`bluefin-lts` uses `build_scripts/` (CentOS-specific assembly).
`bluefin` uses `build_files/` (Fedora pipeline).
An AI pattern-matching from bluefin will use wrong paths.

**Constraint:** Never reference `build_files/` in bluefin-lts context.

#### BS-2.4 · `dakota` Containerfile is NOT the build path

Dakota's `Containerfile` exists only for linting. Real build is via BuildStream.
`Justfile` wraps `bst build` → `bst artifact checkout` → `podman load`.

**Constraint:** Load `dakota-overview.md` before ANY dakota work.

#### BS-2.5 · `testsuite` environment.py implicit context contracts

Suite behavior depends on `context.*` state set in `environment.py` hooks.
Steps reference `context.image_family`, `context.brew_available`, etc.
without any type annotation or schema.

**Constraint:** Read the target suite's `environment.py` before writing/modifying steps.

#### BS-2.6 · `testsuite` dual execution modes

Same suite may run in: VM (gnome-e2e action), container, or plain SSH.
Step implementations must handle all modes or declare mode requirements via tags.

**Constraint:** Check `docs/skills/suite-map.md` for mode requirements before step changes.

#### BS-2.7 · `actions` reusable workflow vs composite action split

Path 1 (reusable `reusable-build.yml`): bluefin, aurora
Path 2 (à la carte composite actions): bluefin-lts, dakota

An AI won't know which path a consumer uses without reading `AGENTS.md`.

**Constraint:** Load `actions/AGENTS.md` to determine consumer path before editing.

#### BS-2.8 · `bonedigger` SHA-pinning intentional inconsistency

`common` and `bluefin` pin bonedigger to SHA.
`bluefin-lts` and `dakota` use `@main` intentionally (no versioned releases).
An agent doing compliance will attempt to pin them to a stale SHA.

**Constraint:** `@main` in `bluefin-lts`/`dakota` bonedigger.yml is intentional. Do NOT pin.

---

## 2. Current Feedback Mechanisms

### Validation Gates (Pre-Merge)

| Gate | Repo(s) | Trigger | What It Catches | Blocking? |
|---|---|---|---|---|
| `just check` | common, bluefin, bluefin-lts, dakota | commit | Justfile syntax | ✅ blocking |
| `pre-commit run --all-files` | common, bluefin, bluefin-lts, dakota | commit | YAML/JSON, trailing-ws, actionlint, floating tags | ✅ blocking |
| `validate.yml` | common | PR | shellcheck, submodule drift, dconf parity, image-ref guard | ✅ blocking |
| `validate-brewfiles.yaml` | common | PR | Brewfile validity | ✅ blocking |
| `pr-validation.yml` | bluefin | PR | validate-pr action + BATS unit tests | ✅ blocking |
| `pr-testsuite.yml` | bluefin-lts | PR | validate-pr + COPR ban + unit smoke | ✅ blocking |
| `pr-validate.yml` | testsuite | PR | ruff + py_compile + behave --dry-run | ✅ blocking |
| `unit-tests.yml` | testsuite | PR | pytest + coverage ≥75% | ✅ blocking |
| `consumer-validation.yml` | actions | PR | Consumer PR/CI evidence required | ✅ blocking |
| `actionlint.yml` | actions | PR | GitHub Actions syntax | ✅ blocking |
| `validate-renovate.yml` | actions, bluefin-lts | PR | Renovate config correctness | ✅ blocking |
| `docs-quality.yml` | common | PR | Skill frontmatter + Trail of Bits CI | ✅ blocking |

### Advisory Gates (Pre-Merge, Non-Blocking)

| Gate | Repo(s) | What It Catches |
|---|---|---|
| `skill-drift.yml` | common, bluefin, bluefin-lts, dakota, actions | Code changes without matching doc updates |
| `pr-e2e.yml` | common | Composed image regressions (active, advisory) |
| `skill-audit.yml` | actions | Stale/missing skill docs |

### Post-Merge / Promotion Gates

| Gate | Repo(s) | Trigger | What It Catches |
|---|---|---|---|
| `build.yml` | common | merge to main | OCI build integrity |
| `e2e.yml` | common | post-merge | Common suite vs bluefin, lts, dakota |
| `post-merge-e2e.yml` | bluefin-lts | merge to main | smoke/common on :lts-testing |
| `promotion-candidate-e2e.yml` | common | weekly Tue | smoke/common on :testing + :lts-testing |
| `weekly-testing-promotion.yml` | bluefin | promotion | Cosign verification + tag move |
| `factory-operations` env | bluefin, bluefin-lts, dakota | promotion | 2-human approval |
| `bootc container lint --fatal-warnings` | bluefin | build | OCI spec compliance |

### Critical Gaps in Feedback

| Gap | Impact | Tracking |
|---|---|---|
| No installability gate | Broken installer paths reach stable | common#423 |
| Migration test manual-only | bootc upgrade regressions undetected | testsuite#232 |
| Bonedigger crash/panic unwired | Lifecycle bot failure doesn't block promotion | common#424 |
| Nightly LTS/GDX persistently red | CI desensitization | testsuite#372, #373 |
| testsuite lacks skill-drift.yml | Doc parity not enforced | P2 backlog |
| No pre-merge e2e for bluefin-lts or dakota | Regressions caught only post-merge | P1 gap |

---

## 3. Structural Obstacles

### Factory-Wide Obstacles

| Obstacle | Repos Affected | Why AI Gets It Wrong |
|---|---|---|
| Mixed shell DSL in Justfiles | all | Deep branching, env-dependent logic, hidden state; AI generates plausible but wrong commands |
| Containerfile multi-stage cache semantics | common, bluefin | Layer ordering and ARG placement have performance implications invisible to AI |
| Cross-repo tag/ref coupling | common, bluefin, bluefin-lts, testsuite | Image tags like `:testing`, `:lts-testing`, `:stable` have promotion semantics AI won't infer |
| Generated CI config (dakota) | dakota | `generate-bst-ci-config` action synthesizes BuildStream behavior at runtime |
| Dual-mode test execution (testsuite) | testsuite | Same suite runs in VM/container/SSH; step authors must handle all modes |
| Consumer contract coupling (actions) | actions → bluefin, aurora, bazzite | Input changes are API-breaking; no type system enforces it |

### Per-Repo Structural Risks

| Repo | File/Area | Risk |
|---|---|---|
| common | `system_files/shared/**` | One bad file breaks 3 downstream images |
| common | `validate.yml` (bespoke guards) | Policy logic embedded in shell; easy to invalidate |
| bluefin | `Containerfile:41-88` (multi-mount shell) | Hidden ordering assumptions |
| bluefin | `Justfile:265-379` (VM/ISO orchestration) | Brittle port probing, side effects |
| bluefin-lts | `reusable-build-image.yml:78-220` | Branch-sensitive release logic, matrix, tagging |
| dakota | `elements/*.bst` DAG | Opaque dependency graph; AI can't infer ordering |
| dakota | `Justfile:86-170` (dual-variant logic) | default + nvidia build/export/squash coupling |
| actions | `scripts/check-consumer-contract.py` | YAML parsing quirks in contract validation |
| actions | `consumer-validation.yml` (regex) | Template-dependent; brittle to PR body format changes |
| testsuite | `tests/shared/gnome_shell_steps.py` | GNOME version-conditioned naming; AT-SPI heuristics |
| testsuite | `tests/*/environment.py` | Heavy monkeypatching, implicit context, skip logic |

---

## 4. Level 3 Bridge Requirements

Level 3 (Instructed) means: **constraint rules are machine-readable and enforced
programmatically.** Agents receive explicit context before operating and violations
are caught by automated systems, not hoped-for by documentation.

### 4.1 Constraint Rules That Must Be Captured

#### Universal (all repos)

| Rule | Enforcement Today | Level 3 Target |
|---|---|---|
| Run `just check` + `pre-commit` before commit | Human discipline + CI catch | Pre-push hook or CI-required check |
| Load AGENTS.md before any repo work | Honor system | Machine-verified instruction acknowledgment |
| Attribution trailer on AI commits | Honor system | CI check for `Assisted-by:` + `Co-authored-by:` |
| Never write to `ublue-os/*` repos | Policy doc | Automated block on `gh` CLI writes to ublue-os |
| Squash merge only | Branch protection | Already enforced ✅ |
| PR title in Conventional Commits format | Human review | CI regex gate |
| Max 4 open PRs per agent | Honor system | Bot enforcement |

#### Per-Repo Constraint Rules

| Repo | Rule | Skill to Load |
|---|---|---|
| common | Changes to `system_files/shared/` must consider bluefin + lts + dakota impact | `submodule-boundary.md` |
| common | dconf key + lock file must be edited together | `dconf-consistency.md` |
| common | Image refs must stay `ghcr.io/projectbluefin/` unless maintainer approves | `image-registry.md` |
| common | CODEOWNERS TRIAGERS sentinel is load-bearing for sync workflow | `governance.md` |
| bluefin | PRs target `testing`, never `main` | `bluefin-build.md` |
| bluefin | Containerfile cache boundary between Stage 1/2 is intentional | `bluefin-build.md` |
| bluefin | Push to `projectbluefin` remote, never `origin` | `bluefin-build.md` |
| bluefin-lts | No COPR — CentOS uses EPEL | `bluefin-lts.md` |
| bluefin-lts | Use `build_scripts/`, never `build_files/` | `bluefin-lts.md` |
| bluefin-lts | PRs target `main` (not `testing`) | `bluefin-lts.md` |
| dakota | BuildStream only — no dnf, no Containerfile builds | `dakota-overview.md` |
| dakota | PRs target `testing`, never `main` | `dakota-overview.md` |
| dakota | `Containerfile` is for lint only, not image assembly | `dakota-overview.md` |
| actions | Consumer validation PR required before merge | `docs/SKILL.md` |
| actions | No input removal without version bump | `docs/SKILL.md` |
| actions | Consumer PRs target `testing` in downstream repos | `docs/SKILL.md` |
| testsuite | Update `suite-map.md` when coverage changes | `suite-map.md` |
| testsuite | Read `environment.py` before writing steps | `suite-map.md` |
| testsuite | Never use `github.ref_name` inside reusable workflows | `ops.md` |

### 4.2 Missing Machine Enforcement (Level 3 Gaps)

These rules exist in documentation but have NO automated enforcement today:

| Rule | Status | Proposed Enforcement |
|---|---|---|
| Load AGENTS.md before repo work | Docs only | Skill-drift CI: fail if touched paths have no skill acknowledgment |
| Attribution trailer on AI commits | Docs only | CI check: grep commit message for `Assisted-by:` pattern |
| Branch target correctness | Docs only | Branch protection: restrict PR base branch per repo |
| Image ref namespace guard | Partial (validate.yml) | Expand guard to all repos, make blocking |
| Consumer validation evidence | ✅ actions | Already enforced |
| COPR ban in bluefin-lts | ✅ pr-testsuite.yml | Already enforced |
| Containerfile cache boundary | Docs only | Custom lint: flag ARG movement across stage boundary |
| Max 4 open PRs per agent | Docs only | Bot query + auto-block |
| dconf key+lock parity | ✅ validate.yml | Already enforced |
| Conventional Commits PR title | Docs only | CI regex check on PR title |

### 4.3 Promotion Path Traceability (Level 3 Requirement)

For Level 3, a promoted `:stable` image must be traceable to:
- The `common` commit that built the shared layer
- The downstream image commit
- The testsuite SHA that validated it
- The workflow run ID
- The 2-human promotion approval

**Current state:** Partial. Cosign signatures link image → workflow run. But there is no
promotion evidence bundle connecting all five pieces. This is a Level 3 requirement.

### 4.4 Human Gates (Permanent — Never Automate)

| Gate | Owner | Reason |
|---|---|---|
| `/approve` on issues | Maintainer | Prioritization judgment |
| PR merge approval | CODEOWNERS reviewer | Accountability |
| `hive/p0` / `hive/p1` labels | Maintainer | Release impact assessment |
| Production promotion (Tuesday) | 2 maintainers | Go/no-go for user-facing change |
| `/unclaim` on stale PRs | Maintainer | Abandoned vs. still-active judgment |
| Any write to `ublue-os/*` | Human only | Absolute prohibition |

---

## 5. Recommended Issue Batch

### Level 2 Confidence Gaps (fix to solidify L2)

| Priority | Action | Repo | Tracking |
|---|---|---|---|
| P0 | Fix nightly LTS e2e (ZFS /var blocking harness) | testsuite | testsuite#373 |
| P0 | Fix nightly GDX e2e (Homebrew missing, COPR error) | testsuite | testsuite#372 |
| P1 | Wire installability gate before testing→stable | common | common#423 ✅ CLOSED |
| P1 | Wire bonedigger crash/panic into promotion decisions | common | common#424 |
| P1 | Unblock migration-test schedule (pending zstd:chunked) | testsuite | testsuite#232 |
| P2 | Add skill-drift.yml to testsuite | testsuite | backlog |
| P2 | Fix stale workflow-map.md (pr-e2e listed as disabled, #493 closed) | common | ✅ Already clean |

### Level 3 Bridge Work (new capabilities for L3)

| Priority | Action | Repo | Tracking |
|---|---|---|---|
| P1 | CI check for `Assisted-by:` / `Co-authored-by:` on AI commits | all | [common#507](https://github.com/projectbluefin/common/issues/507) |
| P1 | CI regex gate for Conventional Commits PR title | all | [actions#84](https://github.com/projectbluefin/actions/issues/84) |
| P1 | Branch target enforcement (restrict PR base) | bluefin, dakota | [bluefin#329](https://github.com/projectbluefin/bluefin/issues/329), [dakota#716](https://github.com/projectbluefin/dakota/issues/716) |
| P1 | Pre-merge e2e for bluefin-lts (compose + common suite) | bluefin-lts | [bluefin-lts#68](https://github.com/projectbluefin/bluefin-lts/issues/68) |
| P2 | Image-ref namespace guard in all repos (not just common) | all | backlog |
| P2 | Promotion evidence bundle (common SHA + image SHA + testsuite SHA + run ID + approval) | common | backlog |
| P2 | Max 4 open PRs enforcement bot | org-wide | backlog |
| P2 | Containerfile cache boundary lint (detect ARG movement) | bluefin | backlog |
| P3 | Machine-readable constraint rules file (`.ai-constraints.yml`) | all | backlog |
| P3 | Instruction loading verification (agent proves it read AGENTS.md) | all | backlog |

---

## 6. Doc Drift Findings (Discovered During Audit)

| File | Issue | Fix | Status |
|---|---|---|---|
| `docs/skills/workflow-map.md:20` | Listed pr-e2e.yml as disabled; #493 is closed, e2e job is active | Remove ⚠️ note | ✅ Already clean — no note was present |
| `docs/skills/acmm-audit-level1.md:9` | States "Level 1 → bridging to Level 2"; per arXiv paper nomenclature should be "Level 2 → bridging to Level 3" | Update header | ✅ Fixed 2026-06-05 |
| `docs/factory/README.md:112` | Pre-merge e2e listed as "✅ (common suite)" but was recently re-enabled | Confirm and update date | ✅ Confirmed correct — pr-e2e.yml active, dated 2026-06-05 |

---

## 7. Supply Chain & Artifact Integrity (Level 3 Preparation)

| Area | Current State | Level 3 Requirement |
|---|---|---|
| Cosign image signing | ✅ Active (bluefin, bluefin-lts) | Maintain |
| Key rotation detection | ✅ `check-cosign-key-rotation.yml` | Maintain |
| GitHub Actions SHA pinning | ✅ Enforced by pre-commit | Maintain |
| OCI digest pinning (Renovate) | ✅ Active in common, bluefin, actions | Extend to all repos |
| SBOM/provenance | ❌ Not present | Add SBOM generation to build workflows |
| Promotion traceability | ⚠️ Partial (cosign only) | Full evidence bundle |

---

## Appendix: Level Definitions (arXiv:2604.09388)

| Level | Name | Key Characteristic |
|---|---|---|
| 1 | Unaware | No AI tooling; manual development |
| 2 | Assisted | AI tools used with human review; basic feedback loops |
| 3 | Instructed | Constraint rules enforced; AI given explicit context programmatically |
| 4 | Partnered | AI operates semi-autonomously with guardrails |
| 5 | Autonomous | AI makes independent decisions within defined boundaries |

**Project Bluefin current assessment: Level 2 (Assisted), substantially met.**
Several Level 3 primitives exist (skill-drift, consumer-validation, dconf-parity guard)
but are not yet comprehensive enough for full Level 3 classification.
