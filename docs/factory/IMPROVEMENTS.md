---
name: IMPROVEMENTS
description: "Why we rewrote Bluefin — the full narrative of what changed, what was replaced, and why. Agents append new entries as improvements land."
---

# Why We Rewrote Bluefin

This is the canonical record of the Bluefin 2.0 transition: what the old system looked like, what replaced it, and why each change was made. It is a living document — agents append new sections at the bottom as improvements land.

**The thesis:** Every manual step that could be automated is a reliability tax. Bluefin 2.0 pays off that debt by making agents do the toil and reserving human judgment for decisions that actually require it.

---

## The Agentic Operating Model

**Before:** Bluefin was maintained entirely by human contributors. Issues were ad-hoc, PRs were manually coordinated, and there was no systematic way to scale the maintenance work.

**After:** Bluefin 2.0 is an agentic-first project. Agents implement. Humans approve design, security-sensitive changes, and merge. The goal is to prove that agentic workflows can build the agentic OS.

The operating model has three layers:

```
┌─────────────────────────────────────────────────────┐
│  KubeStellar Hive  (ACMM orchestration)             │
│  Agents run at increasing autonomy levels            │
└────────────────┬────────────────────────────────────┘
                 │
     ┌───────────┴───────────┐
     ▼                       ▼
bonedigger              kubestellar-bot
(client + lifecycle)    (implementation agent)

ujust report            picks up queued issues
└─ agent collects  ───▶ implements fixes
   system state         ships improvements
   humans can't         back to the image
└─ files issue
   to image repo
        │
        └─── better OS → better bonedigger → loop
```

**Why:** Human maintainers were the bottleneck. The agentic model removes that bottleneck for everything that doesn't require human judgment, while keeping humans in the loop for the decisions that matter.

---

## Org Structure: ublue-os → projectbluefin (complete)

**Before:** Bluefin lived inside `ublue-os`, a shared org with many other projects. There was no clean boundary between Bluefin-specific automation and shared ublue-os infrastructure.

**After:** The `projectbluefin` org owns all Bluefin image repos, automation, CI, and tooling — including the production image registry at `ghcr.io/projectbluefin/`. The migration is complete. `projectbluefin` is fully standalone.

**Why:** Clean ownership boundaries. The org split lets Bluefin evolve its CI, lifecycle automation, and agentic model independently. It also enables org-level secrets, project boards, and access controls specific to the Bluefin factory.

---

## Issue Lifecycle Automation

**Before:** Issues were filed manually, triaged inconsistently, and there was no automated pipeline to move work from "filed" to "done." Each repo handled issues differently.

**After:** A unified lifecycle runs across all 6 factory repos via `lifecycle.yml` (owned in `common`, deployed everywhere via `lifecycle-caller.yml`). Every issue gets:

- Automatic `status/triage` on open
- A pipeline widget in the body showing current stage and exact next action
- Slash commands: `/approve`, `/claim`, `/unclaim`, `/wontfix`, `/hold`
- A label guard that blocks `/approve` until `kind/` + `area/` are set
- A daily stale-claim sweep that returns inactive claims after 7 days

```
filed → status/triage → [status/discussing] → status/queued → status/claimed → done
```

**Why:** Deterministic pipelines. Every issue has exactly one owner at every moment. Agents can pick up work confidently knowing the queue is accurate. Humans can see the full pipeline state without asking anyone.

Reference: [`docs/skills/label-workflow.md`](../skills/label-workflow.md)

---

## Label Standardization

**Before:** Each repo had its own label set with different naming conventions, colors, and semantics. Automation that depended on labels couldn't be shared across repos.

**After:** 67 canonical labels defined in `labels.json` (including `hive/*`, `status/*`, `kind/*`, `area/*`, `hardware/*`, `source/*`, `priority/*`). Labels are synced to all factory repos by `sync-labels.yml`.

**Why:** Label parity is a prerequisite for cross-repo automation. The lifecycle bot, hive sync, and org project board all depend on labels having identical semantics across repos.

Reference: [`docs/skills/label-workflow.md`](../skills/label-workflow.md)

---

## Shared CI/CD via projectbluefin/actions

**Before:** Each repo maintained its own copy of common CI logic. When a workflow pattern needed to change, every repo needed a separate PR. Divergence was constant.

**After:** `projectbluefin/actions` is the canonical home for shared GitHub Actions composite actions and reusable workflows. Signing, SBOM generation, CVE scanning, and provenance attestation all live there. Repos consume via pinned SHA refs.

**Why:** Single source of truth for CI patterns. A fix in `actions` propagates to all consumers. Supply chain concerns (signing, attestation) are handled once, not N times.

Current consumer: `common`, `bluefin`, `bluefin-lts`, `dakota`, `testsuite`.

---

## SHA Pinning Policy

**Before:** GitHub Actions workflows used floating tags (`@v4`, `@main`, `@latest`). Any upstream action could be compromised and silently inject malicious code on the next workflow run.

**After:** All third-party `uses:` references are pinned to full commit SHAs with a version comment. A `no-floating-action-tags` pre-commit hook blocks any attempt to commit floating refs.

```yaml
# correct
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4

# blocked by pre-commit
uses: actions/checkout@v4
uses: actions/checkout@main
```

Renovate manages SHA updates automatically once pins are in place.

**Why:** Supply chain security. Floating tags are a known attack vector. SHA pins guarantee bit-for-bit reproducibility. See [`docs/skills/ci-tooling.md`](../skills/ci-tooling.md).

---

## Documentation as the Factory Brain

**Before:** Project knowledge was scattered across READMEs, wiki pages, and individual maintainer memory. Agents starting cold had no reliable way to understand how the project worked.

**After:** `docs/` in `projectbluefin/common` is the canonical factory brain. Everything an agent needs to work on any part of the project is here:

- `docs/factory/` — org-level structure, parity matrix, open gaps
- `docs/skills/` — task-specific operational skills (60+ files covering every subsystem)
- `docs/qa/` — promotion gates and hardware canary policy

The skill-drift CI gate (`skill-drift.yml`) enforces that implementation changes carry matching doc updates. ACMM audits measure documentation completeness against a maturity model.

**Why:** Agents are stateless. Without documented knowledge, every agent session starts at zero. Documented knowledge compounds: each agent that discovers a pattern and writes it back makes every future agent smarter.

Reference: [`docs/skills/skill-improvement.md`](../skills/skill-improvement.md)

---

## The Self-Improvement Loop

**Before:** No mechanism existed for the project to learn from agent sessions. Patterns discovered, workarounds found, and conventions established were lost when a session ended.

**After:** Every agent session is expected to produce two outputs:
1. **The work** — the PR, fix, or improvement
2. **The learning** — the skill file update that captures what a future agent should know

The loop:
```
agent works on task
  └─ discovers pattern / workaround / convention
       └─ writes it to the relevant skill file
            └─ commits in same PR
                 └─ next agent starts smarter
                      └─ loop
```

The ACMM (AI Codebase Maturity Model) framework measures how well the loop is working. Current status: **Level 3 (Instructed)**, achieved 2026-06-06.

**Why:** Compound improvement. A factory that doesn't learn from its own operation is just executing — not improving.

---

## QA Pipeline and Promotion Gates

**Before:** Promotion from testing to stable was informal. There was no defined set of gates that had to pass before a release.

**After:** Multi-layer QA pipeline:

- **Pre-merge:** `pr-e2e.yml` runs the common test suite against a composed image on every PR to `common`
- **Post-merge:** `e2e.yml` runs the full suite against the downstream images after every `common` build
- **Promotion candidate:** Weekly `promotion-candidate-e2e.yml` runs smoke + common checks on `bluefin:testing` and `bluefin:lts-testing` before promotion decisions
- **Production gate:** `factory-operations` environment requires 2 human approvals before `:stable` tag in any image repo
- **Promotion floor:** N=7 successful runs required before promotion (statistical signal)

**Why:** Confidence in production. The old "it built, ship it" model produced regressions that users found. Automated gates catch problems before they reach stable.

Reference: [`docs/qa/PROMOTION_GATES.md`](../qa/PROMOTION_GATES.md)

---

## Hardware Canary Program

**Before:** Hardware-specific bugs were discovered by users on real hardware after a release. There was no systematic way to catch them pre-promotion.

**After:** Hardware canary program defined: a small set of community volunteers run pre-promotion builds on real hardware and report results before the promotion decision. Seven hardware-only bug categories are tracked separately from software test failures.

**Why:** Automated tests run in VMs. VMs don't catch GPU driver issues, suspend/resume bugs, firmware quirks, or thermal behavior. Hardware canaries are the only signal for these categories.

Reference: [`docs/qa/HARDWARE_CANARY.md`](../qa/HARDWARE_CANARY.md), [`docs/hardware-testing.md`](../hardware-testing.md)

---

## bonedigger: User Feedback Loop

**Before:** Users had no structured way to report issues from their running system. Bug reports were missing diagnostic context, and the same issues were filed multiple times by different users.

**After:** `ujust report` launches the bonedigger client on a live system. An agent collects system diagnostics (logs, package versions, hardware info), scrubs PII on-device, and files a structured issue to the image repo. Priority auto-escalation triggers from `ujust confirm` counts (3+ confirms → `priority/p1`, 5+ confirms → `priority/p0`).

**Why:** Better signal. Issues filed via `ujust report` contain the diagnostic context needed to reproduce and fix problems. Confirm counts surface issues that are affecting multiple users.

Reference: [`docs/skills/bonedigger.md`](../skills/bonedigger.md)

---

## Factory Parity: All Repos on the Same Standard

**Before:** Each repo evolved independently. Some had lifecycle automation, some didn't. Label sets drifted. CODEOWNERS formats varied.

**After:** A parity matrix (tracked in `docs/factory/README.md`) defines what every factory repo must have: AGENTS.md, lifecycle-caller.yml, skill-drift.yml, hive labels, pre-commit, squash-only merge. `sync-codeowners.yml` and `sync-labels.yml` propagate standards from `common` to downstream repos automatically.

**Why:** Automation that works in `common` should work identically in `bluefin`. Parity eliminates the "it works here but not there" class of problems.

---

## Running Improvements

*Agents: append entries here when shipping improvements to the factory. Format: date, area, what changed, issue/PR link.*

| Date | Area | Improvement | Ref |
|---|---|---|---|
| 2026-06-05 | Lifecycle | Unified lifecycle.yml deployed to all 6 factory repos, replacing per-repo bonedigger lifecycle calls | common#— |
| 2026-06-05 | Security | bonedigger sync-templates replaced banned PAT with mergeraptor app token | bonedigger#21 |
| 2026-06-05 | Docs | ACMM Level 2 audit completed; Level 3 bridge requirements defined; Level 3 achieved 2026-06-06 | — |
| 2026-06-06 | Docs | Factory brain restructured: IMPROVEMENTS.md, human-gates.md, skill-improvement.md added; duplicate files merged and deleted | — |
| 2026-06-06 | Docs | Operating manual pass: removed Known Gaps/Priority Order checklists from factory-improvement.md; replaced Open Gaps bullet list in factory/README.md with org-wide GH search commands; added "Capturing gaps" section to agentic-model.md; fixed skill-improvement.md to file issues instead of updating static docs; updated SKILL.md router with gap-capture row; now 100% of factory gaps tracked as GitHub issues, zero static backlog in docs | — |
| 2026-06-06 | Maturity | **ACMM Level 3 (Instructed) achieved.** Factory now has machine-readable per-repo contracts (AGENTS.md in all repos), programmatic instruction loading (Copilot system prompt), AI-specific guardrails (skill-drift CI gate, human-gates.md, human gates documented as non-automatable), and the hive ACMM scoring reflects L3. | hive-status |
| 2026-06-06 | Docs | Operating manual pass 2: added session start output guide to AGENTS.md; collapsed redundant workflow list to pointer; added bootc-installer and knuckle to factory repo map and branch targets; committed untracked AMD s2idle udev rule; updated ACMM audit doc with L3 achievement notice | — |
| 2026-06-10 | CI | Simplification audit: deleted backfill-pipeline.yml + skill-drift.yml (process-as-gate violation), removed dead atuin code from bling.sh, hardened libsetup.sh with flock + JSON validation, added dry-run mode to sync-codeowners.yml | common#569 |
| 2026-06-10 | Audit | Automation audit drift refresh + execution batch: 116 wf / 875 LoC / per-repo gates reconciled; 4 PRs filed and merged (bluefin#484→testing, bluefin-lts#159, bonedigger#22, iso#60) closing #585/#586/#589. CODEOWNERS uses @projectbluefin/maintainers team handle. Refresh-cadence section added to audit README so future agents drift-verify before continuing | common#583 |
| 2026-06-10 | CI | Automation audit execution batch 2 (parallel fleet dispatch): 7 PRs shipped across 3 repos. Phase 1: v1 tag auto-update (actions#154). Phase 2: git-cliff + e2e release gate (common#592). Phase 3: retry composite action (actions#155). Phase 4: token health check (actions#156). Phase 7: dakota BST cache-warm (dakota#785). C2: pin @main refs to SHA in dakota workflows (dakota#784). C3: Renovate grouping rule for projectbluefin/actions refs (common#593). C1 (reusable-promote) blocked pending schema alignment — see #584. | common#583 |
| 2026-06-10 | CI | Correctness audit + merge pass: all 7 batch-2 PRs merged. Bugs caught in QA: wrong build target in cache-warm (elements/layers/top.bst → oci/bluefin.bst), dakota PRs retargeted from testing→main (AGENTS.md corrected). C1 unblocked: release-state.yaml is a record file, not a pipeline input — schema change concern was wrong. | common#583 |
| 2026-06-10 | CI | C1 (reusable-promote.yml) landed: 220-line reusable workflow in actions#157. Removes new secrets (audit template incorrectly added APP_ID/APP_PRIVATE_KEY — existing promote workflows use github.token). Adds missing gate job. Dakota canary thin caller merged (dakota#788, 183→30 LoC). bluefin-lts and bluefin adoption pending one observed promotion cycle. | actions#157 |
| 2026-06-10 | Security | PAT-ban audit + enforcement: removed PACKAGES_TOKEN from actions/reusable-build.yml (actions#158), removed dead SCORECARD_TOKEN comment from bluefin/scorecard.yml (bluefin#485), added pat-ban.yml CI gate blocking unapproved secret references (actions#159), published secrets-policy.md (common/docs/). Factory is now PAT-free on all main/testing branches. |  actions#158/159 |
| 2026-06-12 | CI/OCI | chunkah cadence signal: added `bootc-build/apply-pkg-intervals` composite action + `reusable-pkg-cadence` self-updating workflow. Sets `user.update-interval` xattrs on all RPM-owned files before rechunking so chunkah packs by update frequency instead of blind. Bootstrap data from live images (bluefin 1,826 pkgs, lts 1,489). Self-updates after each Execute Release — no PRs, direct commit. | actions#210, bluefin#537, bluefin-lts#181 |
| 2026-06-12 | Build | Package arrays extracted to TOML manifests in bluefin and bluefin-lts. New `read-packages` Python helper (tomllib stdlib) consumed with readarray. bluefin 03-packages.sh: 198→86 lines (-56%). bluefin-lts 20-packages.sh: 76→58 (-24%), 10-packages-image-base.sh: 122→97 (-20%). Python orchestration refactor filed as bluefin#538. | bluefin#539, bluefin-lts#182 |
| 2026-06-12 | CI | Factory-wide automerge reliability fix: dropped `--auto` from `reusable-renovate-automerge.yml` (works without branch protection), switched all 53 `projectbluefin/actions` SHA pins to `@v1` managed tag across dakota/bluefin/bluefin-lts (propagation delay was the root cause of the June 13 outage), added `no-sha-pins-for-internal-actions` pre-commit hook to enforce `@v1` going forward, fixed `build.yml` missing `testing` in push trigger (blocking :testing image updates), and added `renovate-automerge.yml` to common with mergeraptor bypass token. | projectbluefin/actions@cfcf98a, dakota#830, bluefin#552, bluefin-lts#204 |
| 2026-06-12 | CI | Factory-wide automerge reliability: dropped `--auto` from `reusable-renovate-automerge.yml`, migrated all 53 `projectbluefin/actions` SHA pins to `@v1` across dakota/bluefin/bluefin-lts (propagation delay was root cause of June 13 outage), added `no-sha-pins-for-internal-actions` pre-commit enforcement, fixed `build.yml` missing `testing` push trigger (blocking :testing image updates), added `renovate-automerge.yml` to common with mergeraptor bypass token. | projectbluefin/actions@cfcf98a, dakota#830, bluefin#552, bluefin-lts#204 |