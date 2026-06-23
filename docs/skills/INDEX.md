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
| [brew-lifecycle.md](brew-lifecycle.md) | How to add/remove system-default Homebrew packages via brew-preinstall, the preinstall.d content-addressed lifecycle, what can move to brew, per-shell starship init pattern, and Homebrew 6.0 tap trust (`--trust` flag + `trusted: true` in Brewfiles) |
| [release-promotion.md](release-promotion.md) | **common** release and promotion — criteria, monthly cadence, hotfix process, artifact verification, supply chain (keyless cosign, SBOM, SLSA L2 live as of 2026-06-11) |
| [workflow-map.md](workflow-map.md) | What each `common` GitHub workflow is for — validation, E2E, release, and factory-policy boundaries |
| [e2e-ci.md](e2e-ci.md) | Pre/post-merge and promotion-candidate E2E CI for common — composed PR gate, testing-stream smoke/common checks, masked brew setup, quarantined scenarios |
| [lab-testing.md](lab-testing.md) | KubeVirt lab testing on ghost — how to boot bluefin, lts, and dakota, collect systemd journal logs, and verify common-layer changes before promotion |
| [ci-tooling.md](ci-tooling.md) | Pre-commit floating-tag guard, SHA pinning, Renovate OCI digest tracking, Trivy archive scan pattern, multi-arch build matrix, release-state.yaml schema validation |
| [onboarding.md](onboarding.md) | Verified setup commands, correct pip/npm flags, and PR branch targets for all projectbluefin repos |
| [submodule-boundary.md](submodule-boundary.md) | What is/isn't editable in this repo — `system_files/shared/` is directly tracked here (edit freely), `system_files/bluefin/` is Bluefin-specific |
| [dconf-consistency.md](dconf-consistency.md) | GSettings override ↔ dconf lock file parity rules — must edit both files together for locked settings |
| [oem-hardware-hooks.md](oem-hardware-hooks.md) | OEM first-boot setup hooks in common: hook directories, version-script contract, shellcheck SC1091 pattern, what belongs here vs downstream, migration checklist |
| [image-registry.md](image-registry.md) | projectbluefin OCI image registry — all production images at `ghcr.io/projectbluefin/` |
| [devmode.md](devmode.md) | `ujust devmode` setup wizard — DX is a product feature, not an image; what it installs, UX flow, tap strategy, group logic, legacy -dx migration advisory, known caveats |
| [bootc.md](bootc.md) | bootc — the foundational OS image tool. Mandatory Context7 lookup rule, filesystem layout constraints, factory build pattern, what NOT to do |
| [containerfile.md](containerfile.md) | Containerfile build structure — multi-stage build, wallpaper source caveat, ujust completion generation, SHA verification pattern, `just overlay` local testing |
| [skill-drift.md](skill-drift.md) | How the skill-drift CI check works — path mapping, what counts as a satisfying update, waiver process |
| [human-gates.md](human-gates.md) | The 4 decision gates (Design/Security/Breakage/Merge) — when to stop, how to signal, verification evidence requirement |
| [skill-improvement.md](skill-improvement.md) | The skill-improvement mandate — checklist, what counts as a learning, cross-repo routing |
| [bonedigger.md](bonedigger.md) | bonedigger + kubestellar-bot — the full self-improvement loop, ujust report, priority escalation, template sync |
| [hive.md](hive.md) | Hive system architecture — bonedigger/kubestellar-bot/hive triangle, label taxonomy, sync schedule, finding work |
| [factory-improvement.md](factory-improvement.md) | Self-improving factory loop — gap audit protocol, pipeline uniformity checklist, human gates, known gaps, and priority order for full automation |
| [factory-onboarding.md](factory-onboarding.md) | How to onboard a repo into the factory model — two-output rule, banned anti-patterns (no changelog files), skill-drift CI wiring, AGENTS.md mandate |
| [nvidia.md](nvidia.md) | NVIDIA GPU support — CDI architecture, per-repo nvidia stacks, NGC container ecosystem, driver/toolkit update procedures, known constraints |

## Agent instruction files (not skills — loaded separately by tool)

| File | Purpose |
|---|---|
| [../../.github/copilot-instructions.md](../../.github/copilot-instructions.md) | Copilot agent instructions — session start ritual, PR checklist, scope discipline, CODEOWNERS sentinel |
| [../factory/README.md](../factory/README.md) | Factory operating model entry point for org-level agent and maintainer workflow |
