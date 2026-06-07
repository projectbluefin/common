# docs/skills — Index

Agent-agnostic skill docs for the `projectbluefin/common` repo. These apply to any agent (Copilot, Claude, etc.) working in this repository.

## What belongs here

Workflow knowledge, architectural context, and operational runbooks that any agent needs to work effectively in this repo.

## What does NOT belong here

Agent-specific instruction files (`.github/copilot-instructions.md`, `AGENTS.md`, `.cursorrules`, etc.) are loaded separately by their respective tools and must not be listed here.

## Factory docs

| File | What it covers |
|---|---|
| [../factory/README.md](../factory/README.md) | Org brain landing page — factory structure, data flow, infrastructure state, open gaps, branch targets, sensitive paths, parity matrix |
| [../factory/IMPROVEMENTS.md](../factory/IMPROVEMENTS.md) | **Why we rewrote Bluefin** — narrative by area (build, CI, lifecycle, agentic model, QA, security). Living doc; agents append as improvements land. |
| [../factory/agentic-model.md](../factory/agentic-model.md) | Cross-repo agent rules — hard rules, smallest-change principle, branch targets, sensitive paths, doc-only push exception, ublue-os prohibition |

## QA and promotion docs

| File | What it covers |
|---|---|
| [../qa/PROMOTION_GATES.md](../qa/PROMOTION_GATES.md) | Current promotion pipeline — what gates exist vs. are still planned; today's real pre-promotion checklist |
| [../qa/HARDWARE_CANARY.md](../qa/HARDWARE_CANARY.md) | Hardware canary program design intent and current manual process |
| [../hardware-testing.md](../hardware-testing.md) | Hardware test report format, 7 hardware-only bug categories, promotion policy for hardware blockers |

## Skill docs

| File | What it covers |
|---|---|
| [label-workflow.md](label-workflow.md) | Label taxonomy, issue lifecycle, and workflow guidelines for humans and agents across all factory repos |
| [governance.md](governance.md) | Triagers role, CODEOWNERS sentinel pattern, sync workflow, branch protection matrix |
| [qa.md](qa.md) | QA model, test coverage matrix, promotion gates by repo, hardware gap, running tests |
| [hive-review.md](hive-review.md) | `~/src/hive-status` — session start, P0/P1 triage, hive label taxonomy |
| [queue-dashboard.md](queue-dashboard.md) | PR review and merge queue workflow — ruleset (1 approval, squash, ALLGREEN queue), triage tiers, rebase patterns, submodule boundary policy |
| [release-promotion.md](release-promotion.md) | **common** release and promotion — criteria, monthly cadence, hotfix process, artifact verification, supply chain gaps |
| [workflow-map.md](workflow-map.md) | What each `common` GitHub workflow is for — validation, E2E, release, and factory-policy boundaries |
| [e2e-ci.md](e2e-ci.md) | Pre/post-merge and promotion-candidate E2E CI for common — composed PR gate, testing-stream smoke/common checks, masked brew setup, quarantined scenarios |
| [ci-tooling.md](ci-tooling.md) | Pre-commit floating-tag guard, live skill-drift workflow, Renovate OCI digest tracking |
| [onboarding.md](onboarding.md) | Verified setup commands, correct pip/npm flags, and PR branch targets for all projectbluefin repos |
| [submodule-boundary.md](submodule-boundary.md) | What is/isn't editable in this repo — `system_files/shared/` is directly tracked here (edit freely), `system_files/bluefin/` is Bluefin-specific |
| [dconf-consistency.md](dconf-consistency.md) | GSettings override ↔ dconf lock file parity rules — must edit both files together for locked settings |
| [image-registry.md](image-registry.md) | projectbluefin OCI image registry — all production images at `ghcr.io/projectbluefin/` |
| [rollback-helper.md](rollback-helper.md) | `ublue-rollback-helper` TUI state machine — three-way coordinated arrays, LTS/non-LTS branches, registry path derivation, testing guidance |
| [skill-drift.md](skill-drift.md) | How the skill-drift CI check works — path mapping, what counts as a satisfying update, waiver process |
| [human-gates.md](human-gates.md) | The 4 decision gates (Design/Security/Breakage/Merge) — when to stop, how to signal, verification evidence requirement |
| [skill-improvement.md](skill-improvement.md) | The skill-improvement mandate — checklist, what counts as a learning, cross-repo routing |
| [bonedigger.md](bonedigger.md) | bonedigger + kubestellar-bot — the full self-improvement loop, ujust report, priority escalation, template sync |
| [hive.md](hive.md) | Hive system architecture — bonedigger/kubestellar-bot/hive triangle, label taxonomy, sync schedule, finding work |
| [acmm-audit-level2.md](acmm-audit-level2.md) | ACMM Level 2 audit (2026-06-05) — confirms L2 maturity, maps feedback mechanisms, defines Level 3 bridge requirements |
| [factory-improvement.md](factory-improvement.md) | Self-improving factory loop — gap audit protocol, pipeline uniformity checklist, human gates, known gaps, and priority order for full automation |

## Agent instruction files (not skills — loaded separately by tool)

| File | Purpose |
|---|---|
| [../../.github/copilot-instructions.md](../../.github/copilot-instructions.md) | Copilot agent instructions — session start ritual, PR checklist, scope discipline, CODEOWNERS sentinel |
| [../factory/README.md](../factory/README.md) | Factory operating model entry point for org-level agent and maintainer workflow |
